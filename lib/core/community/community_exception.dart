/// Why a community action failed, in words that can be shown to people.
enum CommunityErrorKind {
  offline,
  signInRequired,
  emailUnverified,
  profileRequired,
  rateLimited,
  restricted,
  forbidden,
  invalid,
  notFound,
  alreadyExists,
  unavailable,
  unknown,
}

class CommunityException implements Exception {
  const CommunityException(this.kind, {this._message, this.field});

  final CommunityErrorKind kind;
  final String? _message;

  /// Form field the server objected to, when it said.
  final String? field;

  static const offlineMessage =
      'You are offline. Connect to the internet to perform this action.';

  String get message =>
      _message ??
      switch (kind) {
        CommunityErrorKind.offline => offlineMessage,
        CommunityErrorKind.signInRequired => 'Sign in to do this.',
        CommunityErrorKind.emailUnverified =>
          'Verify your email address first. Check your inbox for the link.',
        CommunityErrorKind.profileRequired => 'Choose a username first.',
        CommunityErrorKind.rateLimited =>
          "You're doing that too often. Try again later.",
        CommunityErrorKind.restricted =>
          "Your account can't take part in the community right now.",
        CommunityErrorKind.forbidden => "You can't do that.",
        CommunityErrorKind.invalid => 'Check what you entered and try again.',
        CommunityErrorKind.notFound => 'This is no longer available.',
        CommunityErrorKind.alreadyExists => 'That already exists.',
        CommunityErrorKind.unavailable =>
          "Community features aren't available right now.",
        CommunityErrorKind.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'CommunityException($kind, $message)';
}
