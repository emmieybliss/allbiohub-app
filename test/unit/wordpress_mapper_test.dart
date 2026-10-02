import 'package:allbiohub/core/models/category.dart';
import 'package:allbiohub/core/networking/wordpress_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wp_fixtures.dart';

void main() {
  const mapper = WordPressMapper();

  test('maps an embedded post into an Article', () {
    final a = mapper.article(wpPost());
    expect(a.id, 101);
    expect(a.title, 'Tems’ Biography: From Lagos to the World');
    expect(a.excerpt, 'The singer’s journey so far…');
    expect(a.link, 'https://allbiohub.com/tems-biography/');
    expect(a.author?.name, 'Ada Obi');
    expect(a.author?.avatarUrl, contains('s=96'));
    expect(a.publishedAt.toUtc(), DateTime.utc(2026, 9, 28, 6, 29, 28));
    expect(a.contentHtml, contains('<strong>Tems</strong>'));
    expect(a.readingMinutes, 1);
    expect(a.tags.single.name, 'Afrobeats');
    expect(a.tags.single.kind, TermKind.tag);
  });

  test(
    'keeps the post\'s own category order so the primary category is first',
    () {
      final a = mapper.article(wpPost(categories: [137, 1]));
      expect(a.primaryCategory?.slug, 'celebrity-news');
      expect(a.primaryCategory?.displayName, 'Celebrity News');
    },
  );

  test('sorts image sizes smallest first and picks a sharp size', () {
    final image = mapper.article(wpPost()).image!;
    expect(image.variants.first.width, 150);
    expect(image.alt, 'Tems performing');
    expect(image.caption, 'Tems on stage');
    // A 300px slot on a 2x screen needs ≥600px: the 1024 "large" size.
    expect(image.urlFor(600), endsWith('tems-1024x640.jpg'));
    // Square thumbnails are skipped for non-square slots.
    expect(image.urlFor(100), endsWith('tems-300x188.jpg'));
    expect(image.urlFor(100, allowCropped: true), endsWith('tems-150x150.jpg'));
    expect(image.urlFor(5000), endsWith('tems.jpg'));
  });

  test('tolerates missing image and author error objects', () {
    final a = mapper.article(wpPost(withImage: false, authorError: true));
    expect(a.image, isNull);
    expect(a.author, isNull);
  });

  test('list responses without content have no reading time', () {
    final a = mapper.article(wpPost(content: null));
    expect(a.contentHtml, isNull);
    expect(a.readingMinutes, isNull);
  });

  test('decodes entities in term names', () {
    final c = mapper.term({
      'id': 216,
      'name': 'MONEY &amp; CAREER',
      'slug': 'money-career',
      'taxonomy': 'category',
    });
    expect(c.name, 'MONEY & CAREER');
    expect(c.displayName, 'Money & Career');
  });

  test('throws on a malformed post', () {
    expect(() => mapper.article({'id': 'oops'}), throwsA(anything));
  });

  test('article JSON round-trips for bookmarks', () {
    final a = mapper.article(wpPost());
    final copy = a.toJson();
    expect(copy['title'], a.title);
    expect(copy.containsKey('content'), isFalse);
  });
}
