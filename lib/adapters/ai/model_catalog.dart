/// Asking each provider what it can actually do, instead of hard-coding model
/// ids that go stale.
///
/// A hard-coded default is wrong twice: the day the provider retires it, and
/// every day a better model exists that we haven't shipped a release to reach.
/// Both have bitten this app — the voice settings carried a free-text "Model
/// (advanced)" box whose whole purpose was working around a retired or
/// rate-limited id by hand.
///
/// One directory per **vendor**, not per role: a vendor's list endpoint returns
/// its whole catalogue, so the same call fills both the story dropdown and the
/// voice dropdown. See `docs/ai-providers.md`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../secrets/secret_store.dart';
import 'provider_exceptions.dart';
import 'story_segment_codec.dart';

/// What a model is for, as far as this app is concerned.
enum ModelKind {
  /// Writes story text.
  text,

  /// Speaks it.
  audio,

  /// Embeddings, moderation, images, transcription — never offered.
  other,
}

/// One model, as the provider describes it plus what we can say about it.
class AiModel {
  const AiModel({
    required this.id,
    required this.label,
    required this.kind,
    this.note = '',
    this.preview = false,
  });

  /// The id sent on the wire.
  final String id;

  /// The provider's own display name where it gives one, else [id].
  final String label;

  final ModelKind kind;

  /// A short hint shown under the label. Everything here comes from the
  /// provider's own response or from the id — never a quality claim we cannot
  /// stand behind.
  final String note;

  /// Preview / experimental / beta. Worth surfacing because these carry much
  /// tighter free-tier limits — the daily cap that reads as "your key is
  /// broken" when it isn't.
  final bool preview;

  @override
  String toString() => '$id (${kind.name}${preview ? ', preview' : ''})';
}

/// Lists the models one vendor's key can reach.
abstract class ModelDirectory {
  /// The vendor's catalogue. Throws [ProviderNotConfigured] with no key, or
  /// [ProviderRequestException] if the vendor refuses — callers fall back to
  /// the manual field on either.
  Future<List<AiModel>> list();
}

/// True for ids that name themselves as not-for-production.
bool isPreviewId(String id) {
  final lower = id.toLowerCase();
  return lower.contains('preview') ||
      lower.contains('-exp') ||
      lower.contains('experimental') ||
      lower.contains('beta');
}

/// Anthropic — `GET /v1/models`. Text only; there is no Anthropic voice.
class AnthropicModelDirectory implements ModelDirectory {
  AnthropicModelDirectory({
    required SecretStore secrets,
    http.Client? httpClient,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'claude';
  static const String _endpoint =
      'https://api.anthropic.com/v1/models?limit=100';
  static const String _apiVersion = '2023-06-01';

  final SecretStore _secrets;
  final http.Client _http;

  @override
  Future<List<AiModel>> list() async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Claude API key configured.');
    }
    final response = await _http.get(
      Uri.parse(_endpoint),
      headers: {'x-api-key': key, 'anthropic-version': _apiVersion},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    // Arrives newest first, which is the order to show it in.
    return [
      for (final m in (decoded['data'] as List<dynamic>? ?? const []))
        if (m is Map<String, dynamic> && m['id'] is String)
          AiModel(
            id: m['id'] as String,
            label: (m['display_name'] as String?) ?? m['id'] as String,
            kind: ModelKind.text,
            note: _note(m['id'] as String),
            preview: isPreviewId(m['id'] as String),
          ),
    ];
  }

  /// Anthropic names its tiers in the id, and the trade-off between them holds
  /// across generations even as the numbers move.
  static String _note(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('opus')) return 'Most capable — best prose, slowest';
    if (lower.contains('sonnet')) return 'Balanced quality and speed';
    if (lower.contains('haiku')) return 'Fastest and cheapest';
    return '';
  }
}

/// OpenAI — `GET /v1/models`. One flat list of everything the key can reach, so
/// the kinds have to be sorted out from the ids.
class OpenAiModelDirectory implements ModelDirectory {
  OpenAiModelDirectory({required SecretStore secrets, http.Client? httpClient})
    : _secrets = secrets, // ignore: prefer_initializing_formals
      _http = httpClient ?? http.Client();

  static const String keyName = 'openai';
  static const String _endpoint = 'https://api.openai.com/v1/models';

  final SecretStore _secrets;
  final http.Client _http;

  @override
  Future<List<AiModel>> list() async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No OpenAI API key configured.');
    }
    final response = await _http.get(
      Uri.parse(_endpoint),
      headers: {'authorization': 'Bearer $key'},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final models = <AiModel>[
      for (final m in (decoded['data'] as List<dynamic>? ?? const []))
        if (m is Map<String, dynamic> && m['id'] is String)
          _classify(m['id'] as String),
    ];
    models.sort((a, b) => a.id.compareTo(b.id));
    return models;
  }

  /// OpenAI's list is everything at once — chat models beside embeddings,
  /// images, moderation and transcription. Only the two kinds this app can use
  /// survive; anything unrecognised is dropped rather than offered blind.
  static AiModel _classify(String id) {
    final lower = id.toLowerCase();
    ModelKind kind;
    var note = '';
    if (lower.contains('tts')) {
      kind = ModelKind.audio;
      note = 'Speaks text aloud';
    } else if (lower.contains('embedding') ||
        lower.contains('moderation') ||
        lower.contains('whisper') ||
        lower.contains('transcribe') ||
        lower.contains('dall-e') ||
        lower.contains('image') ||
        lower.contains('sora') ||
        lower.contains('davinci') ||
        lower.contains('babbage') ||
        lower.contains('realtime') ||
        lower.contains('audio') ||
        lower.contains('search') ||
        lower.contains('codex')) {
      kind = ModelKind.other;
    } else if (lower.startsWith('gpt') ||
        lower.startsWith('o1') ||
        lower.startsWith('o3') ||
        lower.startsWith('o4') ||
        lower.startsWith('chatgpt')) {
      kind = ModelKind.text;
      if (lower.contains('mini') || lower.contains('nano')) {
        note = 'Smaller — faster and cheaper';
      }
    } else {
      kind = ModelKind.other;
    }
    return AiModel(
      id: id,
      label: id,
      kind: kind,
      note: note,
      preview: isPreviewId(id),
    );
  }
}

/// Google — `GET /v1beta/models`. The response says what each model supports,
/// so the text/audio split is read rather than guessed.
class GoogleModelDirectory implements ModelDirectory {
  GoogleModelDirectory({required SecretStore secrets, http.Client? httpClient})
    : _secrets = secrets, // ignore: prefer_initializing_formals
      _http = httpClient ?? http.Client();

  static const String keyName = 'gemini';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models?pageSize=200';

  final SecretStore _secrets;
  final http.Client _http;

  @override
  Future<List<AiModel>> list() async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No Gemini API key configured.');
    }
    final response = await _http.get(
      Uri.parse(_endpoint),
      headers: {'x-goog-api-key': key},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final out = <AiModel>[];
    for (final m in (decoded['models'] as List<dynamic>? ?? const [])) {
      if (m is! Map<String, dynamic>) continue;
      // "models/gemini-2.5-flash" — the API wants the bare id back.
      final id = ((m['name'] as String?) ?? '').replaceFirst('models/', '');
      if (id.isEmpty) continue;
      final methods = [
        for (final s in (m['supportedGenerationMethods'] as List? ?? const []))
          s.toString(),
      ];
      out.add(
        AiModel(
          id: id,
          label: (m['displayName'] as String?) ?? id,
          kind: _kindOf(id, methods),
          note: _note(id, _kindOf(id, methods)),
          preview: isPreviewId(id),
        ),
      );
    }
    return out;
  }

  /// Families that answer `generateContent` but do not write prose. Checked
  /// against a live catalogue: Google's image, music, robotics and computer-use
  /// models all advertise `generateContent`, so without this list the app
  /// offered "nano-banana-pro-preview" and "lyria-3-pro-preview" as story
  /// writers — and, because "pro" is in the name, described a music generator
  /// as "most capable — best prose".
  static const List<String> _notForProse = [
    'image',
    'imagen',
    'veo',
    'lyria',
    'robotics',
    'computer-use',
    'embedding',
    'aqa',
  ];

  static ModelKind _kindOf(String id, List<String> methods) {
    final lower = id.toLowerCase();
    // Google's TTS models also advertise generateContent, so the id is the only
    // thing that tells them apart.
    if (lower.contains('tts')) return ModelKind.audio;
    if (_notForProse.any(lower.contains)) return ModelKind.other;
    if (!lower.startsWith('gemini') && !lower.startsWith('gemma')) {
      return ModelKind.other;
    }
    if (methods.contains('generateContent')) return ModelKind.text;
    return ModelKind.other;
  }

  static String _note(String id, ModelKind kind) {
    // A note is a claim about what a model is good at, so it must not outlive
    // the classification: "most capable — best prose" on a music generator is
    // exactly the kind of confident wrong answer this file exists to avoid.
    if (kind == ModelKind.other) return '';
    final lower = id.toLowerCase();
    if (lower.contains('tts')) return 'Speaks text aloud';
    // Before the tier words, or "deep-research-pro" reads as a prose model.
    if (lower.contains('deep-research')) {
      return 'Research agent — slow and costly for stories';
    }
    if (lower.startsWith('gemma')) return 'Open model — lighter, less polished';
    if (lower.contains('flash-lite')) return 'Cheapest and fastest';
    if (lower.contains('flash')) return 'Fast, good value';
    if (lower.contains('pro')) return 'Most capable — best prose';
    return '';
  }
}

/// ElevenLabs — `GET /v1/models`. Voice only, and the response flags which
/// models can speak, so nothing is guessed from the id.
class ElevenLabsModelDirectory implements ModelDirectory {
  ElevenLabsModelDirectory({
    required SecretStore secrets,
    http.Client? httpClient,
  }) : _secrets = secrets, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  static const String keyName = 'elevenlabs';
  static const String _endpoint = 'https://api.elevenlabs.io/v1/models';

  final SecretStore _secrets;
  final http.Client _http;

  @override
  Future<List<AiModel>> list() async {
    final key = await _secrets.readKey(keyName);
    if (key == null || key.isEmpty) {
      throw const ProviderNotConfigured('No ElevenLabs API key configured.');
    }
    final response = await _http.get(
      Uri.parse(_endpoint),
      headers: {'xi-api-key': key},
    );
    if (response.statusCode != 200) {
      throw ProviderRequestException(
        response.statusCode,
        extractApiError(response.body),
      );
    }
    // This one returns a bare array rather than an object with `data`.
    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        : ((decoded as Map<String, dynamic>)['models'] as List<dynamic>? ??
              const []);
    return [
      for (final m in list)
        if (m is Map<String, dynamic> && m['model_id'] is String)
          AiModel(
            id: m['model_id'] as String,
            label: (m['name'] as String?) ?? m['model_id'] as String,
            kind: (m['can_do_text_to_speech'] as bool? ?? false)
                ? ModelKind.audio
                : ModelKind.other,
            note: clipNote((m['description'] as String?) ?? ''),
            preview: isPreviewId(m['model_id'] as String),
          ),
    ];
  }
}

/// A provider's prose description, cut to the one line a dropdown has room for.
String clipNote(String text, {int max = 80}) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= max) return oneLine;
  final cut = oneLine.substring(0, max);
  final stop = cut.lastIndexOf(' ');
  return '${stop > max ~/ 2 ? cut.substring(0, stop) : cut}…';
}
