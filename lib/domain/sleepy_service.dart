import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../adapters/export/sleepy_codec.dart';
import '../adapters/storage/storage_repo.dart';
import '../adapters/tts/audio_cache.dart';
import 'models/beat.dart';
import 'models/series.dart';
import 'models/story_character.dart';
import 'models/world.dart';

/// Exports/imports a story as a `.sleepy` file (text + audio + metadata). Audio
/// is pulled from the on-disk cache on export and written back on import (keyed
/// by the voice it was made with), so an imported story replays offline with no
/// API calls when the same voice is used. See `docs/data-model.md`.
class SleepyService {
  SleepyService(this._repo, this._cache, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final AudioCache _cache;
  final Uuid _uuid;

  static const int _formatVersion = 1;

  String _key(String voiceSig, String lang, String text) =>
      audioCacheKey('$voiceSig|$lang|$text');

  // ── Export ──────────────────────────────────────────────────────
  Future<Uint8List> exportBytes(
    Series series, {
    required String language,
    required String voiceSignature,
  }) async {
    final beats = await _repo.loadBeats(series.id);
    final world = series.worldId == null
        ? null
        : await _repo.loadWorldById(series.worldId!);
    final characters = series.worldId == null
        ? const <StoryCharacter>[]
        : await _repo.loadCharacters(series.worldId!);

    final audio = <String, Uint8List>{};
    final chapters = <Map<String, dynamic>>[];
    for (final b in beats) {
      String? audioName;
      final bytes = await _cache.get(_key(voiceSignature, language, b.text));
      if (bytes != null && bytes.isNotEmpty) {
        audioName = 'audio/ch${b.seq}.bin';
        audio[audioName] = bytes;
      }
      chapters.add({
        'seq': b.seq,
        'text': b.text,
        'summary': b.summary,
        'rating': b.rating.name,
        'setting': b.setting,
        'intent': b.intent.name,
        'isFinal': b.isFinal,
        'audio': audioName,
      });
    }

    final manifest = <String, dynamic>{
      'format': 'sleepy',
      'version': _formatVersion,
      'language': language,
      'voiceSignature': voiceSignature,
      'world': world == null
          ? null
          : {
              'name': world.name,
              'premise': world.premise,
              'theme': world.theme.name,
            },
      'characters': [
        for (final c in characters)
          {'name': c.name, 'description': c.description},
      ],
      'story': {
        'title': series.title,
        'theme': series.theme.name,
        'heroMode': series.heroMode.name,
        'heroName': series.heroName,
        'seedSummary': series.seedSummary,
        'storyBible': series.storyBible,
      },
      'chapters': chapters,
    };
    return encodeSleepy(SleepyArchive(manifest: manifest, audio: audio));
  }

  /// Write a `.sleepy` into the app's shareable exports folder; returns its path.
  Future<String> exportToFile(
    Series series, {
    required String language,
    required String voiceSignature,
  }) async {
    final bytes = await exportBytes(
      series,
      language: language,
      voiceSignature: voiceSignature,
    );
    final dir = await exportsDir();
    final file = File(p.join(dir.path, '${_safeName(series.title)}.sleepy'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Directory> exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'Sleepytime', 'stories'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// The `.sleepy` files currently sitting in the exports folder (importable).
  Future<List<File>> listSleepyFiles() async {
    final dir = await exportsDir();
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.sleepy'))
        .toList();
  }

  // ── Import ──────────────────────────────────────────────────────
  Future<Series> importFile(String path, String childId) async {
    final bytes = await File(path).readAsBytes();
    return importBytes(bytes, childId);
  }

  Future<Series> importBytes(Uint8List bytes, String childId) async {
    final data = decodeSleepy(bytes);
    final m = data.manifest;
    final lang = m['language'] as String? ?? 'en';
    final voiceSig = m['voiceSignature'] as String? ?? 'device';

    String? worldId;
    final wm = m['world'] as Map<String, dynamic>?;
    if (wm != null) {
      final world = World(
        id: _uuid.v4(),
        childId: childId,
        name: wm['name'] as String? ?? 'Imported world',
        premise: wm['premise'] as String? ?? '',
        theme: _enum(StoryTheme.values, wm['theme'], StoryTheme.cozy),
      );
      await _repo.saveWorld(world);
      worldId = world.id;
      for (final c in (m['characters'] as List? ?? const [])) {
        final cm = c as Map<String, dynamic>;
        await _repo.saveCharacter(
          StoryCharacter(
            id: _uuid.v4(),
            worldId: worldId,
            name: cm['name'] as String? ?? '',
            description: cm['description'] as String? ?? '',
          ),
        );
      }
    }

    final sm = m['story'] as Map<String, dynamic>;
    final series = Series(
      id: _uuid.v4(),
      childId: childId,
      worldId: worldId,
      title: sm['title'] as String? ?? 'Imported story',
      theme: _enum(StoryTheme.values, sm['theme'], StoryTheme.cozy),
      heroMode: _enum(HeroMode.values, sm['heroMode'], HeroMode.surprise),
      heroName: sm['heroName'] as String?,
      seedSummary: sm['seedSummary'] as String? ?? '',
      storyBible: sm['storyBible'] as String? ?? '',
    );
    await _repo.saveSeries(series);

    for (final c in (m['chapters'] as List? ?? const [])) {
      final cm = c as Map<String, dynamic>;
      final text = cm['text'] as String? ?? '';
      await _repo.saveBeat(
        Beat(
          id: _uuid.v4(),
          seriesId: series.id,
          childId: childId,
          seq: cm['seq'] as int? ?? 0,
          intent: _enum(StoryIntent.values, cm['intent'], StoryIntent.dice),
          text: text,
          summary: cm['summary'] as String? ?? '',
          rating: _enum(AgeRating.values, cm['rating'], AgeRating.tiny),
          setting: cm['setting'] as String? ?? '',
          language: lang,
          isFinal: cm['isFinal'] as bool? ?? false,
        ),
      );
      // Restore the chapter's audio into the cache under the voice it was made
      // with, so it plays instantly (no API call) for a same-voice listener.
      final audioName = cm['audio'] as String?;
      final audioBytes = audioName == null ? null : data.audio[audioName];
      if (audioBytes != null) {
        await _cache.put(_key(voiceSig, lang, text), audioBytes);
      }
    }
    return series;
  }

  T _enum<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  String _safeName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return cleaned.isEmpty ? 'story' : cleaned;
  }
}
