import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleepytime/adapters/audio/mp3_encoder.dart';
import 'package:sleepytime/adapters/audio/mp3_frame.dart';
import 'package:sleepytime/adapters/lunii/device_writer.dart';
import 'package:sleepytime/adapters/lunii/lunii_cipher.dart';
import 'package:sleepytime/adapters/lunii/lunii_transfer.dart';
import 'package:sleepytime/adapters/tts/audio_compression.dart';
import 'package:sleepytime/adapters/tts/tts_synthesizer.dart';

/// The seam between a story's cached narration and a pack on a device.
///
/// Everything either side of it is covered — the encoder, the pack builder,
/// the writer — but the joining up was not, and that is where the decisions
/// live: which chapters go, what happens to a voice whose audio cannot be
/// re-encoded, and what the grown-up is told afterwards.
///
/// [buildAndWritePack] is the worker [sendStoryToLunii] runs in an isolate.
/// Testing it directly keeps these synchronous and lets them look at the
/// files that land.
void main() {
  late Directory temp;
  late String root;

  /// A storyteller-shaped directory. Arbitrary `.md` bytes are enough: the key
  /// derivation just deciphers them, and a pack written with the result reads
  /// back with it.
  void makeDevice() {
    root = temp.path;
    final md = Uint8List(0x200);
    for (var i = 0; i < md.length; i++) {
      md[i] = (i * 17 + 3) & 0xFF;
    }
    File('$root/.md').writeAsBytesSync(md);
    File('$root/.pi').writeAsBytesSync(Uint8List(0));
    File('$root/.cfg').writeAsStringSync('volume=3\n');
    Directory('$root/.content').createSync();
  }

  /// A cached chunk: half a second of tone, wrapped as WAV and compressed the
  /// way the audio cache stores it.
  Uint8List wavChunk({double seconds = 0.5, int rate = 24000}) {
    final frames = (rate * seconds).round();
    final samples = Int16List(frames);
    for (var i = 0; i < frames; i++) {
      samples[i] = ((i % 50) - 25) * 300;
    }
    return compressAudio(
      pcmToWav(Uint8List.sublistView(samples), sampleRate: rate),
    );
  }

  /// A cached chunk that is already MP3, as the ElevenLabs and OpenAI voices
  /// return — either what the device plays or, deliberately, not.
  ///
  /// The frames have to be spaced by the length their own header declares. A
  /// scan will not trust a lone sync pattern with nothing that follows on from
  /// it, so frames at the wrong stride read as no MP3 at all rather than as
  /// the wrong one.
  Uint8List mp3Chunk({bool deviceReady = true}) {
    // MPEG1 128 kbps at 44100: 144 * 128000 / 44100. MPEG2 64 kbps at 22050:
    // 72 * 64000 / 22050.
    final stride = deviceReady ? 417 : 208;
    final header = deviceReady
        ? const [0xFF, 0xFB, 0x90, 0xC0] // MPEG1 44100 mono
        : const [0xFF, 0xF3, 0x90, 0xC0]; // MPEG2 22050 mono
    final bytes = Uint8List(stride * 3);
    for (var i = 0; i < 3; i++) {
      bytes.setRange(i * stride, i * stride + 4, header);
    }
    return compressAudio(bytes);
  }

  LuniiTransferRequest request({
    required List<List<Uint8List>> chapters,
    int skipped = 0,
    LuniiCoverMotif motif = LuniiCoverMotif.nightSky,
  }) => LuniiTransferRequest(
    drive: root,
    backupDirectory: '${temp.path}/backup',
    title: "Ashi's adventure",
    chapterChunks: chapters,
    skipped: skipped,
    motif: motif,
  );

  setUp(() => temp = Directory.systemTemp.createTempSync('lunii_transfer'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('what the grown-up is told', () {
    test('names the chapters, the size and the drive', () {
      const transfer = LuniiTransfer(
        packName: 'E7E036FC',
        chapters: 6,
        skipped: 0,
        bytes: 23524892,
        drive: 'F:',
      );
      expect(
        transfer.summary,
        '6 chapters (22.4 MB) sent to the storyteller on F:',
      );
    });

    test('says when chapters were left behind', () {
      const transfer = LuniiTransfer(
        packName: 'A1B2C3D4',
        chapters: 1,
        skipped: 2,
        bytes: 1048576,
        drive: 'F:',
      );
      expect(transfer.summary, contains('1 chapter ('));
      expect(transfer.summary, contains('2 not downloaded yet, left out'));
    });
  });

  group('audio the device cannot play', () {
    test('MP3 already in the device\'s format goes straight through', () {
      makeDevice();
      final transfer = buildAndWritePack(
        request(
          chapters: [
            [mp3Chunk(), mp3Chunk()],
          ],
        ),
      );
      expect(transfer.chapters, 1);
      // The chunks are concatenated untouched, so the sound file on the
      // device is exactly the two of them.
      final dir = '$root/.content/${transfer.packName}/sf/000';
      final written = Directory(dir).listSync().whereType<File>().single;
      expect(written.lengthSync(), 417 * 6);
    });

    test('MP3 at another rate is refused, naming what it found', () {
      makeDevice();
      expect(
        () => buildAndWritePack(
          request(
            chapters: [
              [mp3Chunk(deviceReady: false)],
            ],
          ),
        ),
        throwsA(
          isA<LuniiDeviceException>()
              .having((e) => e.message, 'names the format', contains('22050'))
              .having(
                (e) => e.message,
                'suggests a way round',
                contains('story pack export'),
              ),
        ),
      );
    });

    test('nothing to send is refused before the device is touched', () {
      makeDevice();
      expect(
        () => buildAndWritePack(request(chapters: const [])),
        throwsA(isA<LuniiDeviceException>()),
      );
      expect(File('$root/.pi').lengthSync(), 0);
    });

    test('a drive that is not a storyteller is refused', () {
      root = temp.path; // no .md, .pi or .content
      expect(
        () => buildAndWritePack(
          request(
            chapters: [
              [mp3Chunk()],
            ],
          ),
        ),
        throwsA(isA<LuniiDeviceException>()),
      );
    });
  });

  group(
    'building from cached WAV',
    () {
      setUp(makeDevice);

      test('each chapter becomes one sound the device will play', () {
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [wavChunk(), wavChunk()],
              [wavChunk()],
              [wavChunk(), wavChunk(), wavChunk()],
            ],
          ),
        );
        expect(transfer.chapters, 3);
        expect(transfer.drive, root);

        final sounds = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().toList();
        expect(sounds.length, 3, reason: 'one per chapter, chunks joined');
        for (final sound in sounds) {
          final plain = luniiPlain(sound);
          expect(
            Mp3FrameHeader.parse(plain)?.summary,
            'MPEG1 L3 ${luniiSampleRate}Hz ${luniiBitrateKbps}kbps mono',
          );
        }
      });

      test('the pack lands in .pi and nothing else on the device changes', () {
        final before = File('$root/.cfg').readAsStringSync();
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
          ),
        );
        final device = LuniiDevice.open(root);
        expect(device.packDirectories, [transfer.packName]);
        expect(File('$root/.cfg').readAsStringSync(), before);
        expect(File('${temp.path}/backup/pi.bak').existsSync(), isTrue);
      });

      test('the cover motif picks the picture', () {
        final velo = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
            motif: LuniiCoverMotif.velo,
          ),
        );
        final image = File(
          Directory(
            '$root/.content/${velo.packName}/rf/000',
          ).listSync().whereType<File>().single.path,
        );
        // Both motifs are 320×240 in sixteen colours, so the check that they
        // differ is the bytes themselves.
        makeDevice();
        final sky = buildAndWritePack(
          request(
            chapters: [
              [wavChunk()],
            ],
          ),
        );
        final other = File(
          Directory(
            '$root/.content/${sky.packName}/rf/000',
          ).listSync().whereType<File>().single.path,
        );
        expect(image.readAsBytesSync(), isNot(other.readAsBytesSync()));
      });

      test('dead air in a chunk does not reach the device', () {
        // Half a second of tone then ten seconds of nothing, the shape a
        // glitched chapter came back in. Sixty seconds of real audio would be
        // far bigger than what a trimmed one encodes to.
        final glitched = compressAudio(
          pcmToWav(
            Uint8List.sublistView(
              Int16List(24000 * 11)
                ..setRange(0, 12000, List.filled(12000, 6000)),
            ),
            sampleRate: 24000,
          ),
        );
        final transfer = buildAndWritePack(
          request(
            chapters: [
              [glitched],
            ],
          ),
        );
        final sound = Directory(
          '$root/.content/${transfer.packName}/sf/000',
        ).listSync().whereType<File>().single;
        // One second at 128 kbps is about 16 kB; eleven would be about 176.
        expect(sound.lengthSync(), lessThan(40 * 1024));
      });
    },
    skip: canEncodeMp3 ? false : 'needs the vendored LAME (Windows)',
  );
}

/// An asset as it sits on the device is ciphered over its first sector, so it
/// has to be deciphered before it looks like an MP3 again.
Uint8List luniiPlain(File file) =>
    luniiDecipher(file.readAsBytesSync(), luniiGenericKey);
