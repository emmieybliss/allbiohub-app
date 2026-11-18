import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Response cache on AsyncStorage. Keys are request URLs; an index keeps the
 * newest [MAX_ENTRIES] and drops the oldest.
 */
const PREFIX = 'abh.cache:';
const INDEX_KEY = 'abh.cache.index';
const MAX_ENTRIES = 300;

export type CacheEntry = { savedAt: number; data: unknown; total?: number; totalPages?: number };

let index: string[] | null = null;

async function loadIndex(): Promise<string[]> {
  if (index) return index;
  try {
    const raw = await AsyncStorage.getItem(INDEX_KEY);
    index = raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    index = [];
  }
  return index;
}

export async function readCache(key: string): Promise<CacheEntry | null> {
  try {
    const raw = await AsyncStorage.getItem(PREFIX + key);
    return raw ? (JSON.parse(raw) as CacheEntry) : null;
  } catch {
    return null;
  }
}

export async function writeCache(key: string, entry: CacheEntry): Promise<void> {
  const keys = await loadIndex();
  const next = [key, ...keys.filter((k) => k !== key)];
  const dropped = next.splice(MAX_ENTRIES);
  index = next;
  await AsyncStorage.setItem(PREFIX + key, JSON.stringify(entry));
  await AsyncStorage.setItem(INDEX_KEY, JSON.stringify(next));
  if (dropped.length) await AsyncStorage.multiRemove(dropped.map((k) => PREFIX + k));
}

/** Clears cached content. Saved stories and settings live elsewhere and stay. */
export async function clearCache(): Promise<void> {
  const keys = await loadIndex();
  await AsyncStorage.multiRemove([...keys.map((k) => PREFIX + k), INDEX_KEY]);
  index = [];
}
