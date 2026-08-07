import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../ai/provider_exceptions.dart';
import '../ai/story_segment_codec.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// Gemini TTS (`gemini-2.5-flash-preview-tts`, `responseModalities: [AUDIO]`).
/// Returns raw 16-bit PCM which we wrap in a WAV container. Reuses the parent's
/// Gemini key. See `docs/voice-tts.md`.
class GeminiTtsSynthesizer implements TtsSynthesizer {
  GeminiTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = 'Kore',
    this.model = 'gemini-2.5-flash-preview-tts',
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'gemini';
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const List<String> voices = [
    'Kore',
    'Aoede',
    'Puck',
    'Zephyr',
    'Charon',
    'Fenrir',
  ];

  final SecretStore _secrets;
  final http.Client _http;
  final String voiceName;
  final String model;

  @override
  String get mimeType => 'audio/wav';

  @override
  String get voiceSignature => 'gemini/$model/$voiceName';

  @override
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    final response = await _http.post(
      Uri.parse('$_base/$model:generateContent'),
      headers: {'content-type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': text},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': voiceName},
            },
          },
        },
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final parts =
        (((decoded['candidates'] as List<dynamic>?)?.firstOrNull
                    as Map<String, dynamic>?)?['content']
                as Map<String, dynamic>?)?['parts']
            as List<dynamic>?;
    final inline =
        (parts?.firstOrNull as Map<String, dynamic>?)?['inlineData']
            as Map<String, dynamic>?;
    final data = inline?['data'] as String?;
    if (data == null || data.isEmpty) {
      throw const ProviderRequestException(200, 'No audio data in response.');
    }
    final pcm = base64.decode(data);
    return pcmToWav(pcm, sampleRate: _rateFrom(inline?['mimeType'] as String?));
  }

  /// Parse the sample rate from a mime type like `audio/L16;rate=24000`.
  int _rateFrom(String? mime) {
    if (mime == null) return 24000;
    final match = RegExp(r'rate=(\d+)').firstMatch(mime);
    return match != null ? int.parse(match.group(1)!) : 24000;
  }
}
