import 'article.dart';
import 'category.dart';
import 'startup.dart';

enum SearchScope { all, stories, startups, topics }

/// Results of a global search, grouped by kind. [startupsAvailable] is false
/// when the startup directory API can't be reached, so the UI can say so
/// instead of claiming there are no matches.
class SearchResults {
  const SearchResults({
    required this.query,
    this.articles = const [],
    this.startups = const [],
    this.topics = const [],
    this.startupsAvailable = true,
  });

  final String query;
  final List<Article> articles;
  final List<Startup> startups;
  final List<Category> topics;
  final bool startupsAvailable;

  bool get isEmpty => articles.isEmpty && startups.isEmpty && topics.isEmpty;
}
