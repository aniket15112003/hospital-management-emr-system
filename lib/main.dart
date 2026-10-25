import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await resolveBackendMode();
  runApp(
    ProviderScope(
      overrides: [
        initialBackendProvider.overrideWithValue(
          BackendState(backend.mode, error: backend.error),
        ),
      ],
      child: const HmsAdminApp(),
    ),
  );
}
