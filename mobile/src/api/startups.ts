import { env } from '@/config/env';
import { singleImage } from '@/lib/images';
import type { FilterOption, Founder, MediaImage, Page, Startup, StartupFilterOptions, StartupQuery } from '@/models/types';
import { AppError, StartupDirectoryUnavailable } from './errors';
import { getJson, HOURS, MINUTES, type Query } from './http';

type Json = Record<string, unknown>;

function str(json: Json, key: string): string | undefined {
  const v = json[key];
  if (v === null || v === undefined) return undefined;
  const s = String(v).trim();
  return s || undefined;
}

function mediaFromJson(v: unknown): MediaImage | undefined {
  if (typeof v === 'string') return v ? singleImage(v) : undefined;
  if (typeof v === 'object' && v !== null) {
    const m = v as Json;
    if (Array.isArray(m.v)) return { variants: m.v as MediaImage['variants'], alt: String(m.alt ?? ''), caption: String(m.cap ?? '') };
    if (typeof m.source_url === 'string') return singleImage(m.source_url, String(m.alt_text ?? ''));
    if (typeof m.url === 'string') return singleImage(m.url);
  }
  return undefined;
}

export function mapStartup(json: Json): Startup {
  if (typeof json.id !== 'number' || typeof json.slug !== 'string' || typeof json.name !== 'string') {
    throw new Error('Not a startup');
  }
  const founded = typeof json.founded === 'number' ? json.founded : parseInt(str(json, 'founded') ?? '', 10);
  const social: Record<string, string> = {};
  if (typeof json.social === 'object' && json.social !== null) {
    for (const [k, v] of Object.entries(json.social as Json)) if (typeof v === 'string' && v) social[k] = v;
  }
  const founders: Founder[] = Array.isArray(json.founders)
    ? json.founders
        .filter((f): f is Json => typeof f === 'object' && f !== null && typeof (f as Json).name === 'string')
        .map((f) => ({ name: f.name as string, role: str(f, 'role'), url: str(f, 'url') }))
    : [];
  return {
    id: json.id,
    slug: json.slug,
    name: json.name,
    link: String(json.link ?? `${env.siteUrl}/startups/${json.slug}/`),
    tagline: str(json, 'tagline'),
    description: str(json, 'description'),
    logo: mediaFromJson(json.logo),
    industry: str(json, 'industry'),
    country: str(json, 'country'),
    city: str(json, 'city'),
    founded: Number.isFinite(founded) ? founded : undefined,
    stage: str(json, 'stage'),
    funding: str(json, 'funding'),
    businessModel: str(json, 'business_model'),
    employees: str(json, 'employees'),
    status: str(json, 'status'),
    website: str(json, 'website'),
    social,
    founders,
    products: Array.isArray(json.products) ? json.products.map(String) : [],
    // Badges show only when the database says exactly true.
    verified: json.verified === true,
    claimed: json.claimed === true,
    featured: json.featured === true,
    createdAt: str(json, 'created_at'),
    updatedAt: str(json, 'updated_at'),
    verifiedAt: str(json, 'verified_at'),
  };
}

export function startupLocation(s: Startup): string | undefined {
  return [s.city, s.country].filter(Boolean).join(', ') || undefined;
}

function option(o: unknown): FilterOption | undefined {
  if (typeof o === 'string') return { value: o, label: o };
  if (typeof o === 'object' && o !== null) {
    const m = o as Json;
    const value = m.value ?? m.slug ?? m.label;
    if (value === undefined) return undefined;
    return { value: String(value), label: String(m.label ?? m.name ?? value), count: typeof m.count === 'number' ? m.count : undefined };
  }
  return undefined;
}

export function mapFilters(json: Json): StartupFilterOptions {
  const list = (key: string) => (Array.isArray(json[key]) ? (json[key] as unknown[]).map(option).filter((o): o is FilterOption => !!o) : []);
  return {
    industries: list('industries'),
    countries: list('countries'),
    stages: list('stages'),
    fundings: list('funding'),
    businessModels: list('business_models'),
    employeeRanges: list('employees'),
  };
}

const flag = (b?: boolean) => (b === undefined ? undefined : b ? 1 : 0);

export function startupQueryParams(q: StartupQuery): Query {
  return {
    search: q.search?.trim() || undefined,
    industry: q.industry,
    country: q.country,
    city: q.city,
    stage: q.stage,
    funding: q.funding,
    business_model: q.businessModel,
    employees: q.employees,
    founded_from: q.foundedFrom,
    founded_to: q.foundedTo,
    verified: flag(q.verified),
    claimed: flag(q.claimed),
    featured: flag(q.featured),
    orderby: q.sort ?? 'newest',
  };
}

export function activeFilterCount(q: StartupQuery): number {
  return [q.industry, q.country, q.city, q.stage, q.funding, q.businessModel, q.employees, q.foundedFrom, q.foundedTo, q.verified, q.claimed, q.featured].filter(
    (v) => v !== undefined,
  ).length;
}

/** A 404 on the collection or filters route means the add-on isn't switched on. */
async function get(path: string, query: Query, maxAgeMs: number, forceRefresh = false) {
  try {
    return await getJson(`${env.startupApi}${path}`, { query, maxAgeMs, forceRefresh });
  } catch (e) {
    if (e instanceof AppError && e.kind === 'notFound' && (path === '/startups' || path === '/startups/filters')) {
      throw new StartupDirectoryUnavailable();
    }
    throw e;
  }
}

export async function fetchStartups(q: StartupQuery, page = 1, perPage = 20, forceRefresh = false): Promise<Page<Startup>> {
  const r = await get('/startups', { ...startupQueryParams(q), page, per_page: perPage }, MINUTES(15), forceRefresh);
  if (!Array.isArray(r.data)) throw new AppError('badResponse');
  const items: Startup[] = [];
  for (const item of r.data) {
    try {
      items.push(mapStartup(item as Json));
    } catch {
      // Skip one malformed record rather than failing the list.
    }
  }
  return { items, page, totalPages: r.totalPages, total: r.total, stale: r.stale };
}

export async function fetchStartup(slug: string, forceRefresh = false): Promise<Startup> {
  const r = await get(`/startups/${encodeURIComponent(slug)}`, {}, HOURS(1), forceRefresh);
  if (typeof r.data !== 'object' || r.data === null || Array.isArray(r.data)) throw new AppError('badResponse');
  return mapStartup(r.data as Json);
}

export async function fetchStartupFilters(forceRefresh = false): Promise<StartupFilterOptions> {
  const r = await get('/startups/filters', {}, HOURS(6), forceRefresh);
  if (typeof r.data !== 'object' || r.data === null || Array.isArray(r.data)) throw new AppError('badResponse');
  return mapFilters(r.data as Json);
}
