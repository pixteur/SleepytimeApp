import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/ai_provider.dart';
import '../../adapters/ai/claude_provider.dart';
import '../../adapters/ai/gemini_provider.dart';
import '../../adapters/ai/openai_provider.dart';
import '../../adapters/prefs/app_prefs.dart';
import '../../adapters/secrets/secret_store.dart';
import '../../adapters/ai/model_catalog.dart';
import '../../app_providers.dart';
import '../../domain/prompt_builder.dart';
import 'about_section.dart';
import 'model_picker.dart';
import 'settings_section.dart';
import 'voice_section.dart';

/// The one parent-only settings page: parent mode, then story AI, then voice —
/// all on a single scroll, so a grown-up sets the app up in one pass. Reached
/// through the parent gate. Implements the CLAUDE.md rules: parent-gated key
/// entry + explicit disclosure/consent before any data is sent.
/// See `docs/safety.md`.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _ProviderMeta {
  const _ProviderMeta(this.id, this.label, this.hint, this.helpUrl);
  final ProviderId id;
  final String label;
  final String hint;
  final String helpUrl;
}

const _providers = [
  _ProviderMeta(
    ProviderId.claude,
    'Claude',
    'sk-ant-…',
    'console.anthropic.com',
  ),
  _ProviderMeta(ProviderId.openai, 'ChatGPT', 'sk-…', 'platform.openai.com'),
  _ProviderMeta(ProviderId.gemini, 'Gemini', 'AIza…', 'aistudio.google.com'),
];

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  ProviderId _provider = ProviderId.claude;

  /// The story model for [_provider]; blank means the adapter's own default.
  String _textModel = '';
  bool _consent = false;
  bool _hasStoredKey = false;
  bool _busy = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  _ProviderMeta get _meta => _providers.firstWhere((p) => p.id == _provider);

  Future<void> _load() async {
    final prefs = await AppPrefs.open();
    final provider = providerIdFromName(prefs.selectedProvider);
    final hasKey = await _keyPresent(provider);
    // Re-resolve so the status card reflects the saved key immediately.
    await ref.read(aiConfigProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _consent = prefs.aiConsentGiven;
      _hasStoredKey = hasKey;
      _keyHint = prefs.keyHint(keyNameFor(provider) ?? '');
      _textModel = prefs.textModel(provider.name) ?? '';
    });
  }

  /// The masked reminder of the saved key, e.g. `AIza••••7f2c`. Empty when no
  /// key is saved, or when it was saved before hints existed.
  String _keyHint = '';

  Future<bool> _keyPresent(ProviderId id) async {
    final name = keyNameFor(id);
    if (name == null) return false;
    return ref.read(secretStoreProvider).hasKey(name);
  }

  Future<void> _onProviderChanged(ProviderId id) async {
    final prefs = await AppPrefs.open();
    await prefs.setSelectedProvider(id.name);
    final hasKey = await _keyPresent(id);
    if (!mounted) return;
    setState(() {
      _provider = id;
      _hasStoredKey = hasKey;
      _keyHint = prefs.keyHint(keyNameFor(id) ?? '');
      // Per-provider, so switching back and forth keeps each one's choice.
      _textModel = prefs.textModel(id.name) ?? '';
      _status = null;
      _keyController.clear();
    });
    // Re-resolve immediately, or the status line goes on naming the provider
    // that was selected a moment ago — the chips said ChatGPT while the status
    // still read "Gemini (online)". It reports the offline placeholder for a
    // provider with no key yet, which is the truth.
    await ref.read(aiConfigProvider.notifier).refresh();
    await ref.read(textModelProvider.notifier).refresh();
  }

  /// Save the story model and rebuild the engine so the next chapter uses it.
  Future<void> _onTextModelChanged(String model) async {
    setState(() => _textModel = model);
    await (await AppPrefs.open()).setTextModel(_provider.name, model);
    await ref.read(textModelProvider.notifier).refresh();
  }

  String _defaultTextModel(ProviderId id) => switch (id) {
    ProviderId.openai => OpenAiProvider.defaultModel,
    ProviderId.gemini => GeminiProvider.defaultModel,
    _ => ClaudeProvider.defaultModel,
  };

  /// The provider "Save & test" exercises. Built with the *chosen* model, so a
  /// green tick means the model that will write tonight's story actually
  /// answered — not just that the key is valid for some other model.
  AiProvider _build(ProviderId id, SecretStore secrets) {
    final model = _textModel.isEmpty ? _defaultTextModel(id) : _textModel;
    return switch (id) {
      ProviderId.openai => OpenAiProvider(secrets: secrets, model: model),
      ProviderId.gemini => GeminiProvider(secrets: secrets, model: model),
      _ => ClaudeProvider(secrets: secrets, model: model),
    };
  }

  Future<void> _saveAndTest() async {
    final key = _keyController.text.trim();
    if (!_consent) {
      setState(() {
        _statusOk = false;
        _status = 'Please tick the consent box first.';
      });
      return;
    }
    if (key.isEmpty && !_hasStoredKey) {
      setState(() {
        _statusOk = false;
        _status = 'Enter a ${_meta.label} API key.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });

    final secrets = ref.read(secretStoreProvider);
    final keyName = keyNameFor(_provider)!;
    final prefs = await AppPrefs.open();
    if (key.isNotEmpty) {
      await secrets.writeKey(keyName, key);
      // Recorded here, while the key is in hand — the secret itself is never
      // read back out of the OS store just to show which one is saved.
      await prefs.setKeyHint(keyName, SecretStore.hintFor(key));
    }
    await prefs.setAiConsent(true);
    await prefs.setSelectedProvider(_provider.name);

    String? error;
    try {
      await _build(_provider, secrets).generate(
        const StoryPrompt(
          system: 'You are a friendly assistant.',
          user: 'Reply with a short, cheerful one-sentence hello.',
        ),
      );
    } catch (e) {
      error = e.toString();
    }

    await ref.read(aiConfigProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hasStoredKey = true;
      _consent = true;
      if (key.isNotEmpty) _keyHint = SecretStore.hintFor(key);
      _keyController.clear();
      _statusOk = error == null;
      _status = error == null
          ? 'Connected! ${_meta.label} will now write the stories.'
          : 'Could not connect: $error';
    });
  }

  Future<void> _clearKey() async {
    setState(() => _busy = true);
    final keyName = keyNameFor(_provider)!;
    await ref.read(secretStoreProvider).deleteKey(keyName);
    // The hint goes with the key it describes.
    await (await AppPrefs.open()).clearKeyHint(keyName);
    await ref.read(aiConfigProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hasStoredKey = false;
      _keyHint = '';
      _statusOk = false;
      _status = '${_meta.label} key removed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = ref.watch(aiConfigProvider);
    final activeLabel = active == ProviderId.fake
        ? 'Offline placeholder'
        : '${_providers.firstWhere((p) => p.id == active).label} (online)';

    return Scaffold(
      appBar: AppBar(title: const Text('Grown-up settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Parent mode first — it's the switch a grown-up reaches for most.
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.family_restroom),
                  title: const Text('Parent mode'),
                  subtitle: const Text(
                    'Show delete, rename & edit controls. Turn off (child mode) '
                    'so a child can\'t accidentally change or delete stories.',
                  ),
                  value: ref.watch(parentModeProvider),
                  onChanged: (v) =>
                      ref.read(parentModeProvider.notifier).set(v),
                ),
              ),
              const Divider(height: 40),

              SettingsSection(
                icon: Icons.auto_stories_outlined,
                title: 'Story AI provider & key',
                children: [
                  Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: $activeLabel',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Stories are created by sending the story prompt and '
                            'details derived from your child\'s profile (nickname, '
                            'age, interests) to the third-party AI provider you '
                            'choose below. Nothing is sent until you add a key and '
                            'consent. Your key is stored securely on this device '
                            'only. Avoid putting personal information into story '
                            'ideas.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OptionChips<ProviderId>(
                    label: 'Provider',
                    options: [for (final p in _providers) p.id],
                    selected: _provider,
                    labelOf: (id) =>
                        _providers.firstWhere((p) => p.id == id).label,
                    enabled: !_busy,
                    onSelected: _onProviderChanged,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _consent = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'I consent to sending prompts and profile-derived context to '
                      '${_meta.label} to generate stories.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: '${_meta.label} API key',
                      helperText: 'Get one at ${_meta.helpUrl}',
                      // Naming the saved key lets a parent tell which one is
                      // in there without the app reading the secret back.
                      hintText: !_hasStoredKey
                          ? _meta.hint
                          : _keyHint.isEmpty
                          ? 'A key is saved — type to replace it'
                          : '$_keyHint — type to replace it',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_hasStoredKey) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _keyHint.isEmpty
                              ? 'A ${_meta.label} key is saved on this device.'
                              : '${_meta.label} key $_keyHint is saved on this '
                                    'device.',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _saveAndTest,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_done_outlined),
                        label: const Text('Save & test'),
                      ),
                      const SizedBox(width: 12),
                      if (_hasStoredKey)
                        TextButton(
                          onPressed: _busy ? null : _clearKey,
                          child: const Text('Remove key'),
                        ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _status!,
                      style: TextStyle(
                        color: _statusOk
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),

              const Divider(height: 40),

              // Its own section: the block above is about *which key this
              // device holds*, and this one is about *what writes the story*.
              // Reading as one run of settings, the model looked like part of
              // adding a key, and a grown-up changing providers could not tell
              // which of the two the chips were driving.
              SettingsSection(
                icon: Icons.edit_note_outlined,
                title: 'Story model',
                children: [
                  Text(
                    'Which ${_meta.label} model writes the chapters.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  // Listed from the provider itself, so a retired id and a
                  // newly released one both show up without an app release.
                  ModelPicker(
                    directory: ref.read(
                      modelDirectoryProvider(vendorForProvider(_provider)),
                    ),
                    kind: ModelKind.text,
                    value: _textModel,
                    defaultId: _defaultTextModel(_provider),
                    label: '${_meta.label} model',
                    helper:
                        'Leave blank for the default. Bigger models write '
                        'better stories and cost more per chapter.',
                    onChanged: _onTextModelChanged,
                  ),
                ],
              ),

              const Divider(height: 40),
              const VoiceSection(),
              const Divider(height: 40),
              const AboutSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
