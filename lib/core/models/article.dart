import 'author.dart';
import 'category.dart';
import 'media_image.dart';

/// A story from AllBioHub. List endpoints return it without [contentHtml];
/// the reader fetches the full article.
class Article {
  const Article({
    required this.id,
    required this.slug,
    required this.link,
    required this.title,
    required this.excerpt,
    required this.publishedAt,
    this.modifiedAt,
    this.author,
    this.image,
    this.categories = const [],
    this.tags = const [],
    this.categoryIds = const [],
    this.contentHtml,
    this.readingMinutes,
    this.sticky = false,
    this.authorId = 0,
    this.featuredMediaId = 0,
    this.tagIds = const [],
  });

  factory Article.fromJson(Map<String, dynamic> json) => Article(
    id: json['id'] as int,
    slug: json['slug'] as String,
    link: json['link'] as String,
    title: json['title'] as String,
    excerpt: json['excerpt'] as String? ?? '',
    publishedAt: DateTime.parse(json['published'] as String),
    modifiedAt: json['modified'] == null
        ? null
        : DateTime.parse(json['modified'] as String),
    author: json['author'] == null
        ? null
        : Author.fromJson(json['author'] as Map<String, dynamic>),
    image: json['image'] == null
        ? null
        : MediaImage.fromJson(json['image'] as Map<String, dynamic>),
    categories: [
      for (final c in json['categories'] as List<dynamic>? ?? const [])
        Category.fromJson(c as Map<String, dynamic>),
    ],
    tags: [
      for (final c in json['tags'] as List<dynamic>? ?? const [])
        Category.fromJson(c as Map<String, dynamic>),
    ],
    categoryIds: [
      for (final id in json['categoryIds'] as List<dynamic>? ?? const [])
        id as int,
    ],
    readingMinutes: json['readingMinutes'] as int?,
    sticky: json['sticky'] as bool? ?? false,
  );

  /// Fills in details that came back as ids only (when the server doesn't
  /// honour `_embed`).
  Article withDetails({
    Author? author,
    MediaImage? image,
    List<Category>? categories,
    List<Category>? tags,
  }) => Article(
    id: id,
    slug: slug,
    link: link,
    title: title,
    excerpt: excerpt,
    publishedAt: publishedAt,
    modifiedAt: modifiedAt,
    author: author ?? this.author,
    image: image ?? this.image,
    categories: categories ?? this.categories,
    tags: tags ?? this.tags,
    categoryIds: categoryIds,
    contentHtml: contentHtml,
    readingMinutes: readingMinutes,
    sticky: sticky,
    authorId: authorId,
    featuredMediaId: featuredMediaId,
    tagIds: tagIds,
  );

  final int id;
  final String slug;

  /// Canonical URL on allbiohub.com, used for sharing.
  final String link;
  final String title;

  /// Plain-text summary.
  final String excerpt;
  final DateTime publishedAt;
  final DateTime? modifiedAt;
  final Author? author;
  final MediaImage? image;
  final List<Category> categories;
  final List<Category> tags;
  final List<int> categoryIds;

  /// WordPress-rendered HTML; null in list responses.
  final String? contentHtml;
  final int? readingMinutes;
  final bool sticky;

  /// Raw ids from the API, used to fetch details the response didn't embed.
  final int authorId;
  final int featuredMediaId;
  final List<int> tagIds;

  Category? get primaryCategory => categories.isEmpty ? null : categories.first;

  /// Serialized for bookmarks and the offline cache. Content is left out to
  /// keep storage small; the reader re-fetches (or uses its own cache).
  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'link': link,
    'title': title,
    'excerpt': excerpt,
    'published': publishedAt.toIso8601String(),
    'modified': modifiedAt?.toIso8601String(),
    'author': author?.toJson(),
    'image': image?.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'tags': tags.map((c) => c.toJson()).toList(),
    'categoryIds': categoryIds,
    'readingMinutes': readingMinutes,
    'sticky': sticky,
  };

  @override
  bool operator ==(Object other) => other is Article && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
