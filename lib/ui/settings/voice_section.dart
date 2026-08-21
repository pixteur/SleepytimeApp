import 'package:flutter/material.dart';

import '../../adapters/ai/model_catalog.dart';
import 'model_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/prefs/app_prefs.dart';
import '../../adapters/secrets/secret_store.dart';
import '../../adapters/tts/elevenlabs_tts_synthesizer.dart';
import '../../adapters/tts/gemini_tts_synthesizer.dart';
import '../../adapters/tts/openai_tts_synthesizer.dart';
import '../../app_providers.dart';
import 'settings_section.dart';

/// Voice setup: the narration engine (free device TTS, or a natural cloud voice
/// from OpenAI / ElevenLabs / Gemini), a voice, and a preview. Cloud engines
/// reuse the story keys (ElevenLabs has its own) and require the same
/// third-party-AI consent. See `docs/voice-tts.md`.
class VoiceSection extends ConsumerStatefulWidget {
  const VoiceSection({super.key});

  @override
  ConsumerState<VoiceSection> createState() => _VoiceSectionState();
}

const _engineLabels = {
  VoiceEngine.device: 'Device (free)',
  VoiceEngine.openai: 'OpenAI',
  VoiceEngine.elevenlabs: 'ElevenLabs',
  VoiceEngine.gemini: 'Gemini',
};

class _VoiceSectionState extends ConsumerState<VoiceSection> {
  final _elevenKey = TextEditingController();

  /// Overrides the model this engine synthesizes with. Blank uses the
  /// adapter's own default, which is what almost everyone should leave it on.
  final _model = TextEditingController();

  /// Masked reminder of the saved ElevenLabs key, e.g. `sk_1••••7f2c`. Empty
  /// when none is saved, or when it was saved before hints existed.
  String _elevenHint = '';
  VoiceEngine _engine = VoiceEngine.device;
  String _voice = '';
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
    _elevenKey.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.open();
    final engine = voiceEngineFromName(prefs.voiceEngine);
    if (!mounted) return;
    setState(() {
      _engine = engine;
      _voice = prefs.voiceName(engine.name) ?? _defaultVoice(engine);
      _model.text = prefs.voiceModel(engine.name) ?? '';
      _elevenHint = prefs.keyHint(ElevenLabsTtsSynthesizer.keyName);
    });
  }

  /// The catalogue behind this engine's model list. Null for the device voice,
  /// which has no API to ask.
  ModelDirectory? _directoryFor(VoiceEngine e) {
    final vendor = vendorForVoice(e);
    return vendor == null ? null : ref.read(modelDirectoryProvider(vendor));
  }

  /// What this engine uses when the model field is left blank — shown as the
  /// field's hint so the default is visible without having to type it.
  String _defaultModel(VoiceEngine e) => switch (e) {
    VoiceEngine.openai => OpenAiTtsSynthesizer.defaultModel,
    VoiceEngine.elevenlabs => ElevenLabsTtsSynthesizer.defaultModel,
    VoiceEngine.gemini => GeminiTtsSynthesizer.defaultModel,
    VoiceEngine.device => '',
  };

  String _defaultVoice(VoiceEngine e) => switch (e) {
    VoiceEngine.openai => 'nova',
    VoiceEngine.elevenlabs => '21m00Tcm4TlvDq8ikWAM',
    VoiceEngine.gemini => 'Kore',
    VoiceEngine.device => '',
  };

  List<DropdownMenuItem<String>> _voiceItems(VoiceEngine e) => switch (e) {
    VoiceEngine.openai => [
      for (final v in OpenAiTtsSynthesizer.voices)
        DropdownMenuItem(value: v, child: Text(v)),
    ],
    VoiceEngine.gemini => [
      for (final v in GeminiTtsSynthesizer.voices)
        DropdownMenuItem(value: v, child: Text(v)),
    ],
    VoiceEngine.elevenlabs => [
      for (final entry in ElevenLabsTtsSynthesizer.presets.entries)
        DropdownMenuItem(value: entry.value, child: Text(entry.key)),
    ],
    VoiceEngine.device => const [],
  };

  Future<void> _onEngineChanged(VoiceEngine e) async {
    final prefs = await AppPrefs.open();
    if (!mounted) return;
    setState(() {
      _engine = e;
      _voice = prefs.voiceName(e.name) ?? _defaultVoice(e);
      _model.text = prefs.voiceModel(e.name) ?? '';
      _elevenHint = prefs.keyHint(ElevenLabsTtsSynthesizer.keyName);
      _status = null;
    });
  }

  Future<void> _save({bool thenTest = false}) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final prefs = await AppPrefs.open();
    await prefs.setVoiceEngine(_engine.name);
    if (_engine != VoiceEngine.device) {
      await prefs.setVoiceName(_engine.name, _voice);
      // Blank means "whatever the adapter defaults to", so a cleared field
      // returns to the built-in rather than sending an empty model id.
      await prefs.setVoiceModel(_engine.name, _model.text.trim());
    }
    if (_engine == VoiceEngine.elevenlabs &&
        _elevenKey.text.trim().isNotEmpty) {
      final key = _elevenKey.text.trim();
      await ref
          .read(secretStoreProvider)
          .writeKey(ElevenLabsTtsSynthesizer.keyName, key);
      // Recorded while the key is in hand — the secret is never read back out
      // of the OS store just to show which one is saved.
      final hint = SecretStore.hintFor(key);
      await prefs.setKeyHint(ElevenLabsTtsSynthesizer.keyName, hint);
      if (mounted) setState(() => _elevenHint = hint);
    }
    await ref.read(voiceConfigProvider.notifier).refresh();

    final active = ref.read(voiceConfigProvider).engine;
    String? error;
    if (thenTest) {
      try {
        await ref
            .read(ttsProvider)
            .speak('Hello! This is how your bedtime stories will sound.');
      } catch (e) {
        error = e.toString();
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _elevenKey.clear();
      _statusOk = error == null;
      if (error != null) {
        _status = 'Voice error: $error';
      } else if (active != _engine && _engine != VoiceEngine.device) {
        _status =
            'Saved, but falling back to Device — add the ${_engineLabels[_engine]} '
            'key and give consent in the Story AI section above first.';
        _statusOk = false;
      } else {
        _status = 'Saved. Active voice: ${_engineLabels[active]}.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = ref.watch(voiceConfigProvider).engine;
    final isCloud = _engine != VoiceEngine.device;

    return SettingsSection(
      icon: Icons.record_voice_over_outlined,
      title: 'Voice',
      children: [
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: ListTile(
            title: Text('Active voice: ${_engineLabels[active]}'),
            subtitle: const Text(
              'Device TTS is free & offline but robotic. Cloud voices are '
              'natural — they send the story text to the chosen provider '
              '(same consent as story generation).',
            ),
          ),
        ),
        const SizedBox(height: 16),
        OptionChips<VoiceEngine>(
          label: 'Engine',
          options: VoiceEngine.values,
          selected: _engine,
          labelOf: (e) => _engineLabels[e]!,
          enabled: !_busy,
          onSelected: _onEngineChanged,
        ),
        if (isCloud) ...[
          const SizedBox(height: 16),
          Text('Voice', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _voice,
            items: _voiceItems(_engine),
            onChanged: _busy
                ? null
                : (v) => setState(() => _voice = v ?? _voice),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          // Asks the provider what its key can reach, rather than making a
          // grown-up know a model id. Falls back to typing one when the list
          // can't be fetched — which is how this worked before.
          ModelPicker(
            directory: _directoryFor(_engine),
            kind: ModelKind.audio,
            value: _model.text,
            defaultId: _defaultModel(_engine),
            label: 'Voice model',
            helper:
                'Leave blank for the default. Worth changing if a model is '
                'retired, or to move off a preview model with tighter limits.',
            onChanged: (v) => setState(() => _model.text = v),
          ),
          const SizedBox(height: 12),
          if (_engine == VoiceEngine.elevenlabs)
            TextField(
              controller: _elevenKey,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'ElevenLabs API key',
                // Naming the saved key lets a parent tell which one is in
                // there without the app reading the secret back.
                hintText: _elevenHint.isEmpty
                    ? null
                    : '$_elevenHint — type to replace it',
                helperText: 'Get one at elevenlabs.io',
                border: const OutlineInputBorder(),
              ),
            )
          else
            Text(
              'Uses your ${_engineLabels[_engine]} key from the Story AI '
              'section above.',
              style: theme.textTheme.bodySmall,
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(thenTest: true),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: const Text('Save & test voice'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _busy ? null : () => _save(),
              child: const Text('Save'),
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
    );
  }
}
