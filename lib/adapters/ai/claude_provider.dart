import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';
import '../secrets/secret_store.dart';
import 'ai_provider.dart';
import 'provider_exceptions.dart';
import 'story_segment_codec.dart';

/// The Anthropic (Claude) provider. Raw HTTP (`POST /v1/messages`) — there is no
/// official Anthropic SDK for Dart — with structured output via
/// `output_config.format`, so the model returns our exact StorySegment shape.
/// Bring-your-own-key (stored via [SecretStore]). See `docs/ai-providers.md`.
class ClaudeProvider implements AiProvider {
  ClaudeProvider({
    required SecretStore secrets,
    http.Client? httpClient,
    String model = 'claude-opus-4-8',
    int maxTokens = 2000,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client(),
       _model = model, // ignore: prefer_initializing_formals
       _maxTokens = maxTokens; // ignore: prefer_initializing_formals

  /// The SecretStore key name under which the Claude API key is stored.
  static const String keyName = 'claude';

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  final SecretStore _secrets;
  final http.Client _http;
  final String _model;
  final int _maxTokens;

  @override
  ProviderId get id => ProviderId.claude;

  @override
  Future<bool> isReady() async {
    final key = await _secrets.readKey(keyName);
    return key != null && key.isNotEmpty;
  }

  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Claude API key configured.');
    }

    final response = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'system': prompt.system,
        'messages': [
          {'role': 'user', 'content': prompt.user},
        ],
        'output_config': {
          'format': {'type': 'json_schema', 'schema': jsonStorySchema},
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
    if (decoded['stop_reason'] == 'refusal') {
      throw const ProviderRefusal('The model declined to generate this story.');
    }

    final content = (decoded['content'] as List<dynamic>?) ?? const [];
    final textBlock = content.cast<Map<String, dynamic>>().firstWhere(
      (b) => b['type'] == 'text',
      orElse: () => const {},
    );
    final jsonText = textBlock['text'] as String?;
    if (jsonText == null || jsonText.isEmpty) {
      throw const ProviderRequestException(200, 'No text block in response.');
    }
    return storySegmentFromJson(jsonDecode(jsonText) as Map<String, dynamic>);
  }
}
