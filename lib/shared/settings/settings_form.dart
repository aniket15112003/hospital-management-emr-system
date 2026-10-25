import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/data/settings_repository.dart';
import '../../core/utils/formatters.dart';
import '../master_data/field_input.dart';
import '../widgets/app_card.dart';
import '../widgets/feedback.dart';

final settingsDocProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, SettingsDoc>(
      (ref, doc) => ref.watch(settingsRepositoryProvider).watch(doc),
    );

/// Card that loads, edits and saves one settings document using [FieldDef]s.
class SettingsFormCard extends ConsumerStatefulWidget {
  const SettingsFormCard({
    super.key,
    required this.doc,
    required this.title,
    required this.fields,
    this.subtitle,
    this.defaults = const {},
    this.extraValidator,
    this.onDataChanged,
  });

  final SettingsDoc doc;
  final String title;
  final String? subtitle;
  final List<FieldDef> fields;

  /// Values used when the document does not exist yet.
  final Map<String, dynamic> defaults;

  /// Cross-field validation; returns an error message or null.
  final String? Function(Map<String, dynamic> data)? extraValidator;

  /// Notified on every edit (e.g. to render a live preview).
  final ValueChanged<Map<String, dynamic>>? onDataChanged;

  @override
  ConsumerState<SettingsFormCard> createState() => _SettingsFormCardState();
}

class _SettingsFormCardState extends ConsumerState<SettingsFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  Map<String, dynamic>? _data;
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    // Adopt server data on first load, and on later updates unless the user
    // has unsaved edits.
    ref.listenManual(settingsDocProvider(widget.doc), (_, next) {
      if (!next.hasValue) return;
      final stored = next.value;
      if (_data != null) {
        if (_dirty || _saving) return;
        if (stored?['updatedAt'] == _data!['updatedAt']) return;
      }
      if (_initializing) {
        _load(stored);
      } else if (mounted) {
        setState(() => _load(stored));
      }
    }, fireImmediately: true);
    _initializing = false;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Map<String, dynamic>? stored) {
    _data = {...widget.defaults, ...?stored};
    for (final f in widget.fields.where(isTextField)) {
      final v = _data![f.key];
      (_controllers[f.key] ??= TextEditingController()).text = v == null
          ? ''
          : '$v';
    }
    _dirty = false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mounted ? widget.onDataChanged?.call(_collect()) : null,
    );
  }

  Map<String, dynamic> _collect() => {
    for (final f in widget.fields)
      f.key: isTextField(f)
          ? parseFieldText(f, _controllers[f.key]!.text)
          : _data![f.key],
  };

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
    widget.onDataChanged?.call(_collect());
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final data = _collect();
    final extra = widget.extraValidator?.call(data);
    if (extra != null) {
      setState(() => _error = extra);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).save(widget.doc, data);
      if (!mounted) return;
      setState(() => _dirty = false);
      showSuccess(context, '${widget.title} saved.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsDocProvider(widget.doc));
    final canManage = ref.watch(
      canProvider((widget.doc.module, PermAction.manage)),
    );

    return AppCard(
      title: widget.title,
      subtitle:
          widget.subtitle ??
          (async.value?['updatedAt'] != null
              ? 'Last updated ${formatDateTime(async.value!['updatedAt'])}'
              : async.hasValue
              ? 'Not configured yet'
              : null),
      actions: [
        if (canManage)
          FilledButton(
            onPressed: _saving || !_dirty ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
      ],
      child: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(settingsDocProvider(widget.doc)),
        ),
        data: (_) => _data == null
            ? const LoadingView()
            : Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: _changed,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final half = box.maxWidth > 640
                        ? (box.maxWidth - 16) / 2
                        : box.maxWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!canManage) ...[
                          const InfoBanner(
                            'Read-only: you do not have permission to change these settings.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_error != null) ...[
                          InfoBanner(_error!, kind: BannerKind.danger),
                          const SizedBox(height: 16),
                        ],
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final f in widget.fields)
                              SizedBox(
                                width:
                                    f.type == FieldType.multiline ||
                                        f.type == FieldType.boolean
                                    ? box.maxWidth
                                    : half,
                                child: FieldInput(
                                  field: f,
                                  data: _data!,
                                  controller: _controllers[f.key],
                                  readOnly: !canManage,
                                  onChanged: (c) {
                                    setState(() => _data!.addAll(c));
                                    _changed();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}
