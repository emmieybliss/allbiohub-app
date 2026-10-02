import 'dart:convert';
import 'dart:io';

import 'package:allbiohub/core/models/startup.dart';
import 'package:flutter_test/flutter_test.dart';

/// `startup_api_sample.json` is real output from the WordPress add-on
/// (wordpress/allbiohub-app-api) running against test data, so this checks
/// that the plugin and the app agree on the contract in API.md.
void main() {
  final sample = jsonDecode(
    File('test/fixtures/startup_api_sample.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('the app parses every startup the plugin sends', () {
    final startups = [
      for (final s in sample['list'] as List<dynamic>)
        Startup.fromJson(s as Map<String, dynamic>),
    ];
    expect(startups, hasLength(2));

    final paystack = startups.firstWhere((s) => s.slug == 'paystack');
    expect(paystack.industry, 'Fintech, Payments');
    expect(paystack.city, 'Lagos');
    expect(paystack.foundedYear, 2015);
    expect(paystack.verified, isTrue);
    expect(paystack.featured, isTrue);
    expect(paystack.claimed, isFalse);
    expect(paystack.founders.map((f) => f.name), [
      'Shola Akinlade',
      'Ezra Olubi',
    ]);
    expect(paystack.socialLinks['linkedin'], contains('linkedin.com'));

    final vast = startups.firstWhere((s) => s.slug == 'vast');
    expect(vast.website, 'https://vastspace.com');
    expect(vast.stage, 'Series A');
    expect(vast.funding, 'Founder funding');
    expect(vast.claimed, isFalse);
    expect(vast.logo, isNull);
    expect(vast.createdAt, isNotNull);
  });

  test('the app parses the plugin filter options', () {
    final filters = StartupFilterOptions.fromJson(
      sample['filters'] as Map<String, dynamic>,
    );
    expect(filters.industries.map((o) => o.value), contains('Fintech'));
    expect(filters.countries.first.count, 1);
    expect(filters.stages.single.label, 'Series A');
    expect(filters.businessModels, isEmpty);
  });
}
