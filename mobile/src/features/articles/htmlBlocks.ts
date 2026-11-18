import { parseDocument } from 'htmlparser2';
import type { ChildNode, Element } from 'domhandler';
import type { MediaImage } from '@/models/types';

/**
 * Turns WordPress-rendered story HTML into a small block model that the
 * reader draws with native views. No WebView: only a whitelist of elements
 * is kept. Scripts, styles and forms are dropped; iframes and videos become
 * link cards (YouTube opens the YouTube app); lazy-load placeholders
 * (data: src) are replaced with data-src; only http(s), mailto and tel links
 * are tappable.
 */
export type Inline = {
  text: string;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strike?: boolean;
  code?: boolean;
  href?: string;
};

export type Block =
  | { type: 'paragraph'; spans: Inline[] }
  | { type: 'heading'; level: number; spans: Inline[] }
  | { type: 'list'; ordered: boolean; items: Block[][] }
  | { type: 'quote'; blocks: Block[] }
  | { type: 'rule' }
  | { type: 'image'; image: MediaImage; href?: string }
  | { type: 'caption'; spans: Inline[] }
  | { type: 'embed'; url: string; kind: 'youtube' | 'video' | 'link'; label: string }
  | { type: 'table'; rows: Inline[][][] }
  | { type: 'code'; text: string };

const DROP = new Set([
  'script', 'style', 'noscript', 'form', 'input', 'button', 'select', 'textarea', 'svg', 'canvas', 'template', 'head', 'meta', 'link', 'object',
]);

const BLOCK = new Set([
  'p', 'div', 'section', 'article', 'header', 'footer', 'main', 'aside', 'figure', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li',
  'blockquote', 'hr', 'table', 'pre', 'img', 'iframe', 'video', 'audio', 'embed', 'figcaption', 'dl', 'details', 'center', 'nav',
]);

type Style = Omit<Inline, 'text'>;

const isElement = (n: ChildNode): n is Element => n.type === 'tag' || n.type === 'script' || n.type === 'style';

function safeHref(raw?: string): string | undefined {
  if (!raw) return undefined;
  const href = raw.trim();
  if (/^(https?:|mailto:|tel:)/i.test(href)) return href;
  if (href.startsWith('/') && !href.startsWith('//')) return href; // site-relative, resolved by openLink
  return undefined;
}

function textOf(node: ChildNode): string {
  if (node.type === 'text') return node.data;
  if (isElement(node)) return node.children.map(textOf).join('');
  return '';
}

function inlineStyle(el: Element, style: Style): Style {
  switch (el.name) {
    case 'strong':
    case 'b':
      return { ...style, bold: true };
    case 'em':
    case 'i':
    case 'cite':
      return { ...style, italic: true };
    case 'u':
    case 'ins':
      return { ...style, underline: true };
    case 's':
    case 'del':
    case 'strike':
      return { ...style, strike: true };
    case 'code':
    case 'kbd':
      return { ...style, code: true };
    case 'a': {
      const href = safeHref(el.attribs.href);
      return href ? { ...style, href } : style;
    }
    default:
      return style;
  }
}

function attr(el: Element, ...names: string[]): string | undefined {
  for (const n of names) {
    const v = el.attribs[n];
    if (v && !v.startsWith('data:')) return v;
  }
  return undefined;
}

export function imageFrom(el: Element): MediaImage | undefined {
  const src = attr(el, 'src', 'data-src', 'data-lazy-src');
  const srcset = attr(el, 'srcset', 'data-srcset', 'data-lazy-srcset');
  const variants: MediaImage['variants'] = [];
  if (srcset) {
    for (const candidate of srcset.split(',')) {
      const [url, size] = candidate.trim().split(/\s+/);
      if (!url || url.startsWith('data:')) continue;
      const w = size?.endsWith('w') ? parseInt(size, 10) : 0;
      variants.push({ url, w: Number.isFinite(w) ? w : 0, h: 0 });
    }
  }
  const w = parseInt(el.attribs.width ?? '', 10);
  const h = parseInt(el.attribs.height ?? '', 10);
  if (src && !variants.some((v) => v.url === src)) variants.push({ url: src, w: Number.isFinite(w) ? w : 0, h: 0 });
  if (!variants.length) return undefined;
  // Width and height attributes give the aspect ratio for every rendition.
  if (Number.isFinite(w) && Number.isFinite(h) && w > 0 && h > 0) {
    for (const v of variants) v.h = v.w > 0 ? Math.round((v.w * h) / w) : 0;
  }
  variants.sort((a, b) => (a.w === 0 ? 1 : b.w === 0 ? -1 : a.w - b.w));
  return { variants, alt: el.attribs.alt ?? '', caption: '' };
}

export function embedFor(src: string): Block | undefined {
  let url = src.trim();
  if (url.startsWith('//')) url = `https:${url}`;
  if (!/^https?:/i.test(url)) return undefined;
  const yt = /youtube(?:-nocookie)?\.com\/embed\/([\w-]+)/.exec(url);
  if (yt) return { type: 'embed', url: `https://www.youtube.com/watch?v=${yt[1]}`, kind: 'youtube', label: 'Watch on YouTube' };
  let host = '';
  try {
    host = new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return undefined;
  }
  if (host.includes('youtube') || host === 'youtu.be') return { type: 'embed', url, kind: 'youtube', label: 'Watch on YouTube' };
  if (/\.(mp4|webm|m3u8|mov)(\?|$)/i.test(url)) return { type: 'embed', url, kind: 'video', label: 'Play video' };
  return { type: 'embed', url, kind: 'link', label: `Open on ${host}` };
}

class Builder {
  blocks: Block[] = [];
  private spans: Inline[] = [];

  push(span: Inline) {
    const prev = this.spans[this.spans.length - 1];
    if (prev && sameStyle(prev, span)) prev.text += span.text;
    else this.spans.push({ ...span });
  }

  flush(kind: 'paragraph' | 'caption' = 'paragraph') {
    const spans = trimSpans(this.spans);
    this.spans = [];
    if (spans.length) this.blocks.push({ type: kind, spans });
  }

  takeSpans(): Inline[] {
    const spans = trimSpans(this.spans);
    this.spans = [];
    return spans;
  }
}

function sameStyle(a: Inline, b: Inline) {
  return a.bold === b.bold && a.italic === b.italic && a.underline === b.underline && a.strike === b.strike && a.code === b.code && a.href === b.href;
}

function trimSpans(spans: Inline[]): Inline[] {
  const out = spans.map((s) => ({ ...s, text: s.text.replace(/[ \t\r\f\v]+/g, ' ').replace(/ ?\n ?/g, '\n') }));
  while (out.length && !out[0].text.trim()) out.shift();
  while (out.length && !out[out.length - 1].text.trim()) out.pop();
  if (!out.length) return out;
  out[0].text = out[0].text.replace(/^\s+/, '');
  out[out.length - 1].text = out[out.length - 1].text.replace(/\s+$/, '');
  return out.filter((s) => s.text.length);
}

function inlines(nodes: ChildNode[], style: Style, b: Builder) {
  for (const n of nodes) {
    if (n.type === 'text') {
      b.push({ ...style, text: n.data.replace(/\s+/g, ' ') });
    } else if (isElement(n)) {
      if (DROP.has(n.name)) continue;
      if (n.name === 'br') b.push({ ...style, text: '\n' });
      else inlines(n.children, inlineStyle(n, style), b);
    }
  }
}

function spansOf(nodes: ChildNode[]): Inline[] {
  const b = new Builder();
  inlines(nodes, {}, b);
  return b.takeSpans();
}

function walk(nodes: ChildNode[], b: Builder, style: Style = {}) {
  for (const n of nodes) {
    if (n.type === 'text') {
      b.push({ ...style, text: n.data.replace(/\s+/g, ' ') });
      continue;
    }
    if (!isElement(n) || DROP.has(n.name)) continue;
    if (!BLOCK.has(n.name)) {
      if (n.name === 'br') b.push({ ...style, text: '\n' });
      else if (n.name === 'a' && n.children.some((c) => isElement(c) && c.name === 'img')) {
        b.flush();
        const img = n.children.find((c): c is Element => isElement(c) && c.name === 'img');
        const image = img && imageFrom(img);
        if (image) b.blocks.push({ type: 'image', image, href: safeHref(n.attribs.href) });
      } else {
        // Inline element that may contain blocks (WordPress sometimes nests them).
        const hasBlock = n.children.some((c) => isElement(c) && BLOCK.has(c.name));
        if (hasBlock) walk(n.children, b, inlineStyle(n, style));
        else inlines(n.children, inlineStyle(n, style), b);
      }
      continue;
    }
    b.flush();
    block(n, b);
  }
}

function block(el: Element, b: Builder) {
  switch (el.name) {
    case 'p':
    case 'center': {
      walk(el.children, b);
      b.flush();
      return;
    }
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6': {
      const spans = spansOf(el.children);
      if (spans.length) b.blocks.push({ type: 'heading', level: Number(el.name[1]), spans });
      return;
    }
    case 'ul':
    case 'ol': {
      const items: Block[][] = [];
      for (const li of el.children) {
        if (!isElement(li) || li.name !== 'li') continue;
        const inner = new Builder();
        walk(li.children, inner);
        inner.flush();
        if (inner.blocks.length) items.push(inner.blocks);
      }
      if (items.length) b.blocks.push({ type: 'list', ordered: el.name === 'ol', items });
      return;
    }
    case 'li': {
      walk(el.children, b);
      b.flush();
      return;
    }
    case 'blockquote': {
      const inner = new Builder();
      walk(el.children, inner);
      inner.flush();
      if (inner.blocks.length) b.blocks.push({ type: 'quote', blocks: inner.blocks });
      return;
    }
    case 'hr':
      b.blocks.push({ type: 'rule' });
      return;
    case 'img': {
      const image = imageFrom(el);
      if (image) b.blocks.push({ type: 'image', image });
      return;
    }
    case 'figcaption': {
      const spans = spansOf(el.children);
      if (spans.length) b.blocks.push({ type: 'caption', spans });
      return;
    }
    case 'iframe':
    case 'embed': {
      const e = embedFor(el.attribs.src ?? el.attribs['data-src'] ?? '');
      if (e) b.blocks.push(e);
      return;
    }
    case 'video':
    case 'audio': {
      const source = el.attribs.src ?? el.children.filter(isElement).find((c) => c.name === 'source')?.attribs.src;
      const e = source ? embedFor(source) : undefined;
      if (e) b.blocks.push(e.type === 'embed' && e.kind === 'link' ? { ...e, kind: 'video', label: el.name === 'audio' ? 'Play audio' : 'Play video' } : e);
      return;
    }
    case 'table': {
      const rows: Inline[][][] = [];
      const collect = (nodes: ChildNode[]) => {
        for (const n of nodes) {
          if (!isElement(n)) continue;
          if (n.name === 'tr') {
            const cells = n.children.filter((c): c is Element => isElement(c) && (c.name === 'td' || c.name === 'th')).map((c) => spansOf(c.children));
            if (cells.length) rows.push(cells);
          } else if (['thead', 'tbody', 'tfoot'].includes(n.name)) collect(n.children);
        }
      };
      collect(el.children);
      if (rows.length) b.blocks.push({ type: 'table', rows });
      return;
    }
    case 'pre': {
      const text = textOf(el).replace(/\s+$/, '');
      if (text) b.blocks.push({ type: 'code', text });
      return;
    }
    default: {
      // Containers (div, figure, section...): their children decide.
      walk(el.children, b);
      b.flush();
    }
  }
}

export function parseStoryHtml(html: string): Block[] {
  const doc = parseDocument(html, { decodeEntities: true, lowerCaseTags: true });
  const b = new Builder();
  walk(doc.children, b);
  b.flush();
  return b.blocks;
}
