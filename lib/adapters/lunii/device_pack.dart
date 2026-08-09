/// Builds the `.content/<PACK>/` tree a Lunii storyteller reads directly —
/// the other half of [lunii_pack.dart](../export/lunii_pack.dart), which makes
/// the STUdio zip a grown-up transfers by hand.
///
/// It returns the files rather than writing them. Nothing here can touch a
/// device: a pack is a value that can be inspected, asserted over and diffed
/// long before anyone decides where to put it. The nine packs already on a
/// storyteller are purchased content, so the writing step stays separate and
/// deliberate.
///
/// The layout, the header fields and the ciphering are all read off a physical
/// FW2 device — see [docs/lunii-sync.md](../../../docs/lunii-sync.md) and
/// `tool/lunii_probe.dart`, which asserts every one of these claims against
/// whatever is attached.
///
/// ```
/// .content/<PACK>/          <PACK> = last 4 bytes of the uuid, upper hex
/// ├── ni                    node index — plaintext, and that is the trap
/// ├── li                    list index — ciphered
/// ├── ri, si                asset indexes — ciphered
/// ├── bt                    64 B boot file — ciphered with the DEVICE key
/// ├── nm                    empty
/// ├── rf/000/XXXXXXXX       images, ciphered
/// └── sf/000/XXXXXXXX       audio, ciphered
/// ```
///
/// The story is laid out as a straight line, the same shape the STUdio pack
/// uses:
///
/// ```
/// cover ─▶ chapter 1 ─▶ chapter 2 ─▶ … ─▶ chapter n
/// ```
///
/// with autoplay on each chapter, so it runs start to finish on its own and OK
/// skips ahead.
library;

import 'dart:math';
import 'dart:typed_data';

import '../audio/mp3_frame.dart';
import '../image/bmp_rle4.dart';
import 'lunii_cipher.dart';

/// Node index layout, all confirmed against a device.
const int _headerSize = 0x200;
const int _nodeSize = 0x2C;
const int _formatVersion = 1;
const int _packVersion = 2;

/// The byte at 0x18 of the node index. Zero in every pack on the device.
const int _controlByte = 0;

/// `ri`/`si` entries are a fixed twelve bytes: `000\` and eight hex digits.
const int _assetEntrySize = 12;

/// The boot file is the first 64 bytes of the ciphered `ri`, ciphered again.
const int _bootSize = 0x40;

/// Screen size the device requires, and the only size it is given.
const int _imageWidth = 320;
const int _imageHeight = 240;

class DevicePackException implements Exception {
  const DevicePackException(this.message);
  final String message;

  @override
  String toString() => 'DevicePackException: $message';
}

/// One chapter: what plays, and what is shown while it plays.
class DevicePackChapter {
  const DevicePackChapter({required this.audio, this.image});

  /// MP3 the device will play — 44.1 kHz mono, as
  /// `lib/adapters/audio/mp3_encoder.dart` produces.
  final Uint8List audio;

  /// Shown for this chapter. Null falls back to the pack's cover.
  final IndexedImage? image;
}

/// A built pack, ready to be written wherever the caller decides.
class DevicePack {
  const DevicePack({
    required this.uuid,
    required this.files,
    required this.nodeCount,
  });

  /// The 16 bytes appended to `.pi` — **last**, once every file below is
  /// safely on disk. A pack that is written but unlisted is merely invisible;
  /// one that is listed but half-written is a broken library.
  final Uint8List uuid;

  /// Paths relative to `.content/<[directoryName]>/`, forward-slashed, each
  /// already ciphered as that particular file wants.
  final Map<String, Uint8List> files;

  final int nodeCount;

  /// The directory this pack lives in: the last four bytes of [uuid] as
  /// uppercase hex.
  String get directoryName => uuid
      .sublist(12, 16)
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  /// Total bytes, for checking there is room before writing.
  int get byteCount => files.values.fold(0, (sum, f) => sum + f.length);
}

/// Assemble a pack for one story.
///
/// [deviceKey] comes from [luniiDeviceKey] over the target device's `.md`. It
/// only protects `bt`, but that is what ties the pack to that one storyteller,
/// so a pack built for one device is not valid on another.
DevicePack buildDevicePack({
  required List<DevicePackChapter> chapters,
  required List<int> deviceKey,
  IndexedImage? cover,
  Uint8List? uuid,
  Random? rng,
}) {
  if (chapters.isEmpty) {
    throw const DevicePackException('A pack needs at least one chapter');
  }
  if (deviceKey.length != 4) {
    throw DevicePackException(
      'A device key is four words, got ${deviceKey.length}',
    );
  }
  final random = rng ?? Random();
  final packUuid = uuid ?? _randomBytes(random, 16);
  if (packUuid.length != 16) {
    throw DevicePackException('A uuid is 16 bytes, got ${packUuid.length}');
  }

  // Assets first: the node graph refers to them by index, so they have to be
  // numbered before the nodes can be written.
  final images = <IndexedImage>[];
  final sounds = <Uint8List>[];
  final imageIndexForChapter = <int>[];

  int addImage(IndexedImage image) {
    _checkImage(image, images.length);
    images.add(image);
    return images.length - 1;
  }

  final coverIndex = cover == null ? -1 : addImage(cover);
  for (var i = 0; i < chapters.length; i++) {
    final own = chapters[i].image;
    imageIndexForChapter.add(own == null ? coverIndex : addImage(own));
    _checkAudio(chapters[i].audio, i);
    sounds.add(chapters[i].audio);
  }

  // One node for the cover, then one per chapter.
  final nodeCount = chapters.length + 1;

  // A straight line needs one list entry per hop: entry i sends node i to
  // node i+1, so the last chapter has nowhere to go and ends the story.
  final list = Int32List(chapters.length);
  for (var i = 0; i < chapters.length; i++) {
    list[i] = i + 1;
  }

  final nodes = <_Node>[
    // The cover. The device waits here until OK is pressed, so no autoplay —
    // and no sound, since a generated story has no title jingle to play.
    _Node(
      image: coverIndex,
      audio: -1,
      okTransition: const _Transition(0, 1, 0),
      wheel: false,
      ok: true,
      home: false,
      pause: false,
      autoplay: false,
    ),
    for (var i = 0; i < chapters.length; i++)
      _Node(
        image: imageIndexForChapter[i],
        audio: i,
        // The last chapter has no onward link, so the device returns to the
        // pack list when it finishes.
        okTransition: i == chapters.length - 1
            ? null
            : _Transition(i + 1, 1, 0),
        wheel: false,
        ok: i != chapters.length - 1,
        home: true,
        pause: true,
        autoplay: true,
      ),
  ];

  // Asset names are eight hex digits, unique inside the pack; the index entry
  // and the file on disk have to agree exactly.
  final imageNames = _uniqueNames(random, images.length);
  final soundNames = _uniqueNames(random, sounds.length);

  final riPlain = _assetIndex(imageNames);
  final siPlain = _assetIndex(soundNames);
  final riCiphered = luniiCipher(riPlain, luniiGenericKey);

  final files = <String, Uint8List>{
    // `ni` is stored in the clear. It is an index like the others and the
    // reverse-engineering notes list it among the encrypted files, but
    // ciphering it corrupts the header while leaving the nodes past byte 512
    // looking perfectly valid.
    'ni': _nodeIndex(nodes, images.length, sounds.length),
    'li': luniiCipher(Uint8List.sublistView(list), luniiGenericKey),
    'ri': riCiphered,
    'si': luniiCipher(siPlain, luniiGenericKey),
    'bt': _bootFile(riCiphered, deviceKey),
    'nm': Uint8List(0),
    for (var i = 0; i < images.length; i++)
      'rf/000/${imageNames[i]}': luniiCipher(
        encodeBmpRle4(images[i]),
        luniiGenericKey,
      ),
    for (var i = 0; i < sounds.length; i++)
      'sf/000/${soundNames[i]}': luniiCipher(sounds[i], luniiGenericKey),
  };

  return DevicePack(uuid: packUuid, files: files, nodeCount: nodeCount);
}

/// The head of the *already ciphered* `ri`, ciphered again with the device
/// key, so deciphering it reproduces `ri` exactly as stored. That identity is
/// what ties a pack to one storyteller, and it is the check
/// `tool/lunii_probe.dart` runs against every pack on a device.
///
/// **Unverified when there are fewer than six images.** Every pack on the
/// device has at least six, so its `ri` comfortably exceeds 64 bytes and the
/// head simply exists. A generated story whose chapters share one cover has a
/// 12-byte `ri`, and what the firmware does when it goes looking for 64 bytes
/// of a 12-byte file is not a question any pack on the device can answer.
/// Zero-padding at least keeps `bt` the fixed 64 bytes every real one is. The
/// first write to a device is what will settle it; see the open question in
/// `docs/lunii-sync.md`.
Uint8List _bootFile(Uint8List riCiphered, List<int> deviceKey) {
  final head = Uint8List(_bootSize);
  final available = riCiphered.length < _bootSize
      ? riCiphered.length
      : _bootSize;
  head.setRange(0, available, riCiphered);
  return luniiCipher(head, deviceKey);
}

/// The device shows exactly one size, and a mis-sized image is the kind of
/// thing that only shows up as a scrambled screen.
void _checkImage(IndexedImage image, int at) {
  if (image.width != _imageWidth || image.height != _imageHeight) {
    throw DevicePackException(
      'Image $at is ${image.width}×${image.height}; the device shows '
      '$_imageWidth×$_imageHeight',
    );
  }
}

/// Last chance to catch audio in the wrong format. Past here it is ciphered,
/// on a device, and silent.
void _checkAudio(Uint8List audio, int chapter) {
  final header = Mp3FrameHeader.parse(audio);
  if (header == null) {
    throw DevicePackException(
      'Chapter ${chapter + 1} does not begin with an MP3 frame',
    );
  }
  if (header.version != MpegVersion.mpeg1 ||
      header.layer != 3 ||
      header.sampleRate != 44100 ||
      header.mode != ChannelMode.mono) {
    throw DevicePackException(
      'Chapter ${chapter + 1} is ${header.summary}; the device plays '
      'MPEG1 L3 44100Hz mono',
    );
  }
}

/// `000\XXXXXXXX` per asset, back to back.
Uint8List _assetIndex(List<String> names) {
  final out = Uint8List(names.length * _assetEntrySize);
  for (var i = 0; i < names.length; i++) {
    out.setRange(
      i * _assetEntrySize,
      (i + 1) * _assetEntrySize,
      '000\\${names[i]}'.codeUnits,
    );
  }
  return out;
}

/// A 512-byte header followed by one 44-byte entry per stage node.
Uint8List _nodeIndex(List<_Node> nodes, int images, int sounds) {
  final out = Uint8List(_headerSize + nodes.length * _nodeSize);
  final view = ByteData.sublistView(out);
  view.setUint16(0x00, _formatVersion, Endian.little);
  view.setUint16(0x02, _packVersion, Endian.little);
  view.setUint32(0x04, _headerSize, Endian.little);
  view.setUint32(0x08, _nodeSize, Endian.little);
  view.setUint32(0x0C, nodes.length, Endian.little);
  // These two must match the `ri` and `si` entry counts exactly.
  view.setUint32(0x10, images, Endian.little);
  view.setUint32(0x14, sounds, Endian.little);
  view.setUint8(0x18, _controlByte);

  for (var i = 0; i < nodes.length; i++) {
    nodes[i].writeTo(view, _headerSize + i * _nodeSize);
  }
  return out;
}

/// Distinct eight-digit hex names.
List<String> _uniqueNames(Random rng, int count) {
  final names = <String>{};
  while (names.length < count) {
    names.add(
      rng.nextInt(1 << 32).toRadixString(16).padLeft(8, '0').toUpperCase(),
    );
  }
  return names.toList();
}

Uint8List _randomBytes(Random rng, int count) =>
    Uint8List.fromList(List<int>.generate(count, (_) => rng.nextInt(256)));

/// Where a button leads: a slice of `li` at [listIndex] running [count]
/// entries, of which [optionIndex] is taken when the wheel is not in play.
class _Transition {
  const _Transition(this.listIndex, this.count, this.optionIndex);
  final int listIndex;
  final int count;
  final int optionIndex;
}

class _Node {
  const _Node({
    required this.image,
    required this.audio,
    required this.okTransition,
    required this.wheel,
    required this.ok,
    required this.home,
    required this.pause,
    required this.autoplay,
  });

  /// Indexes into `ri` and `si`; -1 for none.
  final int image;
  final int audio;
  final _Transition? okTransition;

  /// The five buttons and behaviours, in the order they sit at 0x20.
  final bool wheel;
  final bool ok;
  final bool home;
  final bool pause;
  final bool autoplay;

  void writeTo(ByteData view, int at) {
    view.setInt32(at + 0x00, image, Endian.little);
    view.setInt32(at + 0x04, audio, Endian.little);
    _writeTransition(view, at + 0x08, okTransition);
    // Home is never wired up: backing out of a bedtime story should return to
    // the pack list, which is what an absent transition already does.
    _writeTransition(view, at + 0x14, null);
    // Five uint16 flags, then two bytes of padding to reach 44.
    view.setUint16(at + 0x20, wheel ? 1 : 0, Endian.little);
    view.setUint16(at + 0x22, ok ? 1 : 0, Endian.little);
    view.setUint16(at + 0x24, home ? 1 : 0, Endian.little);
    view.setUint16(at + 0x26, pause ? 1 : 0, Endian.little);
    view.setUint16(at + 0x28, autoplay ? 1 : 0, Endian.little);
  }

  static void _writeTransition(ByteData view, int at, _Transition? t) {
    view.setInt32(at, t?.listIndex ?? -1, Endian.little);
    view.setInt32(at + 4, t?.count ?? -1, Endian.little);
    view.setInt32(at + 8, t?.optionIndex ?? -1, Endian.little);
  }
}
