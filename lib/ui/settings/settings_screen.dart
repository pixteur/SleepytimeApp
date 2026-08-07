import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/ai_provider.dart';
import '../../adapters/ai/claude_provider.dart';
import '../../adapters/ai/gemini_provider.dart';
import '../../adapters/ai/openai_provider.dart';
import '../../adapters/prefs/app_prefs.dart';
import '../../adapters/secrets/secret_store.dart';
import '../../app_providers.dart';
import '../../domain/prompt_builder.dart';
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
    });
  }

  Future<bool> _keyPresent(ProviderId id) async {
    final name = keyNameFor(id);
    if (name == null) return false;
    return ref.read(secretStoreProvider).hasKey(name);
  }

  Future<void> _onProviderChanged(ProviderId id) async {
    await (await AppPrefs.open()).setSelectedProvider(id.name);
    final hasKey = await _keyPresent(id);
    if (!mounted) return;
    setState(() {
      _provider = id;
      _hasStoredKey = hasKey;
      _status = null;
      _keyController.clear();
    });
  }

  AiProvider _build(ProviderId id, SecretStore secrets) => switch (id) {
    ProviderId.openai => OpenAiProvider(secrets: secrets),
    ProviderId.gemini => GeminiProvider(secrets: secrets),
    _ => ClaudeProvider(secrets: secrets),
  };

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
    if (key.isNotEmpty) await secrets.writeKey(keyName, key);
    final prefs = await AppPrefs.open();
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
      _keyController.clear();
      _statusOk = error == null;
      _status = error == null
          ? 'Connected! ${_meta.label} will now write the stories.'
          : 'Could not connect: $error';
    });
  }

  Future<void> _clearKey() async {
    setState(() => _busy = true);
    await ref.read(secretStoreProvider).deleteKey(keyNameFor(_provider)!);
    await ref.read(aiConfigProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hasStoredKey = false;
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
                title: 'Story AI',
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
                      hintText: _hasStoredKey
                          ? 'A key is saved — type to replace it'
                          : _meta.hint,
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
                          'A ${_meta.label} key is saved on this device.',
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
              const VoiceSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
