import 'package:flutter/material.dart';

/// Design tokens, modelled on the XRay medical dashboard palette.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF089BAB);
  static const primaryDark = Color(0xFF067A87);
  static const primaryLight = Color(0xFFCEEBEE);
  static const secondary = Color(0xFFFC9F5B);
  static const success = Color(0xFF2CA87F);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFE64141);
  static const info = Color(0xFF3A8DDE);

  static const background = Color(0xFFEFF7F8);
  static const surface = Colors.white;
  static const border = Color(0xFFE6ECEE);
  static const heading = Color(0xFF374948);
  static const body = Color(0xFF6B7A7A);
  static const muted = Color(0xFFA0AAAB);
}

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  AppRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const card = 15.0;
}

class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 0)),
  ];
}

class AppBreakpoints {
  AppBreakpoints._();

  static const mobile = 700.0;
  static const desktop = 1200.0;
}
