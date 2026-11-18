import { embedFor, parseStoryHtml } from '@/features/articles/htmlBlocks';

it('keeps paragraphs, headings and inline styles', () => {
  const blocks = parseStoryHtml('<h2>Early life</h2><p>Born in <strong>Lagos</strong>, she <em>moved</em> to <a href="https://allbiohub.com/x/">Abuja</a>.</p>');
  expect(blocks[0]).toEqual({ type: 'heading', level: 2, spans: [{ text: 'Early life' }] });
  expect(blocks[1]).toEqual({
    type: 'paragraph',
    spans: [{ text: 'Born in ' }, { text: 'Lagos', bold: true }, { text: ', she ' }, { text: 'moved', italic: true }, { text: ' to ' }, { text: 'Abuja', href: 'https://allbiohub.com/x/' }, { text: '.' }],
  });
});

it('drops scripts, styles and forms', () => {
  const blocks = parseStoryHtml('<p>Hi</p><script>alert(1)</script><style>p{}</style><form><input/><button>Go</button></form>');
  expect(blocks).toEqual([{ type: 'paragraph', spans: [{ text: 'Hi' }] }]);
});

it('makes only safe links tappable', () => {
  const blocks = parseStoryHtml('<p><a href="javascript:alert(1)">bad</a> <a href="mailto:a@b.c">mail</a></p>');
  expect(blocks[0]).toEqual({ type: 'paragraph', spans: [{ text: 'bad ' }, { text: 'mail', href: 'mailto:a@b.c' }] });
});

it('uses data-src for lazy-loaded images and reads srcset', () => {
  const [img, caption] = parseStoryHtml(
    '<figure><img src="data:image/gif;base64,R0l" data-src="https://x/full.jpg" data-srcset="https://x/300.jpg 300w, https://x/1024.jpg 1024w" width="2048" height="1024" alt="A"><figcaption>Photo: AllBioHub</figcaption></figure>',
  );
  expect(img).toMatchObject({ type: 'image', image: { alt: 'A' } });
  if (img.type !== 'image') throw new Error();
  expect(img.image.variants.map((v) => v.url)).toEqual(['https://x/300.jpg', 'https://x/1024.jpg', 'https://x/full.jpg']);
  expect(img.image.variants[0].h).toBe(150);
  expect(caption).toEqual({ type: 'caption', spans: [{ text: 'Photo: AllBioHub' }] });
});

it('turns embeds into link cards', () => {
  expect(parseStoryHtml('<iframe src="https://www.youtube.com/embed/abc_123?rel=0"></iframe>')).toEqual([
    { type: 'embed', url: 'https://www.youtube.com/watch?v=abc_123', kind: 'youtube', label: 'Watch on YouTube' },
  ]);
  expect(embedFor('//player.vimeo.com/video/1')).toMatchObject({ kind: 'link', label: 'Open on player.vimeo.com' });
  expect(embedFor('javascript:x')).toBeUndefined();
});

it('parses nested lists, quotes and tables', () => {
  const [list, quote, table] = parseStoryHtml(
    '<ul><li>One</li><li>Two<ul><li>Inner</li></ul></li></ul><blockquote><p>Quote</p></blockquote><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>',
  );
  expect(list).toMatchObject({ type: 'list', ordered: false, items: [[{ type: 'paragraph' }], [{ type: 'paragraph' }, { type: 'list' }]] });
  expect(quote).toEqual({ type: 'quote', blocks: [{ type: 'paragraph', spans: [{ text: 'Quote' }] }] });
  expect(table).toEqual({ type: 'table', rows: [[[{ text: 'A' }], [{ text: 'B' }]], [[{ text: '1' }], [{ text: '2' }]]] });
});

it('handles line breaks and stray text', () => {
  expect(parseStoryHtml('Intro text<p>Line one<br>Line two</p>')).toEqual([
    { type: 'paragraph', spans: [{ text: 'Intro text' }] },
    { type: 'paragraph', spans: [{ text: 'Line one\nLine two' }] },
  ]);
});
