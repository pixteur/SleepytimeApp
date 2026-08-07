import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/prefs/app_prefs.dart';
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
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.open();
    final engine = voiceEngineFromName(prefs.voiceEngine);
    if (!mounted) return;
    setState(() {
      _engine = engine;
      _voice = prefs.voiceName(engine.name) ?? _defaultVoice(engine);
    });
  }

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
    }
    if (_engine == VoiceEngine.elevenlabs &&
        _elevenKey.text.trim().isNotEmpty) {
      await ref
          .read(secretStoreProvider)
          .writeKey(ElevenLabsTtsSynthesizer.keyName, _elevenKey.text.trim());
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
          if (_engine == VoiceEngine.elevenlabs)
            TextField(
              controller: _elevenKey,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'ElevenLabs API key',
                helperText: 'Get one at elevenlabs.io',
                border: OutlineInputBorder(),
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
