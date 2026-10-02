import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../core/models/media_image.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_image.dart';

typedef LinkTapCallback = void Function(Uri uri);

/// Renders WordPress post HTML as native Flutter widgets (no WebView).
///
/// Only a known set of elements is rendered. Scripts, styles, forms and
/// inline event handlers are dropped, embeds (iframes, video) become link
/// cards, and only http(s)/mailto/tel links are tappable. Unknown elements
/// fall back to their text content.
class ArticleHtml extends StatefulWidget {
  const ArticleHtml({
    super.key,
    required this.html,
    required this.baseUrl,
    required this.onLinkTap,
    this.textScale = 1.0,
  });

  final String html;
  final Uri baseUrl;
  final LinkTapCallback onLinkTap;
  final double textScale;

  @override
  State<ArticleHtml> createState() => _ArticleHtmlState();
}

class _ArticleHtmlState extends State<ArticleHtml> {
  late dom.DocumentFragment _fragment = html_parser.parseFragment(widget.html);
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void didUpdateWidget(ArticleHtml oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _fragment = html_parser.parseFragment(widget.html);
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final renderer = _Renderer(
      context: context,
      baseUrl: widget.baseUrl,
      scale: widget.textScale,
      onLinkTap: widget.onLinkTap,
      recognizers: _recognizers,
    );
    final blocks = renderer.blocks(_fragment.nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}

const _skipTags = {
  'script',
  'style',
  'noscript',
  'form',
  'input',
  'button',
  'select',
  'textarea',
  'svg',
  'canvas',
  'template',
  'head',
  'meta',
  'link',
  'object',
};

const _blockTags = {
  'p',
  'div',
  'section',
  'article',
  'header',
  'footer',
  'main',
  'aside',
  'figure',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'blockquote',
  'hr',
  'table',
  'pre',
  'img',
  'iframe',
  'video',
  'audio',
  'embed',
  'figcaption',
  'dl',
  'details',
  'center',
  'nav',
};

class _Renderer {
  _Renderer({
    required this.context,
    required this.baseUrl,
    required this.scale,
    required this.onLinkTap,
    required this.recognizers,
  });

  final BuildContext context;
  final Uri baseUrl;
  final double scale;
  final LinkTapCallback onLinkTap;
  final List<TapGestureRecognizer> recognizers;

  TextTheme get _text => context.text;
  BrandColors get _brand => context.brand;

  TextStyle get bodyStyle =>
      _text.bodyLarge!.copyWith(fontSize: 17 * scale, height: 1.72);

  // ---- Blocks --------------------------------------------------------

  List<Widget> blocks(List<dom.Node> nodes) {
    final out = <Widget>[];
    final inlineRun = <dom.Node>[];

    void flushInline() {
      if (inlineRun.isEmpty) return;
      final span = _inlineSpan(inlineRun, bodyStyle);
      inlineRun.clear();
      if (_isBlank(span)) return;
      out.add(_paragraph(span));
    }

    for (final node in nodes) {
      if (node is dom.Element && _skipTags.contains(node.localName)) continue;
      if (node is dom.Element && _blockTags.contains(node.localName)) {
        flushInline();
        out.addAll(_block(node));
      } else {
        inlineRun.add(node);
      }
    }
    flushInline();
    return out;
  }

  List<Widget> _block(dom.Element e) {
    switch (e.localName) {
      case 'p':
        if (_hasBlockChild(e)) return blocks(e.nodes);
        final span = _inlineSpan(e.nodes, bodyStyle);
        return _isBlank(span) ? const [] : [_paragraph(span)];
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        return [_heading(e)];
      case 'ul' || 'ol':
        return [_list(e, ordered: e.localName == 'ol', depth: 0)];
      case 'blockquote':
        return [_quote(e)];
      case 'hr':
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
        ];
      case 'figure':
        return _figure(e);
      case 'img':
        final image = _image(e);
        return image == null ? const [] : [_imageBlock(image, null)];
      case 'iframe' || 'video' || 'audio' || 'embed':
        final card = _embedCard(e);
        return card == null ? const [] : [card];
      case 'table':
        return [_table(e)];
      case 'pre':
        return [_pre(e)];
      case 'figcaption':
        return [_caption(e.text)];
      default:
        return blocks(e.nodes);
    }
  }

  Widget _paragraph(InlineSpan span) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Text.rich(span),
  );

  Widget _heading(dom.Element e) {
    final level = int.parse(e.localName!.substring(1));
    final base = switch (level) {
      1 || 2 => _text.headlineSmall!.copyWith(fontSize: 23 * scale),
      3 => _text.titleLarge!.copyWith(fontSize: 20 * scale),
      _ => _text.titleMedium!.copyWith(fontSize: 18 * scale),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Semantics(
        header: true,
        child: Text.rich(_inlineSpan(e.nodes, base)),
      ),
    );
  }

  Widget _list(dom.Element e, {required bool ordered, required int depth}) {
    final items = e.children.where((c) => c.localName == 'li').toList();
    final start = int.tryParse(e.attributes['start'] ?? '') ?? 1;
    return Padding(
      padding: EdgeInsets.only(bottom: depth == 0 ? 18 : 4, left: depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      ordered ? '${start + i}.' : '•',
                      style: bodyStyle.copyWith(
                        color: _brand.goldText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: _listItem(items[i], depth)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _listItem(dom.Element li, int depth) {
    final inline = <dom.Node>[];
    final nested = <Widget>[];
    for (final n in li.nodes) {
      if (n is dom.Element && (n.localName == 'ul' || n.localName == 'ol')) {
        nested.add(_list(n, ordered: n.localName == 'ol', depth: depth + 1));
      } else if (n is dom.Element && n.localName == 'p') {
        inline.addAll(n.nodes);
      } else {
        inline.add(n);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text.rich(_inlineSpan(inline, bodyStyle)), ...nested],
    );
  }

  Widget _quote(dom.Element e) {
    final cite = e.querySelector('cite');
    cite?.remove();
    final style = bodyStyle.copyWith(
      fontFamily: AppFonts.display,
      fontStyle: FontStyle.italic,
      fontSize: 19 * scale,
      height: 1.55,
    );
    final quoteNodes = e.children.where((c) => c.localName == 'p').toList();
    final spans = quoteNodes.isEmpty
        ? [_inlineSpan(e.nodes, style)]
        : [for (final p in quoteNodes) _inlineSpan(p.nodes, style)];
    return Container(
      margin: const EdgeInsets.only(bottom: 22, top: 4),
      padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _brand.gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in spans)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text.rich(s),
            ),
          if (cite != null && cite.text.trim().isNotEmpty)
            Text('— ${cite.text.trim()}', style: _text.bodySmall),
        ],
      ),
    );
  }

  List<Widget> _figure(dom.Element e) {
    final img = e.querySelector('img');
    final caption = e.querySelector('figcaption')?.text.trim();
    if (img != null) {
      final image = _image(img);
      if (image == null) return const [];
      final link = img.parent?.localName == 'a'
          ? _resolve(img.parent!.attributes['href'])
          : null;
      return [_imageBlock(image, caption, link: link)];
    }
    final table = e.querySelector('table');
    if (table != null) {
      return [
        _table(table),
        if (caption != null && caption.isNotEmpty) _caption(caption),
      ];
    }
    final embed = e.querySelector('iframe, video, audio, embed');
    if (embed != null) {
      final card = _embedCard(embed);
      return card == null ? const [] : [card];
    }
    // WordPress embed blocks without an iframe keep the URL as text.
    final url = _resolve(e.text.trim().split(RegExp(r'\s')).first);
    if (e.classes.contains('wp-block-embed') && url != null) {
      return [_linkCard(url, _embedLabel(url))];
    }
    return blocks(e.nodes);
  }

  MediaImage? _image(dom.Element img) {
    String? pick(String attr) {
      final v = img.attributes[attr];
      return v == null || v.isEmpty || v.startsWith('data:') ? null : v;
    }

    final src = pick('src') ?? pick('data-src') ?? pick('data-lazy-src');
    final srcset =
        pick('srcset') ?? pick('data-srcset') ?? pick('data-lazy-srcset');
    final variants = <ImageVariant>[];
    if (srcset != null) {
      for (final candidate in srcset.split(',')) {
        final parts = candidate.trim().split(RegExp(r'\s+'));
        final url = _resolve(parts.first);
        if (url == null || !url.isScheme('https') && !url.isScheme('http')) {
          continue;
        }
        final w = parts.length > 1 && parts[1].endsWith('w')
            ? int.tryParse(parts[1].replaceAll('w', ''))
            : null;
        variants.add(
          ImageVariant(url: url.toString(), width: w ?? 0, height: 0),
        );
      }
    }
    final srcUrl = _resolve(src);
    if (srcUrl != null &&
        (srcUrl.isScheme('https') || srcUrl.isScheme('http')) &&
        !variants.any((v) => v.url == srcUrl.toString())) {
      variants.add(
        ImageVariant(
          url: srcUrl.toString(),
          width: int.tryParse(img.attributes['width'] ?? '') ?? 0,
          height: int.tryParse(img.attributes['height'] ?? '') ?? 0,
        ),
      );
    }
    if (variants.isEmpty) return null;
    variants.sort(
      (a, b) =>
          a.width == 0 ? 1 : (b.width == 0 ? -1 : a.width.compareTo(b.width)),
    );
    final w = int.tryParse(img.attributes['width'] ?? '');
    final h = int.tryParse(img.attributes['height'] ?? '');
    // Keep the intrinsic aspect ratio from width/height attributes.
    if (w != null && h != null && w > 0 && h > 0) {
      for (var i = 0; i < variants.length; i++) {
        final v = variants[i];
        if (v.width > 0 && v.height == 0) {
          variants[i] = ImageVariant(
            url: v.url,
            width: v.width,
            height: (v.width * h / w).round(),
          );
        }
      }
      if (!variants.any((v) => v.height > 0)) {
        variants.add(ImageVariant(url: variants.last.url, width: w, height: h));
      }
    }
    return MediaImage(variants: variants, alt: img.attributes['alt'] ?? '');
  }

  Widget _imageBlock(MediaImage image, String? caption, {Uri? link}) {
    final ratio = (image.aspectRatio ?? 16 / 10).clamp(0.5, 2.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => link != null && !_isImageUrl(link)
                ? onLinkTap(link)
                : _openViewer(context, image),
            child: AppImage(
              image: image,
              aspectRatio: ratio.toDouble(),
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (caption != null && caption.isNotEmpty) _caption(caption),
        ],
      ),
    );
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Text(
      text,
      style: _text.bodySmall?.copyWith(
        fontSize: 13 * scale,
        fontStyle: FontStyle.italic,
      ),
    ),
  );

  Widget? _embedCard(dom.Element e) {
    final src =
        e.attributes['src'] ?? e.querySelector('source')?.attributes['src'];
    var url = _resolve(src);
    if (url == null) return null;
    // YouTube embeds → the watch page, which opens the YouTube app.
    final yt = RegExp(r'youtube(?:-nocookie)?\.com/embed/([\w-]+)')
        .firstMatch(url.toString());
    if (yt != null) {
      url = Uri.parse('https://www.youtube.com/watch?v=${yt.group(1)}');
    }
    return _linkCard(url, _embedLabel(url));
  }

  String _embedLabel(Uri url) {
    final host = url.host.replaceFirst('www.', '');
    if (host.contains('youtube') || host == 'youtu.be') {
      return 'Watch on YouTube';
    }
    if (host.contains('twitter') || host == 'x.com') return 'View post on X';
    if (host.contains('instagram')) return 'View on Instagram';
    if (host.contains('tiktok')) return 'Watch on TikTok';
    if (host.contains('spotify')) return 'Listen on Spotify';
    return 'Open $host';
  }

  Widget _linkCard(Uri url, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: _brand.goldSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onLinkTap(url),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline_rounded, color: _brand.goldText),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: _text.titleSmall)),
                Icon(Icons.open_in_new_rounded, size: 18, color: _brand.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();
    final cellStyle = bodyStyle.copyWith(fontSize: 14.5 * scale, height: 1.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _brand.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, row) in rows.indexed)
                Container(
                  color: i == 0 && row.querySelector('th') != null
                      ? _brand.goldSoft
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cell in row.children.where(
                        (c) => c.localName == 'td' || c.localName == 'th',
                      ))
                        Container(
                          width: 180,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _brand.border),
                            ),
                          ),
                          child: Text.rich(
                            _inlineSpan(
                              cell.nodes,
                              cell.localName == 'th'
                                  ? cellStyle.copyWith(
                                      fontWeight: FontWeight.w700,
                                    )
                                  : cellStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pre(dom.Element e) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _brand.skeleton,
      borderRadius: BorderRadius.circular(10),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        e.text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13.5 * scale,
          height: 1.5,
        ),
      ),
    ),
  );

  // ---- Inline --------------------------------------------------------

  InlineSpan _inlineSpan(List<dom.Node> nodes, TextStyle style) {
    final children = <InlineSpan>[];
    for (final n in nodes) {
      _inline(n, style, children);
    }
    _trimEdges(children);
    return TextSpan(style: style, children: children);
  }

  void _inline(dom.Node node, TextStyle style, List<InlineSpan> out) {
    if (node is dom.Text) {
      final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty) out.add(TextSpan(text: text));
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (_skipTags.contains(tag)) return;
    switch (tag) {
      case 'br':
        out.add(const TextSpan(text: '\n'));
        return;
      case 'img':
        return; // Inline images (emoji, icons) are dropped.
      case 'a':
        final url = _resolve(node.attributes['href']);
        final linkStyle = style.copyWith(
          color: _brand.goldText,
          decoration: TextDecoration.underline,
          decorationColor: _brand.goldText.withValues(alpha: 0.5),
        );
        if (url == null || !_isSafeLink(url)) {
          for (final c in node.nodes) {
            _inline(c, style, out);
          }
          return;
        }
        final recognizer = TapGestureRecognizer()..onTap = () => onLinkTap(url);
        recognizers.add(recognizer);
        final children = <InlineSpan>[];
        for (final c in node.nodes) {
          _inline(c, linkStyle, children);
        }
        out.add(
          TextSpan(
            style: linkStyle,
            recognizer: recognizer,
            children: _withRecognizer(children, recognizer),
          ),
        );
        return;
    }
    final next = switch (tag) {
      'strong' || 'b' => style.copyWith(
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
      ),
      'em' || 'i' || 'cite' => style.copyWith(fontStyle: FontStyle.italic),
      'u' || 'ins' => style.copyWith(decoration: TextDecoration.underline),
      's' ||
      'del' ||
      'strike' => style.copyWith(decoration: TextDecoration.lineThrough),
      'code' || 'kbd' => style.copyWith(
        fontFamily: 'monospace',
        backgroundColor: _brand.skeleton,
      ),
      'mark' => style.copyWith(backgroundColor: _brand.goldSoft),
      'sup' || 'sub' => style.copyWith(fontSize: (style.fontSize ?? 16) * 0.75),
      'small' => style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85),
      _ => style,
    };
    final children = <InlineSpan>[];
    for (final c in node.nodes) {
      _inline(c, next, children);
    }
    if (children.isNotEmpty) out.add(TextSpan(style: next, children: children));
  }

  /// Nested spans inside a link need the recognizer too, or taps on bold
  /// text inside the link do nothing.
  List<InlineSpan> _withRecognizer(
    List<InlineSpan> spans,
    TapGestureRecognizer r,
  ) => [
    for (final s in spans)
      if (s is TextSpan)
        TextSpan(
          text: s.text,
          style: s.style,
          recognizer: r,
          children: s.children == null ? null : _withRecognizer(s.children!, r),
        )
      else
        s,
  ];

  static void _trimEdges(List<InlineSpan> spans) {
    while (spans.isNotEmpty &&
        spans.first is TextSpan &&
        ((spans.first as TextSpan).text?.trim().isEmpty ?? false) &&
        (spans.first as TextSpan).children == null) {
      spans.removeAt(0);
    }
    if (spans.isNotEmpty && spans.first is TextSpan) {
      final f = spans.first as TextSpan;
      if (f.text != null && f.children == null) {
        spans[0] = TextSpan(
          text: f.text!.trimLeft(),
          style: f.style,
          recognizer: f.recognizer,
        );
      }
    }
    while (spans.isNotEmpty &&
        spans.last is TextSpan &&
        ((spans.last as TextSpan).text == '\n' ||
            ((spans.last as TextSpan).text?.trim().isEmpty ?? false) &&
                (spans.last as TextSpan).children == null)) {
      spans.removeLast();
    }
  }

  static bool _isBlank(InlineSpan span) =>
      span.toPlainText().replaceAll(' ', ' ').trim().isEmpty;

  static bool _hasBlockChild(dom.Element e) =>
      e.children.any(
        (c) => _blockTags.contains(c.localName) && c.localName != 'img',
      ) ||
      e.children.any((c) => c.localName == 'img' && e.text.trim().isEmpty);

  Uri? _resolve(String? href) {
    if (href == null) return null;
    final h = href.trim();
    if (h.isEmpty || h.startsWith('#')) return null;
    final uri = Uri.tryParse(h);
    if (uri == null) return null;
    return uri.hasScheme ? uri : baseUrl.resolveUri(uri);
  }

  static bool _isSafeLink(Uri uri) =>
      const {'http', 'https', 'mailto', 'tel'}.contains(uri.scheme);

  static bool _isImageUrl(Uri uri) => RegExp(
    r'\.(jpe?g|png|webp|gif|avif)$',
    caseSensitive: false,
  ).hasMatch(uri.path);
}

void _openViewer(BuildContext context, MediaImage image) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: const CloseButton(),
        ),
        body: InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: AppImage(image: image, fit: BoxFit.contain),
          ),
        ),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
