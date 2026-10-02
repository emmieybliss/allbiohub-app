import 'package:flutter/material.dart';

/// Topics a person can subscribe to for push notifications. Values are the
/// FCM topic names, so they must not change once released.
enum NotificationTopic {
  breaking('breaking', 'Breaking stories'),
  celebrity('celebrity', 'Celebrity'),
  technology('technology', 'Technology'),
  startups('startups', 'Startups'),
  money('money', 'Money & Career'),
  biography('biography', 'Biography'),
  spotlight('spotlight', 'Spotlight');

  const NotificationTopic(this.topic, this.label);

  final String topic;
  final String label;
}

/// Reader text size, applied as a multiplier on article body text.
enum ReaderTextSize {
  small(0.9, 'Small'),
  medium(1.0, 'Default'),
  large(1.15, 'Large'),
  extraLarge(1.3, 'Extra large');

  const ReaderTextSize(this.scale, this.label);

  final double scale;
  final String label;
}

class UserPreferences {
  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.textSize = ReaderTextSize.medium,
    this.onboardingComplete = false,
    this.interestSlugs = const {},
    this.notificationTopics = const {NotificationTopic.breaking},
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['theme'],
          orElse: () => ThemeMode.system,
        ),
        textSize: ReaderTextSize.values.firstWhere(
          (s) => s.name == json['textSize'],
          orElse: () => ReaderTextSize.medium,
        ),
        onboardingComplete: json['onboarded'] as bool? ?? false,
        interestSlugs: {
          for (final s in json['interests'] as List<dynamic>? ?? const []) '$s',
        },
        notificationTopics: {
          for (final t
              in json['topics'] as List<dynamic>? ?? const ['breaking'])
            ...NotificationTopic.values.where((v) => v.topic == t),
        },
      );

  final ThemeMode themeMode;
  final ReaderTextSize textSize;
  final bool onboardingComplete;

  /// Category slugs chosen during onboarding, used to order Home sections.
  final Set<String> interestSlugs;
  final Set<NotificationTopic> notificationTopics;

  UserPreferences copyWith({
    ThemeMode? themeMode,
    ReaderTextSize? textSize,
    bool? onboardingComplete,
    Set<String>? interestSlugs,
    Set<NotificationTopic>? notificationTopics,
  }) => UserPreferences(
    themeMode: themeMode ?? this.themeMode,
    textSize: textSize ?? this.textSize,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    interestSlugs: interestSlugs ?? this.interestSlugs,
    notificationTopics: notificationTopics ?? this.notificationTopics,
  );

  Map<String, dynamic> toJson() => {
    'theme': themeMode.name,
    'textSize': textSize.name,
    'onboarded': onboardingComplete,
    'interests': interestSlugs.toList(),
    'topics': notificationTopics.map((t) => t.topic).toList(),
  };
}
