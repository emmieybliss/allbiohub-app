import 'dart:math' as math;

import 'package:allbiohub/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test('$name theme text meets WCAG AA contrast', () {
      final brand = theme.extension<BrandColors>()!;
      final bg = theme.colorScheme.surface;
      expect(contrast(theme.colorScheme.onSurface, bg), greaterThan(7));
      expect(contrast(brand.muted, bg), greaterThan(4.5));
      expect(contrast(brand.goldText, bg), greaterThan(4.5));
      expect(contrast(brand.goldText, brand.card), greaterThan(4.5));
      expect(contrast(brand.onGold, brand.gold), greaterThan(4.5));
    });
  }
}
