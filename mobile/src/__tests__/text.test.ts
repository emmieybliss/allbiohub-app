import { compactNumber, estimateReadingMinutes, fullDate, htmlToPlainText, relativeDate } from '@/lib/text';

it('turns HTML into plain text', () => {
  expect(htmlToPlainText('<p>Tom &amp; Jerry&#8217;s <b>show</b></p><script>x()</script>')).toBe('Tom & Jerry’s show');
  expect(htmlToPlainText('Read more [&hellip;]')).toBe('Read more…');
  expect(htmlToPlainText(undefined)).toBe('');
});

it('estimates reading time', () => {
  expect(estimateReadingMinutes('<p>one two</p>')).toBe(1);
  expect(estimateReadingMinutes('w '.repeat(660))).toBe(3);
});

it('formats dates like the Flutter app', () => {
  const now = new Date('2026-11-18T12:00:00Z');
  expect(relativeDate('2026-11-18T11:59:40Z', now)).toBe('Just now');
  expect(relativeDate('2026-11-18T11:55:00Z', now)).toBe('5 min ago');
  expect(relativeDate('2026-11-18T09:00:00Z', now)).toBe('3 h ago');
  expect(relativeDate('2026-11-17T10:00:00Z', now)).toBe('Yesterday');
  expect(relativeDate('2026-11-15T10:00:00Z', now)).toBe('3 days ago');
  expect(fullDate('2026-03-04T10:00:00Z', now)).toBe('4 Mar');
  expect(fullDate('2025-03-04T10:00:00Z', now)).toBe('4 Mar 2025');
});

it('shortens numbers', () => {
  expect(compactNumber(950)).toBe('950');
  expect(compactNumber(1200)).toBe('1.2K');
  expect(compactNumber(25_000)).toBe('25K');
});
