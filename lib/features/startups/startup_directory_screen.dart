import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/startup.dart';
import '../../core/repositories/startup_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/paged_list.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/state_views.dart';
import 'startup_providers.dart';
import 'startup_widgets.dart';

/// Searchable, filterable startup list.
class StartupDirectoryScreen extends ConsumerStatefulWidget {
  const StartupDirectoryScreen({
    super.key,
    this.initialQuery = const StartupQuery(),
  });

  final StartupQuery initialQuery;

  @override
  ConsumerState<StartupDirectoryScreen> createState() =>
      _StartupDirectoryScreenState();
}

class _StartupDirectoryScreenState
    extends ConsumerState<StartupDirectoryScreen> {
  late StartupQuery _query = widget.initialQuery;
  late final _search = TextEditingController(text: widget.initialQuery.search);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final q = value.trim();
      setState(
        () => _query = _query.copyWith(search: () => q.isEmpty ? null : q),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startupDirectoryProvider(_query));
    final notifier = ref.read(startupDirectoryProvider(_query).notifier);
    final activeFilters = _query.activeFilterCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup directory'),
        actions: [
          PopupMenuButton<StartupSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _query.sort,
            onSelected: (s) =>
                setState(() => _query = _query.copyWith(sort: s)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: StartupSort.newest, child: Text('Newest')),
              PopupMenuItem(
                value: StartupSort.updated,
                child: Text('Recently updated'),
              ),
              PopupMenuItem(
                value: StartupSort.verified,
                child: Text('Recently verified'),
              ),
              PopupMenuItem(value: StartupSort.name, child: Text('Name A–Z')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search startups',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: activeFilters > 0,
                  label: Text('$activeFilters'),
                  child: IconButton.filledTonal(
                    tooltip: 'Filters',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: _openFilters,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 600) notifier.loadMore();
                return false;
              },
              child: RefreshIndicator(
                onRefresh: notifier.refresh,
                child: _results(state, notifier),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(PagedState<Startup> s, PagedListNotifier<Startup> notifier) {
    if (s.isInitialLoading) {
      return ListView(
        children: const [
          Skeleton(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonBox(height: 170, radius: 16),
                  SizedBox(height: 12),
                  SkeletonBox(height: 170, radius: 16),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (s.error != null) {
      if (s.error is StartupDirectoryUnavailable) {
        return ListView(
          children: const [
            MessageView(
              icon: Icons.rocket_launch_rounded,
              title: 'The startup directory is on its way',
              message: 'Searching African startups in the app is coming soon.',
            ),
          ],
        );
      }
      return ListView(
        children: [ErrorView(error: s.error!, onRetry: notifier.retry)],
      );
    }
    final items = s.items;
    if (items.isEmpty) {
      return ListView(
        children: [
          MessageView(
            icon: Icons.filter_alt_off_rounded,
            title: 'No startups match your filters.',
            message: 'Try a different search or clear some filters.',
            actionLabel: _query.activeFilterCount > 0 ? 'Clear filters' : null,
            onAction: () => setState(() => _query = _query.clearFilters()),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => i < items.length
          ? StartupCard(startup: items[i])
          : LoadMoreFooter(
              isLoading: s.isLoadingMore,
              error: s.loadMoreError,
              onRetry: notifier.retry,
            ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<StartupQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(query: _query),
    );
    if (result != null && mounted) setState(() => _query = result);
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.query});

  final StartupQuery query;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late StartupQuery _draft = widget.query;
  late final _city = TextEditingController(text: widget.query.city);

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Widget _options(
    String title,
    List<FilterOption> options,
    String? selected,
    StartupQuery Function(String?) apply,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(title, style: context.text.titleSmall),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(o.label),
                selected: selected == o.value,
                onSelected: (on) =>
                    setState(() => _draft = apply(on ? o.value : null)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters =
        ref.watch(startupFiltersProvider).value ?? const StartupFilterOptions();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Filters', style: context.text.titleLarge),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _draft = _draft.clearFilters();
                    _city.clear();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _options(
                  'Industry',
                  filters.industries,
                  _draft.industry,
                  (v) => _draft.copyWith(industry: () => v),
                ),
                _options(
                  'Country',
                  filters.countries,
                  _draft.country,
                  (v) => _draft.copyWith(country: () => v),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Text('City', style: context.text.titleSmall),
                ),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(hintText: 'Any city'),
                  onChanged: (v) => _draft = _draft.copyWith(
                    city: () => v.trim().isEmpty ? null : v.trim(),
                  ),
                ),
                _options(
                  'Stage',
                  filters.stages,
                  _draft.stage,
                  (v) => _draft.copyWith(stage: () => v),
                ),
                _options(
                  'Funding',
                  filters.fundings,
                  _draft.funding,
                  (v) => _draft.copyWith(funding: () => v),
                ),
                _options(
                  'Business model',
                  filters.businessModels,
                  _draft.businessModel,
                  (v) => _draft.copyWith(businessModel: () => v),
                ),
                _options(
                  'Employees',
                  filters.employeeRanges,
                  _draft.employees,
                  (v) => _draft.copyWith(employees: () => v),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AllBioHub verified only'),
                  value: _draft.verified ?? false,
                  onChanged: (on) => setState(
                    () => _draft = _draft.copyWith(
                      verified: () => on ? true : null,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Claimed profiles only'),
                  value: _draft.claimed ?? false,
                  onChanged: (on) => setState(
                    () => _draft = _draft.copyWith(
                      claimed: () => on ? true : null,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured only'),
                  value: _draft.featured ?? false,
                  onChanged: (on) => setState(
                    () => _draft = _draft.copyWith(
                      featured: () => on ? true : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('Show startups'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
