import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/category.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import '../discover/discover_screen.dart' show categoryIcon;
import '../home/home_providers.dart';

/// First-run introduction: three short pages and an optional interest
/// picker. Skippable at any point; no account needed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final Set<String> _interests = {};
  int _index = 0;

  static const _intro = [
    (
      icon: Icons.public_rounded,
      title: 'Discover the people, stories and ideas shaping Africa.',
      body:
          'Biography, celebrity news, money, careers and more, all in one hub.',
    ),
    (
      icon: Icons.auto_stories_rounded,
      title: 'Stories worth your time',
      body: 'Read the latest from AllBioHub in a clean, fast reader. Save stories for later.',
    ),
    (
      icon: Icons.rocket_launch_rounded,
      title: 'Explore African startups',
      body: 'Find startups, founders and companies, and the AllBioHub coverage behind them.',
    ),
  ];

  int get _pageCount => _intro.length + 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(preferencesProvider.notifier)
        .update(
          (p) =>
              p.copyWith(onboardingComplete: true, interestSlugs: _interests),
        );
    if (mounted) context.go(Routes.home);
  }

  void _next() {
    if (_index == _pageCount - 1) {
      _finish();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final last = _index == _pageCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Wordmark(size: 20),
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final page in _intro)
                    _IntroPage(
                      icon: page.icon,
                      title: page.title,
                      body: page.body,
                    ),
                  _InterestsPage(
                    selected: _interests,
                    onToggle: (slug) => setState(
                      () => _interests.contains(slug)
                          ? _interests.remove(slug)
                          : _interests.add(slug),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _index ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index ? brand.accent : brand.border,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    flex: 8,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        last
                            ? (_interests.isEmpty
                                  ? 'Start reading'
                                  : 'Continue')
                            : 'Next',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    // Centred when it fits; scrolls on short screens or large text.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: brand.accentSoft,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(icon, size: 42, color: brand.accentText),
              ),
              const SizedBox(height: 32),
              Text(title, style: context.text.displaySmall),
              const SizedBox(height: 16),
              Text(
                body,
                style: context.text.bodyLarge?.copyWith(
                  color: brand.muted,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestsPage extends ConsumerWidget {
  const _InterestsPage({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      children: [
        Text('What do you want to read?', style: context.text.displaySmall),
        const SizedBox(height: 12),
        Text(
          "Pick a few topics and we'll put them first. You can change this later.",
          style: context.text.bodyLarge?.copyWith(color: context.brand.muted),
        ),
        const SizedBox(height: 24),
        switch (categories) {
          AsyncData(:final value) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final Category c in value)
                FilterChip(
                  avatar: Icon(categoryIcon(c.slug), size: 18),
                  label: Text(c.displayName),
                  selected: selected.contains(c.slug),
                  onSelected: (_) => onToggle(c.slug),
                ),
            ],
          ),
          AsyncError() when !categories.isLoading => Text(
            "Topics couldn't load right now. You can choose them later in Profile.",
            style: context.text.bodyMedium,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}
