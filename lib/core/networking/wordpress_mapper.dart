import '../models/article.dart';
import '../models/author.dart';
import '../models/category.dart';
import '../models/media_image.dart';
import '../utils/text_utils.dart';

/// Converts WordPress REST API JSON (`/wp/v2/...` with `_embed`) into app
/// models. Tolerant of missing and malformed embeds: WordPress returns error
/// objects in `_embedded` when an author or image is private or deleted.
class WordPressMapper {
  const WordPressMapper();

  Article article(Map<String, dynamic> json) {
    final embedded = json['_embedded'] as Map<String, dynamic>? ?? const {};
    final content = _rendered(json['content']);

    final terms = <Category>[];
    for (final group in embedded['wp:term'] as List<dynamic>? ?? const []) {
      if (group is! List) continue;
      for (final t in group) {
        if (t is Map<String, dynamic> && t['id'] is int) terms.add(term(t));
      }
    }
    final categoryIds = [
      for (final id in json['categories'] as List<dynamic>? ?? const [])
        id as int,
    ];
    final categories = terms.where((t) => t.kind == TermKind.category).toList()
      // WordPress returns embedded categories alphabetically; keep the
      // post's own order so the primary category comes first.
      ..sort(
        (a, b) =>
            _indexOr(categoryIds, a.id).compareTo(_indexOr(categoryIds, b.id)),
      );

    return Article(
      id: json['id'] as int,
      slug: json['slug'] as String,
      link: json['link'] as String,
      title: htmlToPlainText(_rendered(json['title'])),
      excerpt: htmlToPlainText(_rendered(json['excerpt'])),
      publishedAt: _date(json['date_gmt'] ?? json['date']),
      modifiedAt: json['modified_gmt'] == null && json['modified'] == null
          ? null
          : _date(json['modified_gmt'] ?? json['modified']),
      author: _author(embedded['author']),
      image:
          _featuredImage(embedded['wp:featuredmedia']) ??
          _fallbackImage(json['jetpack_featured_media_url']),
      categories: categories,
      tags: terms.where((t) => t.kind == TermKind.tag).toList(),
      categoryIds: categoryIds,
      contentHtml: content.isEmpty ? null : content,
      readingMinutes: content.isEmpty ? null : estimateReadingMinutes(content),
      sticky: json['sticky'] == true,
      authorId: json['author'] is int ? json['author'] as int : 0,
      featuredMediaId: json['featured_media'] is int
          ? json['featured_media'] as int
          : 0,
      tagIds: [
        for (final id in json['tags'] as List<dynamic>? ?? const [])
          if (id is int) id,
      ],
    );
  }

  Category term(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: htmlToPlainText(json['name'] as String? ?? ''),
    slug: json['slug'] as String? ?? '',
    kind: (json['taxonomy'] == 'post_tag') ? TermKind.tag : TermKind.category,
    count: json['count'] as int? ?? 0,
    description: htmlToPlainText(json['description'] as String?),
    parentId: json['parent'] as int? ?? 0,
  );

  MediaImage? media(Map<String, dynamic> json) {
    final details = json['media_details'];
    final variants = <ImageVariant>[];
    if (details is Map<String, dynamic>) {
      final sizes = details['sizes'];
      if (sizes is Map<String, dynamic>) {
        for (final s in sizes.values) {
          if (s is Map<String, dynamic> && s['source_url'] is String) {
            variants.add(
              ImageVariant(
                url: s['source_url'] as String,
                width: (s['width'] as num?)?.toInt() ?? 0,
                height: (s['height'] as num?)?.toInt() ?? 0,
              ),
            );
          }
        }
      }
    }
    final source = json['source_url'];
    if (source is String && !variants.any((v) => v.url == source)) {
      variants.add(
        ImageVariant(
          url: source,
          width:
              (details is Map ? details['width'] as num? : null)?.toInt() ?? 0,
          height:
              (details is Map ? details['height'] as num? : null)?.toInt() ?? 0,
        ),
      );
    }
    if (variants.isEmpty) return null;
    variants.sort((a, b) {
      if (a.width == 0) return 1;
      if (b.width == 0) return -1;
      return a.width.compareTo(b.width);
    });
    return MediaImage(
      variants: variants,
      alt: json['alt_text'] as String? ?? '',
      caption: htmlToPlainText(_rendered(json['caption'])),
    );
  }

  Author? _author(Object? embed) {
    if (embed is! List || embed.isEmpty) return null;
    return author(embed.first);
  }

  /// A `/wp/v2/users` item, or null if it's an error object.
  Author? author(Object? a) {
    if (a is! Map<String, dynamic> || a['id'] is! int || a['name'] is! String) {
      return null;
    }
    final avatars = a['avatar_urls'];
    String? avatar;
    if (avatars is Map<String, dynamic> && avatars.isNotEmpty) {
      avatar = (avatars['96'] ?? avatars.values.last) as String?;
    }
    return Author(
      id: a['id'] as int,
      name: htmlToPlainText(a['name'] as String),
      slug: a['slug'] as String? ?? '',
      avatarUrl: avatar,
    );
  }

  MediaImage? _featuredImage(Object? embed) {
    if (embed is! List || embed.isEmpty) return null;
    final m = embed.first;
    if (m is! Map<String, dynamic> || m['code'] != null) return null;
    return media(m);
  }

  MediaImage? _fallbackImage(Object? url) =>
      url is String && url.isNotEmpty ? MediaImage.single(url) : null;

  static String _rendered(Object? field) => switch (field) {
    {'rendered': final String r} => r,
    final String s => s,
    _ => '',
  };

  static DateTime _date(Object? value) {
    final s = value as String;
    // `date_gmt` has no zone designator; treat it as UTC.
    return DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z')
        .toLocal();
  }

  static int _indexOr(List<int> ids, int id) {
    final i = ids.indexOf(id);
    return i < 0 ? ids.length : i;
  }
}
