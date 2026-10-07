import 'dart:convert';

import '../cache/local_store.dart';

/// Community features that can be switched on and off remotely, without a
/// new APK, from the `config/app` document in Firestore (COMMUNITY.md →
/// Feature switches). Every feature is off until switched on, and all of
/// them stay off in builds without Firebase.
enum Feature {
  accounts('accounts'),
  profiles('communityProfiles'),
  reactions('reactions'),
  comments('comments'),
  startupFollows('startupFollows'),
  founderFollows('founderFollows'),
  topicFollows('topicFollows'),
  savedSync('savedSync'),
  polls('polls'),
  questionOfTheDay('questionOfTheDay'),
  notificationCenter('notificationCenter'),
  storySubmissions('storySubmissions'),
  startupSubmissions('startupSubmissions'),
  startupClaims('startupClaims'),
  forYou('forYou'),
  aiAssistant('aiAssistant');

  const Feature(this.key);

  /// Field name under `features` in `config/app`.
  final String key;

  /// Features that only make sense with an account.
  bool get needsAccount => switch (this) {
    Feature.accounts || Feature.forYou || Feature.aiAssistant => false,
    _ => true,
  };
}

class FeatureFlags {
  const FeatureFlags(this._on);

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    final features = json['features'];
    if (features is! Map) return none;
    return FeatureFlags({
      for (final f in Feature.values)
        if (features[f.key] == true) f,
    });
  }

  static const none = FeatureFlags({});

  /// Everything on (tests and local development).
  static final all = FeatureFlags(Feature.values.toSet());

  final Set<Feature> _on;

  bool isOn(Feature feature) {
    if (!_on.contains(feature)) return false;
    // A feature that needs an account is off while accounts are off.
    return !feature.needsAccount || _on.contains(Feature.accounts);
  }

  bool get anyCommunity => isOn(Feature.accounts);

  Map<String, dynamic> toJson() => {
    'features': {for (final f in _on) f.key: true},
  };

  @override
  bool operator ==(Object other) =>
      other is FeatureFlags &&
      other._on.length == _on.length &&
      other._on.containsAll(_on);

  @override
  int get hashCode => Object.hashAllUnordered(_on);
}

/// Where switches come from: Firestore in the app, a fixed value in tests.
abstract class FeatureFlagSource {
  /// The current `config/app` document, or null when it can't be read.
  Future<Map<String, dynamic>?> fetch();
}

class FixedFeatureFlagSource implements FeatureFlagSource {
  const FixedFeatureFlagSource([this.json]);

  final Map<String, dynamic>? json;

  @override
  Future<Map<String, dynamic>?> fetch() async => json;
}

/// Last switches seen, so the app opens with them while offline.
class FeatureFlagCache {
  FeatureFlagCache(this._store);

  final LocalStore _store;
  static const _key = 'feature_flags';

  FeatureFlags load() {
    final raw = _store.get(_key);
    if (raw == null) return FeatureFlags.none;
    try {
      return FeatureFlags.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return FeatureFlags.none;
    }
  }

  Future<void> save(FeatureFlags flags) =>
      _store.put(_key, jsonEncode(flags.toJson()));
}
