import 'package:allbiohub/features/articles/article_html.dart';
import 'package:allbiohub/shared/widgets/app_image.dart';
import 'package:allbiohub/core/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<Uri>> pumpHtml(WidgetTester tester, String html) async {
  AppImage.disableNetwork = true;
  final taps = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArticleHtml(
            html: html,
            baseUrl: Uri.parse('https://allbiohub.com/some-story/'),
            onLinkTap: taps.add,
          ),
        ),
      ),
    ),
  );
  return taps;
}

/// Taps the first text span whose text contains [text].
void tapSpan(WidgetTester tester, String text) {
  final rich = tester.widgetList<RichText>(find.byType(RichText));
  for (final r in rich) {
    var done = false;
    r.text.visitChildren((span) {
      if (!done &&
          span is TextSpan &&
          (span.text ?? '').contains(text) &&
          span.recognizer is TapGestureRecognizer) {
        (span.recognizer! as TapGestureRecognizer).onTap!();
        done = true;
        return false;
      }
      return true;
    });
    if (done) return;
  }
  fail('No tappable span with "$text"');
}

void main() {
  testWidgets('renders paragraphs, headings and lists natively', (
    tester,
  ) async {
    await pumpHtml(tester, '''
      <p>First <strong>bold</strong> paragraph.</p>
      <h2>Early life</h2>
      <ul><li>One</li><li>Two</li></ul>
      <ol start="3"><li>Three</li></ol>
      <blockquote><p>A quote</p><cite>Someone</cite></blockquote>
      <hr>
    ''');
    expect(
      find.textContaining('First bold paragraph.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Early life', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('3.'), findsOneWidget);
    expect(find.textContaining('A quote', findRichText: true), findsOneWidget);
    expect(find.text('— Someone'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('drops scripts, styles and forms', (tester) async {
    await pumpHtml(
      tester,
      '<p>Safe</p><script>alert(1)</script><style>p{}</style><form><input value="x"></form>',
    );
    expect(find.textContaining('alert', findRichText: true), findsNothing);
    expect(find.textContaining('Safe', findRichText: true), findsOneWidget);
  });

  testWidgets(
    'links resolve against the article and unsafe schemes are inert',
    (tester) async {
      final taps = await pumpHtml(
        tester,
        '<p><a href="/category/biography/">Bio</a> and <a href="javascript:alert(1)">bad</a> '
        'and <a href="https://example.com/x">out</a></p>',
      );
      tapSpan(tester, 'Bio');
      tapSpan(tester, 'out');
      expect(taps, [
        Uri.parse('https://allbiohub.com/category/biography/'),
        Uri.parse('https://example.com/x'),
      ]);
      expect(() => tapSpan(tester, 'bad'), throwsA(anything));
    },
  );

  testWidgets('embeds become link cards and images keep captions', (
    tester,
  ) async {
    final taps = await pumpHtml(tester, '''
      <figure class="wp-block-embed"><iframe src="https://www.youtube.com/embed/abc123"></iframe></figure>
      <figure><img src="https://allbiohub.com/a.jpg" width="1200" height="800" alt="Stage"><figcaption>On stage</figcaption></figure>
    ''');
    expect(find.text('Watch on YouTube'), findsOneWidget);
    expect(find.text('On stage'), findsOneWidget);
    await tester.tap(find.text('Watch on YouTube'));
    expect(taps.single, Uri.parse('https://www.youtube.com/watch?v=abc123'));
  });

  testWidgets('uses lazy-load sources instead of data: placeholders', (
    tester,
  ) async {
    await pumpHtml(
      tester,
      '<p><img src="data:image/gif;base64,AAAA" data-src="https://allbiohub.com/real.jpg" width="10" height="10"></p>',
    );
    expect(find.byType(AppImage), findsOneWidget);
  });
}
