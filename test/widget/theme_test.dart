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
      expect(contrast(brand.accentText, bg), greaterThan(4.5));
      expect(contrast(brand.accentText, brand.card), greaterThan(4.5));
      expect(contrast(brand.onAccent, brand.accent), greaterThan(4.5));
      // The orange is for large text (the wordmark), which needs 3:1.
      expect(contrast(brand.highlight, bg), greaterThan(3));
    });
  }
}
