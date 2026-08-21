import 'package:flutter/material.dart';

import '../../adapters/ai/model_catalog.dart';
import '../../adapters/ai/provider_exceptions.dart';

/// Pick a model from the ones the provider says the key can reach.
///
/// Three states, because a settings screen that only works online is a settings
/// screen that strands you:
///
///  * **listed** — a dropdown of real ids, each with what we can honestly say
///    about it;
///  * **not asked yet / offline / refused** — the manual field, which is what
///    this used to be and still has to work;
///  * **typed something the list doesn't have** — kept and shown, because a
///    brand-new model id is exactly the case where the list is behind.
///
/// The empty value always means "the app's default", never a blank model id on
/// the wire. See `docs/ai-providers.md`.
class ModelPicker extends StatefulWidget {
  const ModelPicker({
    super.key,
    required this.directory,
    required this.kind,
    required this.value,
    required this.defaultId,
    required this.onChanged,
    required this.label,
    this.helper = '',
  });

  /// Where the list comes from. Null when the engine has no catalogue (the
  /// offline device voice), which hides the picker entirely.
  final ModelDirectory? directory;

  /// Show only models for this job.
  final ModelKind kind;

  /// The chosen id, or blank for [defaultId].
  final String value;

  /// What the adapter falls back to, shown as the empty option's subtitle.
  final String defaultId;

  final ValueChanged<String> onChanged;
  final String label;
  final String helper;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  late final TextEditingController _manual = TextEditingController(
    text: widget.value,
  );
  List<AiModel>? _models;
  bool _loading = false;
  String _error = '';

  @override
  void didUpdateWidget(ModelPicker old) {
    super.didUpdateWidget(old);
    // A different engine/provider means a different catalogue; drop the old one
    // rather than offering Gemini's models for an OpenAI key.
    if (old.directory != widget.directory) {
      setState(() {
        _models = null;
        _error = '';
      });
    }
    if (old.value != widget.value && widget.value != _manual.text) {
      _manual.text = widget.value;
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final directory = widget.directory;
    if (directory == null || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final all = await directory.list();
      final usable = all.where((m) => m.kind == widget.kind).toList();
      if (!mounted) return;
      setState(() {
        _models = usable;
        _error = usable.isEmpty
            ? 'That key reached the provider, but it offers no '
                  '${widget.kind == ModelKind.audio ? "voice" : "story"} models.'
            : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _models = null;
        _error = _explain(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Why the list couldn't be fetched, in words a grown-up can act on. Not
  /// fatal in any case — the manual field is right there.
  static String _explain(Object error) {
    if (error is ProviderNotConfigured) {
      return 'Add the API key first, then this can list its models.';
    }
    if (error is ProviderRequestException) {
      // Seen with a real ElevenLabs key: listing models is its own permission,
      // and a key scoped to speech alone gets a 401 here while working fine
      // for narration. Saying "your key is wrong" would send someone off
      // replacing a key that isn't broken.
      final message = error.message.toLowerCase();
      if (message.contains('permission') || message.contains('models_read')) {
        return 'This key works, but is not allowed to list models. Grant it '
            'read access to models, or type the id below.';
      }
    }
    return 'Could not list models: ${friendlyProviderError(error)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.directory == null) return const SizedBox.shrink();
    final models = _models;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.labelLarge),
            ),
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(models == null ? 'Show models' : 'Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (models != null && models.isNotEmpty)
          _dropdown(models)
        else
          TextField(
            controller: _manual,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              hintText: widget.defaultId,
              helperMaxLines: 3,
              helperText: widget.helper.isEmpty
                  ? 'Leave blank for the default.'
                  : widget.helper,
            ),
            onChanged: (v) => widget.onChanged(v.trim()),
          ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dropdown(List<AiModel> models) {
    final theme = Theme.of(context);
    // A value the list doesn't carry — a hand-typed or newly-released id — has
    // to stay selectable, or opening settings would silently change the model.
    final ids = models.map((m) => m.id).toSet();
    final custom = widget.value.isNotEmpty && !ids.contains(widget.value);

    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: _row('App default', widget.defaultId, theme),
        ),
        if (custom)
          DropdownMenuItem(
            value: widget.value,
            child: _row(widget.value, 'Set by hand', theme),
          ),
        for (final m in models)
          DropdownMenuItem(
            value: m.id,
            child: _row(
              m.label,
              [
                if (m.label != m.id) m.id,
                if (m.preview) 'Preview — tighter daily limits',
                if (m.note.isNotEmpty) m.note,
              ].join(' · '),
              theme,
            ),
          ),
      ],
      onChanged: (v) => widget.onChanged(v ?? ''),
    );
  }

  Widget _row(String title, String subtitle, ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, overflow: TextOverflow.ellipsis),
      if (subtitle.isNotEmpty)
        Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ],
  );
}
