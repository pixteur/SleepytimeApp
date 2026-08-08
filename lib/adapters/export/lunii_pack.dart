/// Builds a **STUdio story pack** — the format the open-source STUdio tool
/// reads and transfers onto a Lunii "Ma Fabrique à Histoires" storyteller.
///
/// A pack is a zip of `story.json` plus an `assets/` folder. The story is a
/// little graph: *stage* nodes play an audio file and show an image, *action*
/// nodes are the links between them. We lay a story out as a straight line —
///
/// ```
/// cover ─▶ chapter 1 ─▶ chapter 2 ─▶ … ─▶ chapter n
/// ```
///
/// — with `autoplay` on each chapter, so it runs start to finish on its own
/// and OK skips ahead. Asset filenames are arbitrary (STUdio resolves them by
/// the names in `story.json` and picks the codec from the extension), and
/// STUdio resamples the audio when it transfers to the device, so we can hand
/// over our cached narration untouched.
///
/// See `docs/lunii-export.md`.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One chapter's narration, straight from the audio cache.
class LuniiChapter {
  const LuniiChapter({
    required this.name,
    required this.audio,
    required this.mimeType,
  });

  /// Node name — shows in STUdio's editor, not on the device.
  final String name;
  final Uint8List audio;

  /// The audio's mime type, used to pick the asset's file extension.
  final String mimeType;
}

/// Pack a story into STUdio archive-format zip bytes.
Uint8List encodeLuniiPack({
  required String title,
  required String description,
  required List<LuniiChapter> chapters,
  Uint8List? cover,
  Random? rng,
}) {
  if (chapters.isEmpty) {
    throw ArgumentError.value(chapters, 'chapters', 'A pack needs a chapter');
  }
  final ids = _Ids(rng ?? Random());
  final archive = Archive();

  void addAsset(String name, Uint8List bytes) =>
      archive.addFile(ArchiveFile('assets/$name', bytes.length, bytes));

  String? coverAsset;
  if (cover != null) {
    coverAsset = 'cover.bmp';
    addAsset(coverAsset, cover);
  }

  // One uuid per chapter up front, so each node can point at the next.
  final chapterIds = [for (var i = 0; i < chapters.length; i++) ids.next()];

  // The cover: the device sits here until OK is pressed, so no autoplay.
  final stageNodes = <Map<String, dynamic>>[];
  final actionNodes = <Map<String, dynamic>>[];
  final coverLink = ids.next();
  stageNodes.add(
    _stage(
      uuid: ids.next(),
      name: title,
      image: coverAsset,
      audio: null,
      okTransition: _transition(coverLink),
      controls: const _Controls(ok: true),
      column: 0,
      squareOne: true,
    ),
  );
  // One option only: OK starts at chapter 1 and the story runs from there.
  // (A chapter picker would need a short spoken prompt per chapter, which is
  // not what a bedtime story wants.)
  actionNodes.add(
    _action(id: coverLink, name: 'Start', options: [chapterIds.first]),
  );

  for (var i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    final asset =
        'chapter-${(i + 1).toString().padLeft(2, '0')}'
        '${_extensionFor(chapter.mimeType)}';
    addAsset(asset, chapter.audio);

    // The last chapter ends the story: no onward link, so the device returns
    // to the pack list when it finishes.
    final isLast = i == chapters.length - 1;
    String? link;
    if (!isLast) {
      link = ids.next();
      actionNodes.add(
        _action(
          id: link,
          name: 'To chapter ${i + 2}',
          options: [chapterIds[i + 1]],
        ),
      );
    }
    stageNodes.add(
      _stage(
        uuid: chapterIds[i],
        name: chapter.name,
        image: coverAsset,
        audio: asset,
        okTransition: link == null ? null : _transition(link),
        // Plays through on its own; OK skips ahead, pause works, and home
        // backs out to the pack list.
        controls: _Controls(
          ok: !isLast,
          home: true,
          pause: true,
          autoplay: true,
        ),
        column: i + 1,
      ),
    );
  }

  final story = <String, dynamic>{
    'title': title,
    'description': description,
    'format': 'v1',
    'version': 1,
    'nightModeAvailable': false,
    'actionNodes': actionNodes,
    'stageNodes': stageNodes,
  };
  final storyBytes = utf8.encode(jsonEncode(story));
  archive.addFile(ArchiveFile('story.json', storyBytes.length, storyBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// STUdio picks an asset's codec from its extension, so this has to match what
/// the voice provider actually handed us.
String _extensionFor(String mimeType) {
  final mime = mimeType.toLowerCase();
  if (mime.contains('wav')) return '.wav';
  if (mime.contains('ogg')) return '.ogg';
  return '.mp3';
}

Map<String, dynamic> _stage({
  required String uuid,
  required String name,
  required String? image,
  required String? audio,
  required Map<String, dynamic>? okTransition,
  required _Controls controls,
  required int column,
  bool squareOne = false,
}) => {
  'uuid': uuid,
  'type': 'stage',
  'name': name,
  'image': image,
  'audio': audio,
  'okTransition': okTransition,
  'homeTransition': null,
  'controlSettings': controls.toJson(),
  // Laid out left to right so the graph is readable if it's opened in STUdio.
  'position': {'x': 100 + column * 220, 'y': 100},
  if (squareOne) 'squareOne': true,
};

Map<String, dynamic> _action({
  required String id,
  required String name,
  required List<String> options,
}) => {
  'id': id,
  'name': name,
  'options': options,
  'position': {'x': 0, 'y': 0},
};

Map<String, dynamic> _transition(String actionNode) => {
  'actionNode': actionNode,
  'optionIndex': 0,
};

/// The five buttons/behaviours the device offers on a node. STUdio requires
/// all five to be present.
class _Controls {
  const _Controls({
    this.ok = false,
    this.home = false,
    this.pause = false,
    this.autoplay = false,
  });

  /// Always off: the wheel picks between an action node's options, and a
  /// straight-line story never offers a choice.
  static const bool wheel = false;

  final bool ok;
  final bool home;
  final bool pause;
  final bool autoplay;

  Map<String, dynamic> toJson() => {
    'wheel': wheel,
    'ok': ok,
    'home': home,
    'pause': pause,
    'autoplay': autoplay,
  };
}

/// Random UUIDv4s for the node graph. The app's `Uuid` isn't used here so the
/// encoder stays a pure function of its inputs (seed it in tests).
class _Ids {
  _Ids(this._rng);

  final Random _rng;

  String next() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
