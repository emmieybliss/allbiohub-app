import type { Article, MediaImage, Term } from '@/models/types';

/**
 * Saved stories are copied to the account as JSON in the shape the Flutter
 * app wrote (lib/core/models/article.dart, Article.toJson), so a story saved
 * in either version of the app shows up in the other.
 */
type Json = Record<string, unknown>;

function imageToJson(image?: MediaImage) {
  return image ? { v: image.variants.map((v) => ({ url: v.url, w: v.w, h: v.h })), alt: image.alt, cap: image.caption } : null;
}

function termToJson(t: Term) {
  return { id: t.id, name: t.name, slug: t.slug, kind: t.kind, count: t.count, description: t.description, parent: t.parentId };
}

export function articleToSyncJson(a: Article): Json {
  return {
    id: a.id,
    slug: a.slug,
    link: a.link,
    title: a.title,
    excerpt: a.excerpt,
    published: a.publishedAt,
    modified: a.modifiedAt ?? null,
    author: a.author ? { id: a.author.id, name: a.author.name, slug: a.author.slug, avatar: a.author.avatarUrl ?? null } : null,
    image: imageToJson(a.image),
    categories: a.categories.map(termToJson),
    tags: a.tags.map(termToJson),
    categoryIds: a.categoryIds,
    readingMinutes: a.readingMinutes ?? null,
    sticky: a.sticky,
  };
}

const num = (v: unknown) => (typeof v === 'number' ? v : 0);
const str = (v: unknown) => (typeof v === 'string' ? v : '');

function termFromJson(j: Json, kind: 'category' | 'tag'): Term {
  return {
    id: num(j.id),
    name: str(j.name),
    slug: str(j.slug),
    kind: j.kind === 'tag' || j.kind === 'category' ? j.kind : kind,
    count: num(j.count),
    description: str(j.description),
    parentId: num(j.parent),
  };
}

/** Reads a saved story from the account (a JSON string or object); null when it can't be read. */
export function articleFromSyncJson(raw: unknown): Article | null {
  let j: Json;
  try {
    j = (typeof raw === 'string' ? JSON.parse(raw) : raw) as Json;
  } catch {
    return null;
  }
  if (!j || typeof j !== 'object' || typeof j.id !== 'number' || !str(j.slug) || !str(j.published)) return null;
  const img = j.image as Json | null;
  const author = j.author as Json | null;
  const categories = Array.isArray(j.categories) ? (j.categories as Json[]).map((c) => termFromJson(c, 'category')) : [];
  const tags = Array.isArray(j.tags) ? (j.tags as Json[]).map((c) => termFromJson(c, 'tag')) : [];
  return {
    id: j.id,
    slug: str(j.slug),
    link: str(j.link),
    title: str(j.title),
    excerpt: str(j.excerpt),
    publishedAt: str(j.published),
    modifiedAt: str(j.modified) || undefined,
    author: author ? { id: num(author.id), name: str(author.name), slug: str(author.slug), avatarUrl: str(author.avatar) || undefined } : undefined,
    image:
      img && Array.isArray(img.v) && img.v.length
        ? { variants: (img.v as Json[]).map((v) => ({ url: str(v.url), w: num(v.w), h: num(v.h) })), alt: str(img.alt), caption: str(img.cap) }
        : undefined,
    categories,
    tags,
    categoryIds: Array.isArray(j.categoryIds) ? (j.categoryIds as unknown[]).filter((n): n is number => typeof n === 'number') : categories.map((c) => c.id),
    readingMinutes: typeof j.readingMinutes === 'number' ? j.readingMinutes : undefined,
    sticky: j.sticky === true,
    authorId: author ? num(author.id) : 0,
    featuredMediaId: 0,
    tagIds: tags.map((t) => t.id),
  };
}
