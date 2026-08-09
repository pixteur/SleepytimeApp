/// FFI bindings to LAME (`libmp3lame.dll`).
///
/// A thin, mechanical translation of the subset of `lame.h` the app uses —
/// no policy lives here. What settings a Lunii storyteller wants is
/// [mp3_encoder.dart](mp3_encoder.dart)'s business.
///
/// The DLL is vendored at `windows/third_party/lame/` and installed next to
/// the executable; see the README there for provenance and licensing.
library;

import 'dart:ffi';
import 'dart:io';

/// The `MPEG_mode` enum from `lame.h`. Only the values the app sets.
abstract final class LameMode {
  static const int stereo = 0;
  static const int jointStereo = 1;
  static const int mono = 3;
}

/// LAME could not be loaded or refused a setting. Callers that want to degrade
/// gracefully — offer the STUdio zip instead of a direct device write — catch
/// this rather than let it escape to the UI.
class LameException implements Exception {
  const LameException(this.message);
  final String message;

  @override
  String toString() => 'LameException: $message';
}

/// `lame_global_flags*`, LAME's encoder handle. Opaque: it is only ever passed
/// back to LAME.
typedef LameGfp = Pointer<Void>;

/// One of LAME's many `lame_set_*(gfp, int)` setters.
typedef LameSetInt = int Function(LameGfp, int);

/// A setter that returns nothing, of which there is one.
typedef LameSetVoidInt = void Function(LameGfp, int);

/// `lame_init_params` and `lame_close`.
typedef LameGfpToInt = int Function(LameGfp);

/// `lame_encode_buffer` — planar samples, one pointer per channel.
typedef LameEncode =
    int Function(
      LameGfp,
      Pointer<Int16>,
      Pointer<Int16>,
      int,
      Pointer<Uint8>,
      int,
    );

/// `lame_encode_buffer_interleaved` — L R L R … in one buffer.
typedef LameEncodeInterleaved =
    int Function(LameGfp, Pointer<Int16>, int, Pointer<Uint8>, int);

/// `lame_encode_flush`.
typedef LameFlush = int Function(LameGfp, Pointer<Uint8>, int);

/// `lame_get_lametag_frame`.
typedef LameLametag = int Function(LameGfp, Pointer<Uint8>, int);

typedef _InitNative = LameGfp Function();
typedef _SetIntNative = Int32 Function(LameGfp, Int32);
typedef _SetVoidIntNative = Void Function(LameGfp, Int32);
typedef _GfpToIntNative = Int32 Function(LameGfp);
typedef _EncodeNative =
    Int32 Function(
      LameGfp,
      Pointer<Int16>,
      Pointer<Int16>,
      Int32,
      Pointer<Uint8>,
      Int32,
    );
typedef _EncodeInterleavedNative =
    Int32 Function(LameGfp, Pointer<Int16>, Int32, Pointer<Uint8>, Int32);
typedef _FlushNative = Int32 Function(LameGfp, Pointer<Uint8>, Int32);
typedef _LametagNative = Size Function(LameGfp, Pointer<Uint8>, Size);

/// The bound library. Open it once and reuse it — [instance] does that.
class Lame {
  Lame._(this._library)
    : init = _library.lookupFunction<_InitNative, LameGfp Function()>(
        'lame_init',
      ),
      setInSampleRate = _setter(_library, 'lame_set_in_samplerate'),
      setOutSampleRate = _setter(_library, 'lame_set_out_samplerate'),
      setNumChannels = _setter(_library, 'lame_set_num_channels'),
      setMode = _setter(_library, 'lame_set_mode'),
      setBitrateKbps = _setter(_library, 'lame_set_brate'),
      setQuality = _setter(_library, 'lame_set_quality'),
      setWriteVbrTag = _setter(_library, 'lame_set_bWriteVbrTag'),
      setWriteId3TagAutomatic = _library
          .lookupFunction<_SetVoidIntNative, LameSetVoidInt>(
            'lame_set_write_id3tag_automatic',
          ),
      initParams = _library.lookupFunction<_GfpToIntNative, LameGfpToInt>(
        'lame_init_params',
      ),
      encodeBuffer = _library.lookupFunction<_EncodeNative, LameEncode>(
        'lame_encode_buffer',
      ),
      encodeBufferInterleaved = _library
          .lookupFunction<_EncodeInterleavedNative, LameEncodeInterleaved>(
            'lame_encode_buffer_interleaved',
          ),
      encodeFlush = _library.lookupFunction<_FlushNative, LameFlush>(
        'lame_encode_flush',
      ),
      getLametagFrame = _library.lookupFunction<_LametagNative, LameLametag>(
        'lame_get_lametag_frame',
      ),
      close = _library.lookupFunction<_GfpToIntNative, LameGfpToInt>(
        'lame_close',
      );

  static LameSetInt _setter(DynamicLibrary lib, String symbol) =>
      lib.lookupFunction<_SetIntNative, LameSetInt>(symbol);

  /// Held so the library outlives the symbols looked up out of it.
  // ignore: unused_field
  final DynamicLibrary _library;

  /// Allocate an encoder. Returns `nullptr` if LAME is out of memory.
  final LameGfp Function() init;

  /// Rate of the samples handed to [encodeBuffer]. Set this and
  /// [setOutSampleRate] to different values and LAME resamples for you.
  final LameSetInt setInSampleRate;
  final LameSetInt setOutSampleRate;

  /// How many channels the *input* has. Independent of [setMode], which is
  /// what comes out: 2 in with [LameMode.mono] set downmixes.
  final LameSetInt setNumChannels;
  final LameSetInt setMode;
  final LameSetInt setBitrateKbps;

  /// 0 is best and slowest, 9 fastest; 2 is LAME's own "near best".
  final LameSetInt setQuality;

  /// Reserve a leading frame for the Xing/LAME tag. Doing so obliges the
  /// caller to fill it in afterwards with [getLametagFrame].
  final LameSetInt setWriteVbrTag;
  final LameSetVoidInt setWriteId3TagAutomatic;

  /// Lock the settings in. Negative means LAME rejected the combination.
  final LameGfpToInt initParams;

  /// Encode planar samples. With one input channel LAME ignores the right
  /// pointer outright, so passing the left one twice is fine.
  final LameEncode encodeBuffer;
  final LameEncodeInterleaved encodeBufferInterleaved;

  /// Pad and emit the final frames. Its buffer needs 7200 bytes.
  final LameFlush encodeFlush;

  /// Build the real Xing/LAME tag frame, to be written over the space
  /// [setWriteVbrTag] reserved at the head of the stream. Returns the bytes
  /// written, or — if that exceeds the buffer size — the size required.
  final LameLametag getLametagFrame;

  final LameGfpToInt close;

  static Lame? _instance;
  static bool _tried = false;

  /// The loaded library, or null if it isn't available on this machine. Null
  /// is the expected answer on a platform with no vendored build, so callers
  /// can offer the file-based export instead of failing.
  static Lame? get instanceOrNull {
    if (!_tried) {
      _tried = true;
      final path = _locate();
      if (path != null) {
        try {
          _instance = Lame._(DynamicLibrary.open(path));
        } on Object catch (_) {
          _instance = null; // wrong architecture, missing dependency, …
        }
      }
    }
    return _instance;
  }

  static Lame get instance =>
      instanceOrNull ??
      (throw const LameException(
        'libmp3lame could not be loaded. On Windows it ships next to the '
        'executable; see windows/third_party/lame/README.md.',
      ));

  /// Where the DLL might be.
  ///
  /// In the installed app it sits beside the executable, where Windows' own
  /// search order finds it by bare name. Under `flutter test` and
  /// `dart run tool/…` the executable is the Dart SDK's, so the vendored copy
  /// in the source tree has to be named outright — walking up from the working
  /// directory, since a test may be run from a subdirectory.
  static String? _locate() {
    if (!Platform.isWindows) return null;
    const vendored = 'windows/third_party/lame/libmp3lame.dll';
    const name = 'libmp3lame.dll';

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final beside = File('$exeDir${Platform.pathSeparator}$name');
    if (beside.existsSync()) return beside.path;

    var dir = Directory.current;
    for (var up = 0; up < 4; up++) {
      final candidate = File('${dir.path}/$vendored');
      if (candidate.existsSync()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}
