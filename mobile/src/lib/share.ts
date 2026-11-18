import { Share } from 'react-native';
import type { Article, Startup } from '@/models/types';

/** Share text always links to the canonical allbiohub.com URL. */
export async function shareArticle(a: Article) {
  await Share.share({ message: `${a.title}\n${a.link}`, url: a.link, title: a.title }).catch(() => {});
}

export async function shareStartup(s: Startup) {
  const text = s.tagline ? `${s.name}: ${s.tagline}` : s.name;
  await Share.share({ message: `${text} on AllBioHub\n${s.link}`, url: s.link, title: s.name }).catch(() => {});
}
