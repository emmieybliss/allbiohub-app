import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/category.dart';
import '../../core/models/search_result.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/article_cards.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import '../home/home_providers.dart';
import '../startups/startup_widgets.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  SearchScope _scope = SearchScope.all;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _useQuery(String q) {
    _field.text = q;
    _field.selection = TextSelection.collapsed(offset: q.length);
    ref.read(searchControllerProvider.notifier)
      ..onQueryChanged(q)
      ..submit(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _field,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              controller.onQueryChanged(v);
              setState(() {});
            },
            onSubmitted: controller.submit,
            decoration: InputDecoration(
              hintText: 'Search stories, startups, topics',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _field.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _field.clear();
                        controller.onQueryChanged('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        bottom: state.query.length >= GlobalSearchController.minLength
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      for (final scope in SearchScope.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_scopeLabel(scope, state.results)),
                            selected: _scope == scope,
                            onSelected: (_) => setState(() => _scope = scope),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _body(context, state, controller),
      ),
    );
  }

  String _scopeLabel(SearchScope scope, SearchResults? r) {
    final (label, count) = switch (scope) {
      SearchScope.all => ('All', null),
      SearchScope.stories => ('Stories', r?.articles.length),
      SearchScope.startups => ('Startups', r?.startups.length),
      SearchScope.topics => ('Topics', r?.topics.length),
    };
    return count == null || count == 0 ? label : '$label ($count)';
  }

  Widget _body(
    BuildContext context,
    SearchState state,
    GlobalSearchController controller,
  ) {
    if (state.query.length < GlobalSearchController.minLength) {
      return _Suggestions(
        key: const ValueKey('suggestions'),
        recent: state.recent,
        onPick: _useQuery,
        onClear: controller.clearRecent,
      );
    }
    if (state.error != null) {
      return ErrorView(
        key: const ValueKey('error'),
        error: state.error!,
        onRetry: controller.retry,
      );
    }
    final results = state.results;
    if (results == null || (state.isLoading && results.query != state.query)) {
      return const SingleChildScrollView(
        key: ValueKey('loading'),
        child: ArticleListSkeleton(),
      );
    }
    return _Results(
      key: ValueKey(results.query),
      results: results,
      scope: _scope,
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({
    super.key,
    required this.recent,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent searches',
                    style: context.text.titleMedium,
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          ),
          for (final q in recent)
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(q),
              onTap: () => onPick(q),
            ),
        ],
        if (categories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Browse topics', style: context.text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  ActionChip(
                    label: Text(c.displayName),
                    onPressed: () =>
                        context.push(Routes.category(c.slug), extra: c),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.results, required this.scope});

  final SearchResults results;
  final SearchScope scope;

  @override
  Widget build(BuildContext context) {
    final showStories =
        scope == SearchScope.all || scope == SearchScope.stories;
    final showStartups =
        scope == SearchScope.all || scope == SearchScope.startups;
    final showTopics = scope == SearchScope.all || scope == SearchScope.topics;

    final empty = switch (scope) {
      SearchScope.all => results.isEmpty,
      SearchScope.stories => results.articles.isEmpty,
      SearchScope.startups => results.startups.isEmpty,
      SearchScope.topics => results.topics.isEmpty,
    };
    if (empty) {
      final startupsMissing =
          scope == SearchScope.startups && !results.startupsAvailable;
      return MessageView(
        icon: Icons.search_off_rounded,
        title: startupsMissing
            ? 'Startup search is coming soon'
            : 'No results found',
        message: startupsMissing
            ? 'The startup directory is not available in the app yet.'
            : 'Try another keyword.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (showTopics && results.topics.isNotEmpty) ...[
          if (scope == SearchScope.all) const _GroupTitle('Topics'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in results.topics)
                  ActionChip(
                    avatar: Icon(
                      t.kind == TermKind.tag
                          ? Icons.tag_rounded
                          : Icons.folder_outlined,
                      size: 18,
                    ),
                    label: Text(
                      t.kind == TermKind.tag ? t.name : t.displayName,
                    ),
                    onPressed: () => context.push(
                      t.kind == TermKind.tag
                          ? Routes.tag(t.slug)
                          : Routes.category(t.slug),
                      extra: t,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (showStartups && results.startups.isNotEmpty) ...[
          if (scope == SearchScope.all) const _GroupTitle('Startups'),
          for (final s
              in scope == SearchScope.all
                  ? results.startups.take(3)
                  : results.startups)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: StartupCard(startup: s),
            ),
        ],
        if (showStories && results.articles.isNotEmpty) ...[
          if (scope == SearchScope.all) const _GroupTitle('Stories'),
          for (final a in results.articles) ArticleListTile(article: a),
        ],
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: CategoryLabel(title, color: context.brand.muted),
  );
}

/// Search field look-alike that opens [SearchScreen].
class SearchLauncher extends StatelessWidget {
  const SearchLauncher({
    super.key,
    this.hint = 'Search stories, startups, topics',
  });

  final String hint;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      button: true,
      label: 'Search',
      excludeSemantics: true,
      child: Material(
        color: brand.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: brand.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(Routes.search),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: brand.muted),
                const SizedBox(width: 12),
                Text(
                  hint,
                  style: context.text.bodyMedium?.copyWith(color: brand.subtle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
