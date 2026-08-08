import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/narration.dart';
import '../ai/provider_exceptions.dart';
import '../secrets/secret_store.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// ElevenLabs TTS — the most expressive, best for distinct character voices.
/// Needs its own key. `voiceName` is an ElevenLabs voice id.
/// See `docs/voice-tts.md`.
class ElevenLabsTtsSynthesizer implements TtsSynthesizer {
  ElevenLabsTtsSynthesizer({
    required SecretStore secrets,
    http.Client? httpClient,
    this.voiceName = '21m00Tcm4TlvDq8ikWAM', // "Rachel"
    this.model = 'eleven_multilingual_v2',
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'elevenlabs';
  static const String _base = 'https://api.elevenlabs.io/v1/text-to-speech';

  /// Friendly name → voice id for the Settings picker.
  static const Map<String, String> presets = {
    'Rachel (warm)': '21m00Tcm4TlvDq8ikWAM',
    'Bella (soft)': 'EXAVITQu4vr4xnSDxMaL',
    'Elli (young)': 'MF3mGyEYCl7XYWbV9V6O',
    'Antoni (male)': 'ErXwobaYiN019PkySvjV',
  };

  final SecretStore _secrets;
  final http.Client _http;
  final String voiceName;
  final String model;

  @override
  String get mimeType => 'audio/mpeg';

  @override
  String get voiceSignature => 'elevenlabs/$model/$voiceName';

  @override
  Future<Uint8List> synthesize(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
    NarrationCue cue = const NarrationCue(),
    String standingDirection = '',
  }) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No ElevenLabs API key configured.');
    }
    final response = await _http.post(
      Uri.parse('$_base/$voiceName?output_format=mp3_44100_128'),
      headers: {
        'xi-api-key': key,
        'accept': 'audio/mpeg',
        'content-type': 'application/json',
      },
      // v2 takes no free-text direction, so the cue is expressed through the
      // voice settings it does have: lower stability lets the reading move
      // more, which is what a cue with any feeling in it is asking for.
      body: jsonEncode({
        'text': text,
        'model_id': model,
        if (!cue.isEmpty)
          'voice_settings': {
            'stability': cue.emotion.isEmpty ? 0.5 : 0.35,
            'similarity_boost': 0.75,
            'style': cue.emotion.isEmpty ? 0.0 : 0.35,
            'use_speaker_boost': true,
          },
      }),
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(response.statusCode, response.body);
    }
    return response.bodyBytes;
  }
}
