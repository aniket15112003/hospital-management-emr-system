import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hes/app/app.dart';
import 'package:hes/app/nav_items.dart';
import 'package:hes/app/router.dart';
import 'package:hes/core/auth/permissions.dart';
import 'package:hes/core/auth/session.dart';
import 'package:hes/core/config/app_config.dart';
import 'package:hes/core/data/providers.dart';

Future<ProviderContainer> _pumpDemoApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      initialBackendProvider.overrideWithValue(
        const BackendState(BackendMode.demo),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HmsAdminApp()),
  );
  await _settle(tester);
  return container;
}

/// Pumps a few frames; avoids pumpAndSettle hanging on progress indicators.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  test('every nav item has a page and vice versa', () {
    expect(navItems.map((i) => i.path).toSet(), adminPages.keys.toSet());
  });

  testWidgets('every Admin Panel route renders in demo mode (desktop)', (
    tester,
  ) async {
    final container = await _pumpDemoApp(tester, const Size(1440, 1000));
    final router = container.read(routerProvider);
    expect(find.text('HMS Admin'), findsOneWidget);
    for (final item in navItems) {
      router.go(item.path);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: item.path);
      expect(find.text('Access denied'), findsNothing, reason: item.path);
      expect(router.routerDelegate.currentConfiguration.uri.path, item.path);
    }
  });

  testWidgets('pages render on a phone-sized screen with a drawer', (
    tester,
  ) async {
    final container = await _pumpDemoApp(tester, const Size(390, 844));
    final router = container.read(routerProvider);
    for (final path in [
      '/',
      '/departments',
      '/users',
      '/roles',
      '/numbering',
    ]) {
      router.go(path);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: path);
    }
    await tester.tap(find.byTooltip('Toggle navigation'));
    await _settle(tester);
    expect(find.byType(Drawer), findsOneWidget);
  });

  testWidgets('a role without permission sees no restricted menu or page', (
    tester,
  ) async {
    final container = await _pumpDemoApp(tester, const Size(1440, 1000));
    container.read(demoSessionProvider.notifier).switchRole(AppRole.labUser);
    await _settle(tester);
    expect(find.text('Users'), findsNothing);
    container.read(routerProvider).go('/users');
    await _settle(tester);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('department form validates required fields', (tester) async {
    final container = await _pumpDemoApp(tester, const Size(1440, 1000));
    container.read(routerProvider).go('/departments');
    await _settle(tester);
    await tester.tap(find.text('Add department'));
    await _settle(tester);
    await tester.tap(find.text('Create'));
    await _settle(tester);
    expect(find.text('Department ID is required'), findsOneWidget);
    expect(find.text('Department name is required'), findsOneWidget);
    expect(GoRouter.of(tester.element(find.byType(AlertDialog))), isNotNull);
  });
}
