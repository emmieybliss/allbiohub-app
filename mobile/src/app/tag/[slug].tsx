import { useLocalSearchParams } from 'expo-router';
import { useTag } from '@/api/queries';
import { ErrorView } from '@/components/ui';
import { FeedHeader } from '@/features/articles/FeedHeader';
import { StoryFeed } from '@/features/articles/StoryFeed';

export default function TagScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const t = useTag(slug);
  if (t.isError) return <ErrorView error={t.error} onRetry={() => t.refetch()} />;
  return (
    <StoryFeed
      title={t.data ? `#${t.data.name}` : ''}
      feedKey={`tag-${slug}`}
      kind={t.data ? { tagId: t.data.id } : undefined}
      header={t.data ? <FeedHeader overline="Topic" title={`#${t.data.name}`} description={t.data.description} count={t.data.count} /> : null}
    />
  );
}
