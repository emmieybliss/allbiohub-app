import 'package:share_plus/share_plus.dart';

import '../models/article.dart';
import '../models/startup.dart';

/// Builds share text that always links to the canonical allbiohub.com URL,
/// and hands it to the system share sheet. Network-specific sharing (e.g.
/// WhatsApp or X intents with UTM tags) can be added here later.
class ShareService {
  const ShareService();

  static String articleText(Article article) =>
      '${article.title}\n\nRead more on AllBioHub:\n${article.link}';

  static String startupText(Startup startup) {
    final about = startup.tagline ?? startup.industry;
    return [
      startup.name,
      ?about,
      '',
      'Discover ${startup.name} on AllBioHub:',
      startup.link,
    ].join('\n');
  }

  Future<bool> shareArticle(Article article) =>
      _share(articleText(article), article.title);

  Future<bool> shareStartup(Startup startup) =>
      _share(startupText(startup), startup.name);

  Future<bool> _share(String text, String subject) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return result.status == ShareResultStatus.success;
  }
}
