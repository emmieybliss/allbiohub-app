import 'package:allbiohub/core/models/startup.dart';
import 'package:allbiohub/core/services/share_service.dart';
import 'package:allbiohub/core/networking/wordpress_mapper.dart';
import 'package:allbiohub/core/utils/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';

void main() {
  test('htmlToPlainText strips tags and decodes entities', () {
    expect(
      htmlToPlainText('<p>Wizkid &amp; Burna&#8217;s   <b>tour</b></p>'),
      'Wizkid & Burna’s tour',
    );
    expect(htmlToPlainText('<p>Long story [&hellip;]</p>'), 'Long story…');
    expect(htmlToPlainText(null), '');
  });

  test('reading time is at least a minute', () {
    expect(estimateReadingMinutes('<p>short</p>'), 1);
    expect(estimateReadingMinutes('<p>${'word ' * 660}</p>'), 3);
  });

  test('relative dates', () {
    final now = DateTime(2026, 10, 2, 12);
    expect(
      relativeDate(now.subtract(const Duration(seconds: 20)), now: now),
      'Just now',
    );
    expect(
      relativeDate(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      relativeDate(now.subtract(const Duration(hours: 3)), now: now),
      '3 h ago',
    );
    expect(
      relativeDate(now.subtract(const Duration(days: 1)), now: now),
      'Yesterday',
    );
    expect(relativeDate(DateTime(2026, 8, 1), now: now), '1 Aug');
    expect(relativeDate(DateTime(2025, 8, 1), now: now), '1 Aug 2025');
  });

  test('share text links to the canonical website URL', () {
    final article = const WordPressMapper().article(wpPost());
    final text = ShareService.articleText(article);
    expect(text, startsWith(article.title));
    expect(text, contains('Read more on AllBioHub'));
    expect(text, endsWith('https://allbiohub.com/tems-biography/'));
    final startup = Startup.fromJson(startupJson());
    expect(
      ShareService.startupText(startup),
      endsWith('https://allbiohub.com/startups/vast/'),
    );
  });

  test('startup query counts and clears filters', () {
    const q = StartupQuery(search: 'pay', industry: 'Fintech', verified: true);
    expect(q.activeFilterCount, 2);
    final cleared = q.clearFilters();
    expect(cleared.activeFilterCount, 0);
    expect(cleared.search, 'pay');
    expect(q.copyWith(industry: () => null).industry, isNull);
  });
}
