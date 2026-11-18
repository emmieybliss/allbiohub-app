import { useLocalSearchParams } from 'expo-router';
import { useCategory } from '@/api/queries';
import { ErrorView } from '@/components/ui';
import { FeedHeader } from '@/features/articles/FeedHeader';
import { StoryFeed } from '@/features/articles/StoryFeed';

export default function CategoryScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const c = useCategory(slug);
  if (c.isError) return <ErrorView error={c.error} onRetry={() => c.refetch()} />;
  return (
    <StoryFeed
      title={c.data?.name ?? ''}
      feedKey={`category-${slug}`}
      kind={c.data ? { categoryId: c.data.id } : undefined}
      header={c.data ? <FeedHeader overline="Section" title={c.data.name} description={c.data.description} count={c.data.count} /> : null}
    />
  );
}
