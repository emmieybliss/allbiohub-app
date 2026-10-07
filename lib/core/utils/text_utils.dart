import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

/// Turns WordPress-rendered HTML (titles, excerpts) into plain text, decoding
/// entities such as `&#8217;` and `&amp;`.
String htmlToPlainText(String? html) {
  if (html == null || html.isEmpty) return '';
  final text = html_parser.parseFragment(html).text ?? '';
  return text
      .replaceAll(RegExp(r'\s*\[(?:&hellip;|…|\.\.\.)\]\s*$'), '…')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Estimated minutes to read [html] at 220 words per minute (minimum 1).
int estimateReadingMinutes(String html) {
  final words = htmlToPlainText(html)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .length;
  return (words / 220).ceil().clamp(1, 999);
}

/// "Just now", "5 min ago", "3 h ago", "Yesterday", "2 days ago", then a date.
String relativeDate(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return fullDate(date, now: current);
}

String fullDate(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return DateFormat(date.year == current.year ? 'd MMM' : 'd MMM yyyy')
      .format(date);
}

const _accents = {
  'a': 'àáâãäåāăąạ',
  'c': 'çćč',
  'd': 'ďđ',
  'e': 'èéêëēėęěẹ',
  'i': 'ìíîïīįị',
  'n': 'ñńňṅ',
  'o': 'òóôõöøōọ',
  'r': 'ŕř',
  's': 'śšşṣ',
  't': 'ťţ',
  'u': 'ùúûüūůűụ',
  'y': 'ýÿ',
  'z': 'źżž',
};

/// Slug used as a founder's id: "Tosin Eniolorunda" → "tosin-eniolorunda".
/// Must match `slugify` in firebase/functions/src/validation.ts, which
/// checks it.
String slugify(String input) {
  var s = input
      .toLowerCase()
      .replaceAll(RegExp('[̀-ͯ]'), '')
      .replaceAll('ß', 'ss');
  for (final e in _accents.entries) {
    s = s.replaceAll(RegExp('[${e.value}]'), e.key);
  }
  s = s
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.length > 80 ? s.substring(0, 80) : s;
}
