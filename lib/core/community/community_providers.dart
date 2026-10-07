import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/local_store.dart';
import '../providers.dart';
import 'community_api.dart';
import 'feature_flags.dart';
import 'models.dart';
import 'unavailable_community_api.dart';

// Community dependency graph. main.dart swaps in the Firebase
// implementations when the build has Firebase settings; tests override
// them with in-memory fakes.

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const UnavailableAuthRepository(),
);

final communityApiProvider = Provider<CommunityApi>(
  (ref) => const UnavailableCommunityApi(),
);

final featureFlagSourceProvider = Provider<FeatureFlagSource>(
  (ref) => const FixedFeatureFlagSource(),
);

/// Saved startups and founders on this device.
final savedEntityStoreProvider = Provider<LocalStore>(
  (ref) => MemoryLocalStore(),
);

/// Remote feature switches. Opens with the last switches seen (or all off),
/// then refreshes from the server.
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  late final FeatureFlagCache _cache;

  @override
  FeatureFlags build() {
    if (!ref.watch(communityApiProvider).isAvailable) return FeatureFlags.none;
    _cache = FeatureFlagCache(ref.watch(settingsStoreProvider));
    Future.microtask(refresh);
    return _cache.load();
  }

  Future<void> refresh() async {
    final json = await ref.read(featureFlagSourceProvider).fetch();
    if (json == null || !ref.mounted) return;
    final flags = FeatureFlags.fromJson(json);
    state = flags;
    await _cache.save(flags);
  }
}

final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(
      FeatureFlagsNotifier.new,
    );

/// Whether a community feature is on.
final featureProvider = Provider.family<bool, Feature>(
  (ref, feature) => ref.watch(featureFlagsProvider).isOn(feature),
);

/// The signed-in person, or null for guests.
final authUserProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authUserProvider).value?.uid,
);

/// The signed-in person's public profile (null until they choose a
/// username).
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(communityApiProvider).watchProfile(uid);
});

final myAccountProvider = StreamProvider<AccountSettings?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(communityApiProvider).watchAccount(uid);
});

/// People the signed-in person blocked. Their comments are hidden.
final blockedUsersProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const {});
  return ref.watch(communityApiProvider).watchBlocked(uid);
});

final followsProvider = StreamProvider<List<FollowedItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(communityApiProvider).watchFollows(uid);
});

/// Follows changed in this session but not yet confirmed by the server
/// list. Lets Follow buttons switch at once and roll back on failure.
class FollowOverrides extends Notifier<Map<FollowTarget, bool>> {
  @override
  Map<FollowTarget, bool> build() {
    // Once the server list agrees with an override it is no longer needed.
    ref.listen(followsProvider, (_, next) {
      final follows = next.value;
      if (follows == null || state.isEmpty) return;
      final ids = {for (final f in follows) f.target};
      final pending = {
        for (final e in state.entries)
          if (ids.contains(e.key) != e.value) e.key: e.value,
      };
      if (pending.length != state.length) state = pending;
    });
    ref.listen(currentUidProvider, (_, _) => state = const {});
    return const {};
  }

  /// Follows or unfollows. Throws (after rolling back) when it fails.
  Future<void> set(FollowTarget target, bool follow) async {
    state = {...state, target: follow};
    try {
      await ref.read(communityApiProvider).setFollow(target, follow: follow);
    } on Object {
      if (ref.mounted) state = {...state}..remove(target);
      rethrow;
    }
  }
}

final followOverridesProvider =
    NotifierProvider<FollowOverrides, Map<FollowTarget, bool>>(
      FollowOverrides.new,
    );

final isFollowingProvider = Provider.family<bool, FollowTarget>((ref, target) {
  final override = ref.watch(followOverridesProvider.select((m) => m[target]));
  if (override != null) return override;
  final follows = ref.watch(followsProvider).value ?? const [];
  return follows.any((f) => f.target == target);
});

final unreadNotificationsProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || !ref.watch(featureProvider(Feature.notificationCenter))) {
    return Stream.value(0);
  }
  return ref.watch(communityApiProvider).watchUnreadCount(uid);
});

/// Registers this phone for personal push notifications while someone is
/// signed in, and unregisters it before they sign out.
class DeviceRegistration {
  DeviceRegistration(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshes;
  String? _registeredFor;

  Future<void> onUser(String? uid) async {
    final notifications = _ref.read(notificationServiceProvider);
    final api = _ref.read(communityApiProvider);
    if (!notifications.isAvailable || !api.isAvailable) return;
    if (uid == null || uid == _registeredFor) return;
    _registeredFor = uid;
    try {
      final token = await notifications.token();
      if (token != null) await api.registerDevice(token);
      await _refreshes?.cancel();
      _refreshes = notifications.tokenRefreshes.listen(
        (t) => api.registerDevice(t).catchError((Object _) {}),
      );
    } on Object catch (e) {
      debugPrint('Device not registered: $e');
      _registeredFor = null;
    }
  }

  /// Call before signing out so this phone stops getting their notifications.
  Future<void> beforeSignOut() async {
    final notifications = _ref.read(notificationServiceProvider);
    await _refreshes?.cancel();
    _refreshes = null;
    _registeredFor = null;
    try {
      final token = await notifications.token();
      if (token != null) {
        await _ref.read(communityApiProvider).unregisterDevice(token);
      }
    } on Object catch (e) {
      debugPrint('Device not unregistered: $e');
    }
  }
}

final deviceRegistrationProvider = Provider<DeviceRegistration>((ref) {
  final registration = DeviceRegistration(ref);
  ref.listen(
    currentUidProvider,
    (_, uid) => registration.onUser(uid),
    fireImmediately: true,
  );
  return registration;
});

/// Signs out after unregistering this phone from personal notifications.
Future<void> signOut(WidgetRef ref) async {
  await ref.read(deviceRegistrationProvider).beforeSignOut();
  await ref.read(authRepositoryProvider).signOut();
}
