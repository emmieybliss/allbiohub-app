import { useLocalSearchParams } from 'expo-router';
import { useCategory } from '@/api/queries';
import { ErrorView } from '@/components/ui';
import { FeedHeader } from '@/features/articles/FeedHeader';
import { FollowButton } from '@/features/community/components';
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
      header={c.data ? (
          <FeedHeader
            overline="Section"
            title={c.data.name}
            description={c.data.description}
            count={c.data.count}
            action={<FollowButton dense target={{ kind: 'topic', id: c.data.slug, label: c.data.name }} />}
          />
        ) : null}
    />
  );
}
