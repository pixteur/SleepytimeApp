import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';
import '../secrets/secret_store.dart';
import 'ai_provider.dart';
import 'provider_exceptions.dart';
import 'story_segment_codec.dart';

/// The Google Gemini provider. `generateContent` with a structured
/// `responseSchema` (Gemini's own schema dialect: UPPERCASE types) so the model
/// returns our exact StorySegment shape. Bring-your-own-key.
/// See `docs/ai-providers.md`.
class GeminiProvider implements AiProvider {
  GeminiProvider({
    required SecretStore secrets,
    http.Client? httpClient,
    String model = 'gemini-2.5-flash',
    int maxTokens = 2000,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client(),
       _model = model, // ignore: prefer_initializing_formals
       _maxTokens = maxTokens; // ignore: prefer_initializing_formals

  static const String keyName = 'gemini';
  static const String _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final SecretStore _secrets;
  final http.Client _http;
  final String _model;
  final int _maxTokens;

  /// Gemini's schema dialect (UPPERCASE types). Mirrors [jsonStorySchema].
  static const Map<String, dynamic> _schema = {
    'type': 'OBJECT',
    'properties': {
      'story_text': {'type': 'STRING'},
      'summary': {'type': 'STRING'},
      'rating': {
        'type': 'STRING',
        'enum': ['tiny', 'little', 'big', 'older'],
      },
      'setting': {'type': 'STRING'},
      'sensitive_flags': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'characters': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'open_threads': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'is_final': {'type': 'BOOLEAN'},
    },
    'required': storySegmentFields,
  };

  @override
  ProviderId get id => ProviderId.gemini;

  @override
  Future<bool> isReady() async {
    final key = await _secrets.readKey(keyName);
    return key != null && key.isNotEmpty;
  }

  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }

    final response = await _http.post(
      Uri.parse('$_base/$_model:generateContent'),
      headers: {'content-type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': prompt.system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt.user},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _schema,
          'maxOutputTokens': _maxTokens,
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

    final blockReason =
        (decoded['promptFeedback'] as Map<String, dynamic>?)?['blockReason'];
    if (blockReason != null) {
      throw ProviderRefusal('Blocked: $blockReason');
    }

    final candidates = (decoded['candidates'] as List<dynamic>?) ?? const [];
    if (candidates.isEmpty) {
      throw const ProviderRequestException(200, 'No candidates in response.');
    }
    final candidate = candidates.first as Map<String, dynamic>;
    final finish = candidate['finishReason'];
    if (finish == 'SAFETY' ||
        finish == 'BLOCKLIST' ||
        finish == 'PROHIBITED_CONTENT') {
      throw ProviderRefusal('Stopped: $finish');
    }

    final parts =
        ((candidate['content'] as Map<String, dynamic>?)?['parts']
            as List<dynamic>?) ??
        const [];
    if (parts.isEmpty) {
      throw const ProviderRequestException(200, 'No content parts.');
    }
    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const ProviderRequestException(200, 'Empty content text.');
    }
    return storySegmentFromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
