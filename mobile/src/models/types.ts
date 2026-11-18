export type ImageVariant = { url: string; w: number; h: number };

/** An image with every size WordPress generated, smallest first (unknown widths last). */
export type MediaImage = { variants: ImageVariant[]; alt: string; caption: string };

export type Author = { id: number; name: string; slug: string; avatarUrl?: string; description?: string };

export type TermKind = 'category' | 'tag';

export type Term = {
  id: number;
  name: string;
  slug: string;
  kind: TermKind;
  count: number;
  description: string;
  parentId: number;
};

export type Article = {
  id: number;
  slug: string;
  /** Canonical URL on allbiohub.com, used for sharing. */
  link: string;
  title: string;
  /** Plain-text summary. */
  excerpt: string;
  /** ISO date. */
  publishedAt: string;
  modifiedAt?: string;
  author?: Author;
  image?: MediaImage;
  categories: Term[];
  tags: Term[];
  categoryIds: number[];
  /** WordPress-rendered HTML; only on the reader. */
  contentHtml?: string;
  readingMinutes?: number;
  sticky: boolean;
  authorId: number;
  featuredMediaId: number;
  tagIds: number[];
};

export type Page<T> = {
  items: T[];
  page: number;
  totalPages?: number;
  total?: number;
  stale: boolean;
};

export function hasMore(page: Page<unknown>): boolean {
  if (page.totalPages !== undefined) return page.page < page.totalPages;
  return page.items.length > 0;
}

export type Founder = { name: string; role?: string; url?: string };

/** A startup from the directory. Only identity fields are required; the UI hides anything missing. */
export type Startup = {
  id: number;
  slug: string;
  name: string;
  link: string;
  tagline?: string;
  description?: string;
  logo?: MediaImage;
  industry?: string;
  country?: string;
  city?: string;
  founded?: number;
  stage?: string;
  funding?: string;
  businessModel?: string;
  employees?: string;
  status?: string;
  website?: string;
  social: Record<string, string>;
  founders: Founder[];
  products: string[];
  verified: boolean;
  claimed: boolean;
  featured: boolean;
  createdAt?: string;
  updatedAt?: string;
  verifiedAt?: string;
};

export type FilterOption = { value: string; label: string; count?: number };

export type StartupFilterOptions = {
  industries: FilterOption[];
  countries: FilterOption[];
  stages: FilterOption[];
  fundings: FilterOption[];
  businessModels: FilterOption[];
  employeeRanges: FilterOption[];
};

/** The website's sort options, in its order. The key is what the API expects. */
export const STARTUP_SORTS = [
  { key: 'newest', label: 'Recently added' },
  { key: 'updated', label: 'Recently updated' },
  { key: 'founded', label: 'Founded recently' },
  { key: 'oldest', label: 'Oldest' },
  { key: 'name', label: 'Alphabetical' },
  { key: 'featured', label: 'Featured first' },
  { key: 'verified', label: 'Verified first' },
] as const;

export type StartupSort = (typeof STARTUP_SORTS)[number]['key'];

export type StartupQuery = {
  search?: string;
  industry?: string;
  country?: string;
  city?: string;
  stage?: string;
  funding?: string;
  businessModel?: string;
  employees?: string;
  foundedFrom?: number;
  foundedTo?: number;
  verified?: boolean;
  claimed?: boolean;
  featured?: boolean;
  sort?: StartupSort;
};
