import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/formatters.dart';
import '../widgets/feedback.dart';
import 'field_input.dart';

/// Create / edit / view dialog for any master entity.
Future<void> showMasterForm(
  BuildContext context, {
  required MasterEntityConfig config,
  MasterRecord? record,
  bool readOnly = false,
}) => showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      MasterFormDialog(config: config, record: record, readOnly: readOnly),
);

class MasterFormDialog extends ConsumerStatefulWidget {
  const MasterFormDialog({
    super.key,
    required this.config,
    this.record,
    this.readOnly = false,
  });

  final MasterEntityConfig config;
  final MasterRecord? record;
  final bool readOnly;

  @override
  ConsumerState<MasterFormDialog> createState() => _MasterFormDialogState();
}

class _MasterFormDialogState extends ConsumerState<MasterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, dynamic> _data;
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = {
      for (final f in widget.config.fields)
        if (f.defaultValue != null) f.key: f.defaultValue,
      ...?widget.record?.data,
    };
    for (final f in widget.config.fields.where(isTextField)) {
      final v = _data[f.key];
      _controllers[f.key] = TextEditingController(text: v == null ? '' : '$v');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    final out = <String, dynamic>{};
    for (final f in widget.config.fields) {
      if (f.derived) continue;
      Object? v = isTextField(f)
          ? parseFieldText(f, _controllers[f.key]!.text)
          : _data[f.key];
      if (!f.isVisible(_data)) v = null;
      out[f.key] = v;
      if (f.type == FieldType.reference) {
        out[f.refNameKey] = v == null ? null : _data[f.refNameKey];
        for (final k in f.refCopy.keys) {
          out[k] = v == null ? null : _data[k];
        }
      }
    }
    return out;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(masterRepositoryProvider)
          .save(widget.config, id: widget.record?.id, data: _collect());
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(
        context,
        '${widget.config.singular} ${widget.record == null ? 'created' : 'updated'}.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final isNew = widget.record == null;
    final title = widget.readOnly
        ? c.singular
        : isNew
        ? 'Add ${c.singular.toLowerCase()}'
        : 'Edit ${c.singular.toLowerCase()}';
    final width = MediaQuery.sizeOf(context).width;
    final twoCol = width > 720;
    // No LayoutBuilder here: scrollable dialogs measure intrinsic sizes.
    final contentWidth = twoCol ? 640.0 : width - 96;
    final half = twoCol ? (contentWidth - 16) / 2 : contentWidth;

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: contentWidth,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Builder(
            builder: (context) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    InfoBanner(_error!, kind: BannerKind.danger),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final f in c.fields)
                        if (f.isVisible(_data))
                          SizedBox(
                            width:
                                f.type == FieldType.multiline ||
                                    f.type == FieldType.boolean
                                ? contentWidth
                                : half,
                            child: FieldInput(
                              field: f,
                              data: _data,
                              controller: _controllers[f.key],
                              readOnly: widget.readOnly,
                              onChanged: (changes) =>
                                  setState(() => _data.addAll(changes)),
                            ),
                          ),
                    ],
                  ),
                  if (!isNew) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Status: ${widget.record!.status} · Created '
                      '${formatDateTime(widget.record!.createdAt)} · Updated '
                      '${formatDateTime(widget.record!.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(widget.readOnly ? 'Close' : 'Cancel'),
        ),
        if (!widget.readOnly)
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(isNew ? 'Create' : 'Save changes'),
          ),
      ],
    );
  }
}
