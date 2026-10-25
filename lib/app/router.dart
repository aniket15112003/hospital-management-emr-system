import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session.dart';
import '../core/config/app_config.dart';
import '../core/data/providers.dart';
import '../features/admin_dashboard/dashboard_page.dart';
import '../features/audit_logs/audit_logs_page.dart';
import '../features/auth/auth_pages.dart';
import '../features/backup_recovery/backup_page.dart';
import '../features/billing_masters/billing_masters_page.dart';
import '../features/departments/departments_config.dart';
import '../features/doctors/doctors_config.dart';
import '../features/hospital_settings/hospital_profile_page.dart';
import '../features/hospital_settings/numbering_page.dart';
import '../features/hospital_settings/print_settings_page.dart';
import '../features/hospital_settings/system_settings_page.dart';
import '../features/lab_tests/lab_tests_config.dart';
import '../features/medicines/medicines_config.dart';
import '../features/opd_charges/opd_charges_config.dart';
import '../features/prescription_templates/prescription_templates_config.dart';
import '../features/reports/reports_page.dart';
import '../features/roles_permissions/roles_page.dart';
import '../features/users/users_page.dart';
import '../features/wards_rooms_beds/wards_rooms_beds_config.dart';
import '../shared/layout/admin_shell.dart';
import '../shared/master_data/master_data_panel.dart';

/// Page builder for every Admin Panel route (all rendered inside the shell).
final Map<String, Widget Function()> adminPages = {
  '/': () => const DashboardPage(),
  '/departments': () => const MasterDataPage(config: departmentsConfig),
  '/doctors': () => const MasterDataPage(config: doctorsConfig),
  '/users': () => const UsersPage(),
  '/opd-charges': () => const MasterDataPage(config: opdChargesConfig),
  '/lab-tests': () => const MasterDataPage(config: labTestsConfig),
  '/medicines': () => const MasterDataPage(config: medicinesConfig),
  '/wards': () => const MasterDataPage(config: wardsConfig),
  '/rooms': () => const MasterDataPage(config: roomsConfig),
  '/beds': () => const MasterDataPage(config: bedsConfig),
  '/billing-masters': () => const BillingMastersPage(),
  '/prescription-templates': () =>
      MasterDataPage(config: prescriptionTemplatesConfig),
  '/roles': () => const RolesPage(),
  '/numbering': () => const NumberingPage(),
  '/hospital-profile': () => const HospitalProfilePage(),
  '/print-settings': () => const PrintSettingsPage(),
  '/reports': () => const ReportsPage(),
  '/audit-logs': () => const AuditLogsPage(),
  '/backup': () => const BackupPage(),
  '/system-settings': () => const SystemSettingsPage(),
};

const _publicRoutes = {'/login', '/setup', '/loading', '/inactive'};

/// Pure redirect policy, exposed for testing.
String? resolveRedirect({
  required BackendMode mode,
  required AsyncValue<AppSession?> session,
  required Uri uri,
}) {
  final path = uri.path;
  final from = uri.queryParameters['from'];
  String target() => (from != null && from.startsWith('/')) ? from : '/';

  if (mode == BackendMode.unconfigured) {
    return path == '/setup' ? null : '/setup';
  }
  if (session.isLoading && !session.hasValue) {
    return path == '/loading'
        ? null
        : Uri(
            path: '/loading',
            queryParameters: {'from': uri.toString()},
          ).toString();
  }
  final s = session.value;
  if (s == null) {
    return path == '/login'
        ? null
        : _publicRoutes.contains(path)
        ? '/login'
        : Uri(
            path: '/login',
            queryParameters: {'from': uri.toString()},
          ).toString();
  }
  if (!s.isActive) return path == '/inactive' ? null : '/inactive';
  if (_publicRoutes.contains(path)) return target();
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(backendModeProvider, (_, _) => refresh.value++);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      mode: ref.read(backendModeProvider),
      session: ref.read(sessionProvider),
      uri: state.uri,
    ),
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Page not found: ${state.uri.path}'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go to dashboard'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupRequiredPage()),
      GoRoute(path: '/loading', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/inactive',
        builder: (_, _) => const AccountInactivePage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          for (final e in adminPages.entries)
            GoRoute(
              path: e.key,
              pageBuilder: (_, state) =>
                  NoTransitionPage(key: state.pageKey, child: e.value()),
            ),
        ],
      ),
    ],
  );
});
