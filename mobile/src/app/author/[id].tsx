import { useLocalSearchParams } from 'expo-router';
import { View } from 'react-native';
import { useAuthor } from '@/api/queries';
import { AppImage } from '@/components/AppImage';
import { AppText } from '@/components/ui';
import { StoryFeed } from '@/features/articles/StoryFeed';

/** An AllBioHub writer and their stories. */
export default function AuthorScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const authorId = Number(id);
  const a = useAuthor(authorId);
  const header = a.data ? (
    <View style={{ flexDirection: 'row', gap: 14, alignItems: 'center', padding: 16 }}>
      {a.data.avatarUrl ? (
        <AppImage image={{ variants: [{ url: a.data.avatarUrl, w: 96, h: 96 }], alt: '', caption: '' }} width={64} style={{ width: 64, height: 64 }} rounded={32} />
      ) : null}
      <View style={{ flex: 1, gap: 4 }}>
        <AppText variant="overline" color="accent">
          Writer
        </AppText>
        <AppText variant="headline" accessibilityRole="header">
          {a.data.name}
        </AppText>
        {a.data.description ? (
          <AppText variant="bodySmall" color="muted">
            {a.data.description}
          </AppText>
        ) : null}
      </View>
    </View>
  ) : null;
  // The stories load even if the author profile itself is private.
  return <StoryFeed title={a.data?.name ?? 'Stories'} feedKey={`author-${authorId}`} kind={Number.isFinite(authorId) ? { authorId } : undefined} header={header} />;
}
