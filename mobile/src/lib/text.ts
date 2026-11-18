import { decodeHTML } from 'entities';

/**
 * WordPress-rendered HTML (titles, excerpts) to plain text, decoding entities
 * such as &#8217; and &amp;.
 */
export function htmlToPlainText(html?: string | null): string {
  if (!html) return '';
  const text = decodeHTML(
    html
      .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, ' ')
      .replace(/<br\s*\/?>/gi, ' ')
      .replace(/<\/(p|div|li|h[1-6])>/gi, ' ')
      .replace(/<[^>]+>/g, ''),
  );
  return text
    .replace(/\s*\[(?:…|\.\.\.)\]\s*$/, '…')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Estimated minutes to read at 220 words per minute (minimum 1). */
export function estimateReadingMinutes(html: string): number {
  const words = htmlToPlainText(html).split(' ').filter(Boolean).length;
  return Math.min(999, Math.max(1, Math.ceil(words / 220)));
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function fullDate(iso: string, now: Date = new Date()): string {
  const d = new Date(iso);
  const day = `${d.getDate()} ${MONTHS[d.getMonth()]}`;
  return d.getFullYear() === now.getFullYear() ? day : `${day} ${d.getFullYear()}`;
}

/** "Just now", "5 min ago", "3 h ago", "Yesterday", "2 days ago", then a date. */
export function relativeDate(iso: string, now: Date = new Date()): string {
  const diff = now.getTime() - new Date(iso).getTime();
  const minutes = Math.floor(diff / 60_000);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes} min ago`;
  if (hours < 24) return `${hours} h ago`;
  if (days === 1) return 'Yesterday';
  if (days < 7) return `${days} days ago`;
  return fullDate(iso, now);
}

export function compactNumber(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n >= 10_000_000 ? 0 : 1).replace(/\.0$/, '')}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(n >= 10_000 ? 0 : 1).replace(/\.0$/, '')}K`;
  return String(n);
}

export function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
