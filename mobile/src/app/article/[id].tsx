import { useLocalSearchParams } from 'expo-router';
import { useArticle } from '@/api/queries';
import { ArticleView } from '@/features/articles/ArticleView';

export default function ArticleScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <ArticleView query={useArticle(Number(id))} />;
}
