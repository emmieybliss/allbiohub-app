import { useLocalSearchParams } from 'expo-router';
import { useArticleBySlug } from '@/api/queries';
import { ArticleView } from '@/features/articles/ArticleView';

/** allbiohub.com/{slug}/ links (App Links, notifications, links in stories). */
export default function StoryBySlugScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  return <ArticleView query={useArticleBySlug(slug)} />;
}
