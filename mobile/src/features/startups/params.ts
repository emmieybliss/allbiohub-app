import type { StartupQuery, StartupSort } from '@/models/types';
import { STARTUP_SORTS } from '@/models/types';

/** A directory query as route params (/directory?industry=...&sort=...), and back. */
export type DirectoryParams = Partial<Record<'search' | 'industry' | 'country' | 'city' | 'stage' | 'funding' | 'businessModel' | 'employees' | 'foundedFrom' | 'foundedTo' | 'verified' | 'claimed' | 'featured' | 'sort', string>>;

export function queryToParams(q: StartupQuery): DirectoryParams {
  const out: DirectoryParams = {};
  for (const [k, v] of Object.entries(q)) {
    if (v === undefined || v === null || v === '') continue;
    out[k as keyof DirectoryParams] = typeof v === 'boolean' ? (v ? '1' : '0') : String(v);
  }
  return out;
}

export function paramsToQuery(p: DirectoryParams): StartupQuery {
  const str = (v?: string) => (v ? v : undefined);
  const int = (v?: string) => {
    const n = parseInt(v ?? '', 10);
    return Number.isFinite(n) ? n : undefined;
  };
  const bool = (v?: string) => (v === '1' ? true : v === '0' ? false : undefined);
  const sort = STARTUP_SORTS.some((s) => s.key === p.sort) ? (p.sort as StartupSort) : undefined;
  return {
    search: str(p.search),
    industry: str(p.industry),
    country: str(p.country),
    city: str(p.city),
    stage: str(p.stage),
    funding: str(p.funding),
    businessModel: str(p.businessModel),
    employees: str(p.employees),
    foundedFrom: int(p.foundedFrom),
    foundedTo: int(p.foundedTo),
    verified: bool(p.verified),
    claimed: bool(p.claimed),
    featured: bool(p.featured),
    sort,
  };
}
