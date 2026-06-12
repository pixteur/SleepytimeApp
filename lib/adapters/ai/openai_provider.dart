import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/story_segment.dart';
import '../../domain/prompt_builder.dart';
import '../secrets/secret_store.dart';
import 'ai_provider.dart';
import 'provider_exceptions.dart';
import 'story_segment_codec.dart';

/// The OpenAI (ChatGPT) provider. Chat Completions API with Structured Outputs
/// (`response_format.json_schema`, strict) so the model returns our exact
/// StorySegment shape. Bring-your-own-key. See `docs/ai-providers.md`.
class OpenAiProvider implements AiProvider {
  OpenAiProvider({
    required SecretStore secrets,
    http.Client? httpClient,
    String model = 'gpt-4o',
    int maxTokens = 2000,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client(),
       _model = model, // ignore: prefer_initializing_formals
       _maxTokens = maxTokens; // ignore: prefer_initializing_formals

  static const String keyName = 'openai';
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  final SecretStore _secrets;
  final http.Client _http;
  final String _model;
  final int _maxTokens;

  @override
  ProviderId get id => ProviderId.openai;

  @override
  Future<bool> isReady() async {
    final key = await _secrets.readKey(keyName);
    return key != null && key.isNotEmpty;
  }

  @override
  Future<StorySegment> generate(StoryPrompt prompt) async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No OpenAI API key configured.');
    }

    final response = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': _maxTokens,
        'messages': [
          {'role': 'system', 'content': prompt.system},
          {'role': 'user', 'content': prompt.user},
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'story_segment',
            'strict': true,
            'schema': jsonStorySchema,
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
    final choices = (decoded['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) {
      throw const ProviderRequestException(200, 'No choices in response.');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    if (message['refusal'] != null) {
      throw ProviderRefusal(message['refusal'].toString());
    }
    final content = message['content'] as String?;
    if (content == null || content.isEmpty) {
      throw const ProviderRequestException(200, 'Empty message content.');
    }
    return storySegmentFromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
