/// Build-time configuration.
///
/// Values come from `--dart-define` or `--dart-define-from-file=.env.<name>`
/// (see `.env.example`). Only public configuration belongs here: never put
/// admin credentials, API secrets or private keys in the app.
class AppConfig {
  const AppConfig({
    required this.siteUrl,
    required this.environment,
    required this.startupApiPath,
    this.privacyPolicyUrl = '',
    this.termsUrl = '',
    this.contactEmail = '',
    this.firebaseProjectId = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseMessagingSenderId = '',
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      siteUrl: String.fromEnvironment(
        'WORDPRESS_BASE_URL',
        defaultValue: 'https://allbiohub.com',
      ),
      environment: String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      startupApiPath: String.fromEnvironment(
        'STARTUP_API_PATH',
        defaultValue: '/wp-json/allbiohub/v1',
      ),
      privacyPolicyUrl: String.fromEnvironment(
        'PRIVACY_POLICY_URL',
        defaultValue: 'https://allbiohub.com/privacy-policy/',
      ),
      termsUrl: String.fromEnvironment(
        'TERMS_URL',
        defaultValue: 'https://allbiohub.com/terms-and-conditions/',
      ),
      contactEmail: String.fromEnvironment('CONTACT_EMAIL'),
      firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseMessagingSenderId: String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
      ),
    );
  }

  /// Canonical website, e.g. `https://allbiohub.com`. Shared links point here.
  final String siteUrl;

  /// `development`, `staging` or `production`.
  final String environment;

  /// Base path of the startup directory API on [siteUrl].
  final String startupApiPath;

  /// Website privacy policy. Empty until the site publishes one; the app
  /// then shows its own data summary only.
  final String privacyPolicyUrl;
  final String termsUrl;

  /// Shown in Profile → Contact when set.
  final String contactEmail;

  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;

  String get wordpressApiBase => '$siteUrl/wp-json/wp/v2';
  String get startupApiBase => '$siteUrl$startupApiPath';
  String get siteHost => Uri.parse(siteUrl).host;

  bool get isProduction => environment == 'production';

  bool get hasFirebase =>
      firebaseProjectId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty;

  Uri pageUrl(String slug) => Uri.parse('$siteUrl/$slug/');
}
