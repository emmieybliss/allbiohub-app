import type { MediaImage } from '@/models/types';

export function singleImage(url: string, alt = ''): MediaImage {
  return { variants: [{ url, w: 0, h: 0 }], alt, caption: '' };
}

/** Aspect ratio of the largest rendition with known size. */
export function aspectRatio(image: MediaImage): number | undefined {
  const known = image.variants.filter((v) => v.w > 0 && v.h > 0);
  const v = known[known.length - 1];
  return v ? v.w / v.h : undefined;
}

/**
 * The smallest rendition at least [physicalWidth] pixels wide, so cards
 * download medium/large files rather than the original upload. Cropped
 * thumbnails (different aspect ratio) are skipped unless [allowCropped].
 */
export function imageUrlFor(image: MediaImage, physicalWidth: number, allowCropped = false): string {
  const ratio = aspectRatio(image);
  for (const v of image.variants) {
    if (v.w === 0) continue;
    const cropped = ratio !== undefined && v.h > 0 && Math.abs(v.w / v.h - ratio) > 0.05;
    if (cropped && !allowCropped) continue;
    if (v.w >= physicalWidth) return v.url;
  }
  const sized = image.variants.filter((v) => v.w > 0);
  return (sized[sized.length - 1] ?? image.variants[image.variants.length - 1]).url;
}
