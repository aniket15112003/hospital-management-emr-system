import 'package:flutter/material.dart';

import '../../core/auth/permissions.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/master_data/master_data_panel.dart';
import '../../shared/widgets/feedback.dart';
import 'billing_masters_config.dart';

class BillingMastersPage extends StatefulWidget {
  const BillingMastersPage({super.key});

  @override
  State<BillingMastersPage> createState() => _BillingMastersPageState();
}

class _BillingMastersPageState extends State<BillingMastersPage> {
  int _tab = 0;

  static final _configs = [
    chargeHeadsConfig,
    paymentMethodsConfig,
    discountRulesConfig,
  ];

  @override
  Widget build(BuildContext context) {
    return PageBody(
      title: 'Billing Masters',
      subtitle: 'Charge heads, payment methods and discount controls.',
      module: Modules.billingMasters,
      children: [
        const InfoBanner(
          'Configuration only. Invoicing, payment collection and receipts '
          'belong to the future Billing module.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<int>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
            ),
            segments: [
              for (var i = 0; i < _configs.length; i++)
                ButtonSegment(value: i, label: Text(_configs[i].title)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 16),
        MasterDataPanel(key: ValueKey(_tab), config: _configs[_tab]),
      ],
    );
  }
}
