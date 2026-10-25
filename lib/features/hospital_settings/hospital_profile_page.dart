import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/settings/settings_form.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import 'settings_docs.dart';

const hospitalProfileFields = [
  FieldDef('name', 'Hospital name', required: true),
  FieldDef('registrationNumber', 'Registration / licence no.', maxLength: 60),
  FieldDef('addressLine1', 'Address line 1', required: true, maxLength: 200),
  FieldDef('addressLine2', 'Address line 2', maxLength: 200),
  FieldDef('city', 'City', required: true, maxLength: 60),
  FieldDef('state', 'State', required: true, maxLength: 60),
  FieldDef('postalCode', 'Postal code', maxLength: 12),
  FieldDef('country', 'Country', maxLength: 60, defaultValue: 'India'),
  FieldDef('phone', 'Phone', type: FieldType.phone, required: true),
  FieldDef('alternatePhone', 'Alternate phone', type: FieldType.phone),
  FieldDef('email', 'Email', type: FieldType.email, required: true),
  FieldDef('website', 'Website', maxLength: 120),
  FieldDef('gstin', 'GSTIN / tax ID', maxLength: 20, uppercase: true),
  FieldDef('emergencyPhone', 'Emergency contact', type: FieldType.phone),
];

class HospitalProfilePage extends StatelessWidget {
  const HospitalProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
    title: 'Hospital Profile',
    subtitle: 'Name, address and contact details used across documents.',
    module: Modules.hospitalProfile,
    children: [
      _LogoCard(),
      SizedBox(height: 20),
      SettingsFormCard(
        doc: hospitalProfileDoc,
        title: 'Hospital details',
        fields: hospitalProfileFields,
        defaults: {'country': 'India'},
      ),
    ],
  );
}

class _LogoCard extends ConsumerStatefulWidget {
  const _LogoCard();

  @override
  ConsumerState<_LogoCard> createState() => _LogoCardState();
}

class _LogoCardState extends ConsumerState<_LogoCard> {
  bool _uploading = false;

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final repo = ref.read(settingsRepositoryProvider);
      final url = await repo.uploadLogo(bytes, ext);
      await repo.save(hospitalProfileDoc, {'logoUrl': url});
      if (mounted) showSuccess(context, 'Logo uploaded.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove logo?',
      message: 'Documents will print without a logo.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(settingsRepositoryProvider).save(hospitalProfileDoc, {
        'logoUrl': null,
      });
      if (mounted) showSuccess(context, 'Logo removed.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(settingsRepositoryProvider).storageAvailable;
    final canManage = ref.watch(
      canProvider((Modules.hospitalProfile, PermAction.manage)),
    );
    final url =
        ref.watch(settingsDocProvider(hospitalProfileDoc)).value?['logoUrl']
            as String?;

    return AppCard(
      title: 'Logo',
      subtitle: 'PNG, JPG or WEBP up to 2 MB',
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null
                ? const Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: AppColors.muted,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    semanticLabel: 'Hospital logo',
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
          ),
          if (!storage)
            const SizedBox(
              width: 420,
              child: InfoBanner(
                'Logo upload needs Firebase Storage (a storage bucket in the '
                'Firebase configuration and deployed storage.rules). It is '
                'not available in the current setup.',
                kind: BannerKind.warning,
              ),
            )
          else if (canManage)
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _uploading ? null : _pick,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload, size: 18),
                  label: Text(url == null ? 'Upload logo' : 'Replace logo'),
                ),
                if (url != null)
                  OutlinedButton(
                    onPressed: _uploading ? null : _remove,
                    child: const Text('Remove'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
