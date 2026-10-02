import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/common.dart';
import '../home/home_providers.dart';

/// Brief branded intro. Warms the category and Home caches in the
/// background and moves on after ~1 second whether or not they finished.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).log(AnalyticsEvent.appOpen);
    // Start loading Home now; the result is cached by the provider.
    unawaited(ref.read(homeFeedProvider.future).then((_) {}, onError: (_) {}));
    Future.delayed(const Duration(milliseconds: 1000), _continue);
  }

  void _continue() {
    if (!mounted) return;
    final onboarded = ref.read(preferencesProvider).onboardingComplete;
    final pending = ref.read(pendingLocationProvider.notifier).take();
    final router = GoRouter.of(context);
    router.go(onboarded ? Routes.home : Routes.onboarding);
    // A notification tapped at launch opens on top of Home.
    if (onboarded && pending != null && pending != Routes.home) {
      router.push(pending);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(fade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 112),
                const SizedBox(height: 20),
                const Wordmark(size: 34),
                const SizedBox(height: 10),
                Text(
                  'INFORM. INSPIRE. IMPACT.',
                  style: fontStyle(
                    AppFonts.body,
                    11,
                    FontWeight.w600,
                    letterSpacing: 3,
                    color: context.brand.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
