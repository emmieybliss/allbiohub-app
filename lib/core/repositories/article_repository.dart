import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/article.dart';
import '../models/category.dart';
import '../models/paginated.dart';
import '../networking/api_client.dart';
import '../networking/app_exception.dart';
import '../networking/wordpress_mapper.dart';

/// Stories from the WordPress REST API (`/wp-json/wp/v2`).
class ArticleRepository {
  ArticleRepository({
    required this._client,
    required AppConfig config,
    required this._taxonomy,
    this._mapper = const WordPressMapper(),
  }) : _base = config.wordpressApiBase;

  final ApiClient _client;
  final String _base;
  final TaxonomyRepository _taxonomy;
  final WordPressMapper _mapper;

  static const _embed = 'author,wp:featuredmedia,wp:term';

  /// Fields for lists: no `content`, which is by far the heaviest field.
  static const _listFields =
      'id,date,date_gmt,modified,modified_gmt,slug,link,title,excerpt,author,'
      'featured_media,categories,tags,sticky,_links,_embedded';
  static const _fullFields = '$_listFields,content';

  Future<Paginated<Article>> latest({
    int page = 1,
    int perPage = 10,
    int? categoryId,
    List<int> categoryIds = const [],
    int? tagId,
    List<int> excludeIds = const [],
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    final ApiResponse response;
    try {
      response = await _client.getJson(
        '$_base/posts',
        query: {
          'page': page,
          'per_page': perPage,
          'categories': categoryIds.isNotEmpty
              ? categoryIds.join(',')
              : categoryId,
          'tags': tagId,
          if (excludeIds.isNotEmpty) 'exclude': excludeIds.join(','),
          '_embed': _embed,
          '_fields': _listFields,
        },
        maxAge: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        cancelToken: cancelToken,
      );
    } on AppException catch (e) {
      if (page > 1 && e.kind == AppErrorKind.notFound) return _endOfList(page);
      rethrow;
    }
    return Paginated(
      items: await _complete(_articles(response.data)),
      page: page,
      totalPages: response.totalPages,
      total: response.total,
      stale: response.stale,
    );
  }

  /// Past the last page: an empty page rather than an error.
  static Paginated<Article> _endOfList(int page) =>
      Paginated(items: const [], page: page, totalPages: page - 1);

  /// Sticky posts, which editors pin on the website's front page.
  Future<List<Article>> featured({bool forceRefresh = false}) async {
    final response = await _client.getJson(
      '$_base/posts',
      query: {
        'sticky': true,
        'per_page': 5,
        '_embed': _embed,
        '_fields': _listFields,
      },
      maxAge: const Duration(minutes: 10),
      forceRefresh: forceRefresh,
    );
    return _complete(_articles(response.data));
  }

  Future<Article> byId(int id, {bool forceRefresh = false}) async {
    final response = await _client.getJson(
      '$_base/posts/$id',
      query: {'_embed': _embed, '_fields': _fullFields},
      maxAge: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AppException(AppErrorKind.badResponse);
    }
    return (await _complete([_mapper.article(data)], withTags: true)).single;
  }

  /// Looks up a story by its URL slug (used by deep links).
  Future<Article> bySlug(String slug, {bool forceRefresh = false}) async {
    final response = await _client.getJson(
      '$_base/posts',
      query: {'slug': slug, '_embed': _embed, '_fields': _fullFields},
      maxAge: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
    final items = await _complete(_articles(response.data), withTags: true);
    if (items.isEmpty) throw const AppException(AppErrorKind.notFound);
    return items.first;
  }

  /// Other recent stories in the same primary category.
  Future<List<Article>> related(Article article, {int count = 4}) async {
    final categoryId =
        article.primaryCategory?.id ??
        (article.categoryIds.isEmpty ? null : article.categoryIds.first);
    if (categoryId == null) return const [];
    final page = await latest(
      perPage: count,
      categoryId: categoryId,
      excludeIds: [article.id],
    );
    return page.items;
  }

  Future<Paginated<Article>> search(
    String query, {
    int page = 1,
    int perPage = 10,
    CancelToken? cancelToken,
  }) async {
    final response = await _client.getJson(
      '$_base/posts',
      query: {
        'search': query,
        'page': page,
        'per_page': perPage,
        '_embed': _embed,
        '_fields': _listFields,
      },
      maxAge: const Duration(minutes: 10),
      cancelToken: cancelToken,
    );
    return Paginated(
      items: await _complete(_articles(response.data)),
      page: page,
      totalPages: response.totalPages,
      total: response.total,
      stale: response.stale,
    );
  }

  /// Some servers and caches drop `_embed`, returning only ids for the
  /// author, image and terms. Fetch whatever is missing in one batched
  /// request per kind (cached for a day). Failures leave the gaps empty
  /// rather than failing the list: cards fall back to placeholders.
  Future<List<Article>> _complete(
    List<Article> articles, {
    bool withTags = false,
  }) async {
    final mediaIds = {
      for (final a in articles)
        if (a.image == null && a.featuredMediaId > 0) a.featuredMediaId,
    };
    final authorIds = {
      for (final a in articles)
        if (a.author == null && a.authorId > 0) a.authorId,
    };
    final needsCategories = articles.any(
      (a) => a.categories.isEmpty && a.categoryIds.isNotEmpty,
    );
    final tagIds = withTags
        ? {
            for (final a in articles)
              if (a.tags.isEmpty) ...a.tagIds,
          }
        : const <int>{};
    if (mediaIds.isEmpty &&
        authorIds.isEmpty &&
        !needsCategories &&
        tagIds.isEmpty) {
      return articles;
    }

    // Started together, awaited in turn.
    final mediaFuture = _byIds('media', mediaIds, _mapper.media);
    final authorsFuture = _byIds('users', authorIds, _mapper.author);
    final categoriesFuture = needsCategories
        ? _taxonomy.allCategoriesById().catchError(
            (Object _) => <int, Category>{},
          )
        : Future.value(const <int, Category>{});
    final tagsFuture = _byIds(
      'tags',
      tagIds,
      (j) => _mapper.term({...j, 'taxonomy': 'post_tag'}),
    );
    final media = await mediaFuture;
    final authors = await authorsFuture;
    final categories = await categoriesFuture;
    final tags = await tagsFuture;

    return [
      for (final a in articles)
        a.withDetails(
          image: a.image ?? media[a.featuredMediaId],
          author: a.author ?? authors[a.authorId],
          categories: a.categories.isNotEmpty
              ? null
              : [for (final id in a.categoryIds) ?categories[id]],
          tags: a.tags.isNotEmpty || tags.isEmpty
              ? null
              : [for (final id in a.tagIds) ?tags[id]],
        ),
    ];
  }

  Future<Map<int, T>> _byIds<T extends Object>(
    String endpoint,
    Set<int> ids,
    T? Function(Map<String, dynamic>) map,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final sorted = ids.toList()..sort();
      final response = await _client.getJson(
        '$_base/$endpoint',
        query: {'include': sorted.join(','), 'per_page': sorted.length},
        maxAge: const Duration(days: 1),
      );
      final data = response.data;
      if (data is! List) return const {};
      final result = <int, T>{};
      for (final item in data) {
        if (item is! Map<String, dynamic> || item['id'] is! int) continue;
        final value = map(item);
        if (value != null) result[item['id'] as int] = value;
      }
      return result;
    } on Object {
      return const {};
    }
  }

  List<Article> _articles(Object? data) {
    if (data is! List) throw const AppException(AppErrorKind.badResponse);
    final result = <Article>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(_mapper.article(item));
      } on Object {
        // Skip a single malformed post rather than failing the whole list.
      }
    }
    return result;
  }
}

/// Categories and tags.
class TaxonomyRepository {
  TaxonomyRepository({
    required this._client,
    required AppConfig config,
    this._mapper = const WordPressMapper(),
  }) : _base = config.wordpressApiBase;

  final ApiClient _client;
  final String _base;
  final WordPressMapper _mapper;

  /// Internal or commercial categories that aren't editorial sections.
  static const hiddenCategorySlugs = {
    'uncategorized',
    'editorial-submission',
    'sponsored',
  };

  /// Every category (including hidden ones) by id, for labelling stories.
  Future<Map<int, Category>> allCategoriesById() async {
    final response = await _client.getJson(
      '$_base/categories',
      query: {
        'per_page': 100,
        '_fields': 'id,name,slug,count,description,parent',
      },
      maxAge: const Duration(hours: 12),
    );
    return {for (final c in _terms(response.data, TermKind.category)) c.id: c};
  }

  /// Editorial categories with at least one story, largest first.
  Future<List<Category>> categories({bool forceRefresh = false}) async {
    final response = await _client.getJson(
      '$_base/categories',
      query: {
        'per_page': 100,
        'hide_empty': true,
        'orderby': 'count',
        'order': 'desc',
        '_fields': 'id,name,slug,count,description,parent',
      },
      maxAge: const Duration(hours: 12),
      forceRefresh: forceRefresh,
    );
    return _terms(response.data, TermKind.category)
        .where((c) => c.count > 0 && !hiddenCategorySlugs.contains(c.slug))
        .toList();
  }

  Future<List<Category>> popularTags({int count = 20}) async {
    final response = await _client.getJson(
      '$_base/tags',
      query: {
        'per_page': count,
        'orderby': 'count',
        'order': 'desc',
        'hide_empty': true,
        '_fields': 'id,name,slug,count',
      },
      maxAge: const Duration(hours: 12),
    );
    return _terms(
      response.data,
      TermKind.tag,
    ).where((t) => t.count > 1).toList();
  }

  Future<Category> categoryBySlug(String slug) async {
    final all = await categories();
    for (final c in all) {
      if (c.slug == slug) return c;
    }
    final response = await _client.getJson(
      '$_base/categories',
      query: {'slug': slug, '_fields': 'id,name,slug,count,description,parent'},
      maxAge: const Duration(hours: 12),
    );
    final found = _terms(response.data, TermKind.category);
    if (found.isEmpty) throw const AppException(AppErrorKind.notFound);
    return found.first;
  }

  Future<Category> tagBySlug(String slug) async {
    final response = await _client.getJson(
      '$_base/tags',
      query: {'slug': slug, '_fields': 'id,name,slug,count,description'},
      maxAge: const Duration(hours: 12),
    );
    final found = _terms(response.data, TermKind.tag);
    if (found.isEmpty) throw const AppException(AppErrorKind.notFound);
    return found.first;
  }

  /// Categories and tags whose name matches [query].
  Future<List<Category>> searchTopics(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final results = await Future.wait([
      for (final kind in TermKind.values)
        _client
            .getJson(
              '$_base/${kind == TermKind.category ? 'categories' : 'tags'}',
              query: {
                'search': query,
                'per_page': 10,
                'hide_empty': true,
                '_fields': 'id,name,slug,count',
              },
              maxAge: const Duration(hours: 1),
              cancelToken: cancelToken,
            )
            .then((r) => _terms(r.data, kind)),
    ]);
    return results
        .expand((list) => list)
        .where((t) => !hiddenCategorySlugs.contains(t.slug))
        .toList();
  }

  List<Category> _terms(Object? data, TermKind kind) {
    if (data is! List) throw const AppException(AppErrorKind.badResponse);
    return [
      for (final item in data)
        if (item is Map<String, dynamic> && item['id'] is int)
          _mapper.term({
            ...item,
            'taxonomy': kind == TermKind.tag ? 'post_tag' : 'category',
          }),
    ];
  }
}
