import type { Article, Author, MediaImage, Term, TermKind } from '@/models/types';
import { estimateReadingMinutes, htmlToPlainText } from '@/lib/text';
import { singleImage } from '@/lib/images';

/**
 * WordPress REST JSON (/wp/v2/...) to app models. Tolerant of missing and
 * malformed embeds: WordPress puts error objects in _embedded when an author
 * or image is private or deleted, and the live site ignores _embed entirely.
 */
type Json = Record<string, unknown>;

const isObj = (v: unknown): v is Json => typeof v === 'object' && v !== null && !Array.isArray(v);
const num = (v: unknown): number | undefined => (typeof v === 'number' && Number.isFinite(v) ? v : undefined);

function rendered(field: unknown): string {
  if (typeof field === 'string') return field;
  if (isObj(field) && typeof field.rendered === 'string') return field.rendered;
  return '';
}

/** date_gmt has no zone designator; treat it as UTC. */
function isoDate(value: unknown): string {
  const s = String(value);
  const withZone = /Z$|[+-]\d\d:?\d\d$/.test(s) ? s : `${s}Z`;
  const d = new Date(withZone);
  return Number.isNaN(d.getTime()) ? new Date(0).toISOString() : d.toISOString();
}

export function mapTerm(json: Json, kind?: TermKind): Term {
  return {
    id: json.id as number,
    name: htmlToPlainText(String(json.name ?? '')),
    slug: String(json.slug ?? ''),
    kind: kind ?? (json.taxonomy === 'post_tag' ? 'tag' : 'category'),
    count: num(json.count) ?? 0,
    description: htmlToPlainText(typeof json.description === 'string' ? json.description : ''),
    parentId: num(json.parent) ?? 0,
  };
}

export function mapMedia(json: Json): MediaImage | undefined {
  const details = isObj(json.media_details) ? json.media_details : undefined;
  const variants: MediaImage['variants'] = [];
  const sizes = details && isObj(details.sizes) ? details.sizes : undefined;
  if (sizes) {
    for (const s of Object.values(sizes)) {
      if (isObj(s) && typeof s.source_url === 'string') {
        variants.push({ url: s.source_url, w: num(s.width) ?? 0, h: num(s.height) ?? 0 });
      }
    }
  }
  const source = json.source_url;
  if (typeof source === 'string' && !variants.some((v) => v.url === source)) {
    variants.push({ url: source, w: num(details?.width) ?? 0, h: num(details?.height) ?? 0 });
  }
  if (!variants.length) return undefined;
  variants.sort((a, b) => (a.w === 0 ? 1 : b.w === 0 ? -1 : a.w - b.w));
  return {
    variants,
    alt: typeof json.alt_text === 'string' ? json.alt_text : '',
    caption: htmlToPlainText(rendered(json.caption)),
  };
}

/** A /wp/v2/users item, or undefined for an error object. */
export function mapAuthor(a: unknown): Author | undefined {
  if (!isObj(a) || typeof a.id !== 'number' || typeof a.name !== 'string') return undefined;
  let avatarUrl: string | undefined;
  if (isObj(a.avatar_urls)) {
    const urls = a.avatar_urls as Record<string, string>;
    avatarUrl = urls['96'] ?? Object.values(urls).pop();
  }
  return {
    id: a.id,
    name: htmlToPlainText(a.name),
    slug: typeof a.slug === 'string' ? a.slug : '',
    avatarUrl,
    description: typeof a.description === 'string' ? htmlToPlainText(a.description) || undefined : undefined,
  };
}

export function mapArticle(json: Json): Article {
  if (typeof json.id !== 'number' || typeof json.slug !== 'string') throw new Error('Not a post');
  const embedded = isObj(json._embedded) ? json._embedded : {};
  const content = rendered(json.content);

  const terms: Term[] = [];
  const termGroups = embedded['wp:term'];
  if (Array.isArray(termGroups)) {
    for (const group of termGroups) {
      if (!Array.isArray(group)) continue;
      for (const t of group) if (isObj(t) && typeof t.id === 'number') terms.push(mapTerm(t));
    }
  }
  const categoryIds = (Array.isArray(json.categories) ? json.categories : []).filter((v): v is number => typeof v === 'number');
  const indexOf = (id: number) => {
    const i = categoryIds.indexOf(id);
    return i < 0 ? categoryIds.length : i;
  };
  // WordPress embeds categories alphabetically; keep the post's own order so the primary comes first.
  const categories = terms.filter((t) => t.kind === 'category').sort((a, b) => indexOf(a.id) - indexOf(b.id));

  const authorEmbed = Array.isArray(embedded.author) ? embedded.author[0] : undefined;
  const mediaEmbed = Array.isArray(embedded['wp:featuredmedia']) ? embedded['wp:featuredmedia'][0] : undefined;
  const featured = isObj(mediaEmbed) && mediaEmbed.code === undefined ? mapMedia(mediaEmbed) : undefined;
  const fallback =
    typeof json.jetpack_featured_media_url === 'string' && json.jetpack_featured_media_url
      ? singleImage(json.jetpack_featured_media_url)
      : undefined;

  return {
    id: json.id,
    slug: json.slug,
    link: String(json.link ?? ''),
    title: htmlToPlainText(rendered(json.title)),
    excerpt: htmlToPlainText(rendered(json.excerpt)),
    publishedAt: isoDate(json.date_gmt ?? json.date),
    modifiedAt: json.modified_gmt ?? json.modified ? isoDate(json.modified_gmt ?? json.modified) : undefined,
    author: mapAuthor(authorEmbed),
    image: featured ?? fallback,
    categories,
    tags: terms.filter((t) => t.kind === 'tag'),
    categoryIds,
    contentHtml: content || undefined,
    readingMinutes: content ? estimateReadingMinutes(content) : undefined,
    sticky: json.sticky === true,
    authorId: num(json.author) ?? 0,
    featuredMediaId: num(json.featured_media) ?? 0,
    tagIds: (Array.isArray(json.tags) ? json.tags : []).filter((v): v is number => typeof v === 'number'),
  };
}

/** Maps a list, skipping a single malformed post rather than failing the list. */
export function mapArticles(data: unknown): Article[] {
  if (!Array.isArray(data)) throw new Error('Expected a list of posts');
  const result: Article[] = [];
  for (const item of data) {
    if (!isObj(item)) continue;
    try {
      result.push(mapArticle(item));
    } catch {
      // skip
    }
  }
  return result;
}
