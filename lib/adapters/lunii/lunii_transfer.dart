/// Turning a story's cached narration into a pack on an attached storyteller.
///
/// The work — decompress, decode, trim, join, encode, cipher, write — is tens
/// of seconds of solid CPU and a couple of dozen megabytes of file I/O for a
/// six-chapter story. All of it runs in a worker isolate, because doing it on
/// the UI isolate would freeze the app for the duration.
///
/// What crosses into the isolate is the *compressed* cached chunks, a few
/// megabytes, rather than the decoded audio, which is an order of magnitude
/// larger. Everything downstream of that is pure Dart, FFI or file I/O, none
/// of which needs Flutter bindings.
///
/// See [docs/lunii-sync.md](../../../docs/lunii-sync.md).
library;

import 'dart:isolate';
import 'dart:typed_data';

import '../audio/mp3_encoder.dart';
import '../audio/mp3_decoder.dart';
import '../audio/wav.dart';
import '../export/cover_image.dart';

import '../tts/audio_compression.dart';
import 'device_pack.dart';
import 'device_writer.dart';

/// Which picture the storyteller shows while the story plays.
enum LuniiCoverMotif {
  nightSky('Night sky'),
  velo('Bicycle');

  const LuniiCoverMotif(this.label);
  final String label;
}

/// What was sent, for telling the grown-up afterwards.
class LuniiTransfer {
  const LuniiTransfer({
    required this.packName,
    required this.chapters,
    required this.skipped,
    required this.bytes,
    required this.drive,
  });

  final String packName;
  final int chapters;

  /// Chapters left out because their narration is not fully downloaded.
  final int skipped;
  final int bytes;
  final String drive;

  String get summary =>
      '$chapters chapter${chapters == 1 ? '' : 's'} '
      '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MB) sent to the '
      'storyteller on $drive'
      '${skipped > 0 ? ' — $skipped not downloaded yet, left out' : ''}';
}

/// Everything the worker needs, in plain values it can be handed.
class LuniiTransferRequest {
  const LuniiTransferRequest({
    required this.drive,
    required this.backupDirectory,
    required this.title,
    required this.chapterChunks,
    required this.skipped,
    required this.motif,
    this.titleChunks,
  });

  final String drive;
  final String backupDirectory;
  final String title;

  /// Per chapter, its cached chunks exactly as they sit in the audio cache —
  /// still compressed, so this stays small enough to hand across cheaply.
  final List<List<Uint8List>> chapterChunks;

  /// The story's title, spoken — cached chunks like any other clip. Null when
  /// it has not been synthesized, which leaves the cover silent as before
  /// rather than failing the transfer over a nicety.
  final List<Uint8List>? titleChunks;
  final int skipped;
  final LuniiCoverMotif motif;
}

/// Build a pack from [request] and install it, off the UI isolate.
Future<LuniiTransfer> sendStoryToLunii(LuniiTransferRequest request) =>
    Isolate.run(() => buildAndWritePack(request));

/// The worker. Top-level and synchronous on purpose: it is what
/// [sendStoryToLunii] runs, and `tool/lunii_write.dart` exercises the same
/// path from the command line.
LuniiTransfer buildAndWritePack(LuniiTransferRequest request) {
  if (request.chapterChunks.isEmpty) {
    throw const LuniiDeviceException(
      'No narration saved yet — play or download the story first.',
    );
  }
  final device = LuniiDevice.open(request.drive);

  final chapters = <DevicePackChapter>[];
  for (final chunks in request.chapterChunks) {
    chapters.add(DevicePackChapter(audio: _chapterAudio(chunks)));
  }

  final cover = switch (request.motif) {
    LuniiCoverMotif.velo => veloCoverIndexed(seed: request.title),
    LuniiCoverMotif.nightSky => nightSkyCoverIndexed(seed: request.title),
  };

  final titleChunks = request.titleChunks;
  final pack = buildDevicePack(
    chapters: chapters,
    deviceKey: device.deviceKey,
    cover: cover,
    titleAudio: titleChunks == null || titleChunks.isEmpty
        ? null
        : _chapterAudio(titleChunks),
  );
  writePack(device, pack, backupDirectory: request.backupDirectory);

  return LuniiTransfer(
    packName: pack.directoryName,
    chapters: chapters.length,
    skipped: request.skipped,
    bytes: pack.byteCount,
    drive: request.drive,
  );
}

/// One chapter's chunks as a single MP3 the device will play.
///
/// Every voice ends up in the same place — samples, trimmed, joined, encoded
/// at what the device plays — whether it handed back WAV or MP3. Going through
/// samples even for MP3 that is already the right shape costs a decode, and
/// buys a chapter that is one clean stream rather than several concatenated
/// ones, with the dead air taken out of each.
///
/// Trimming is per chunk rather than once at the end, because a provider's
/// dead air can land in the middle of a chapter as easily as after it. See
/// [trimTrailingSilence].
Uint8List _chapterAudio(List<Uint8List> chunks) {
  final parts = <WavAudio>[];
  for (final chunk in chunks) {
    final raw = decompressAudio(chunk);
    parts.add(
      trimTrailingSilence(_isMp3(raw) ? decodeMp3(raw) : decodeWav(raw)),
    );
  }
  return encodePcmToLuniiMp3(joinWav(parts));
}

/// Cached narration is WAV from most voices and MP3 from the rest, and the
/// cache does not record which. RIFF's magic is the tell.
bool _isMp3(Uint8List bytes) =>
    bytes.length < 4 ||
    !(bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46); //  F
