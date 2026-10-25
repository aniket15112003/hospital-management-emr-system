// Regenerates functions/default_roles.json from the Dart role matrix so the
// backend bootstrap seeds exactly what the client expects:
//   dart run tool/export_default_roles.dart
import 'dart:convert';
import 'dart:io';

import 'package:hes/core/auth/permissions.dart';

void main() {
  final out = {
    for (final r in AppRole.values)
      if (r != AppRole.superAdmin)
        r.id: {
          'name': r.label,
          'permissions': permissionsToJson(defaultPermissionsFor(r)),
        },
  };
  File(
    'functions/default_roles.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('Wrote functions/default_roles.json');
}
