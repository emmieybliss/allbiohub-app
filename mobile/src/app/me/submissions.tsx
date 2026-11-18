import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import { ActivityIndicator, RefreshControl, ScrollView, View } from 'react-native';
import { Row } from '@/components/Screen';
import { AppText, Button, Divider, ErrorView, StateView } from '@/components/ui';
import { FeatureGate, JoinPrompt } from '@/features/community/components';
import { useMySubmissions } from '@/features/community/hooks';
import { SUBMISSION_STATUS_LABELS, type Submission } from '@/features/community/models';
import { useFeature, useUser } from '@/features/community/store';
import { relativeDate } from '@/lib/text';
import { radius, usePalette } from '@/theme';

const KIND: Record<Submission['kind'], [string, keyof typeof Ionicons.glyphMap]> = {
  story: ['Story', 'newspaper-outline'],
  startup: ['Startup', 'rocket-outline'],
  claim: ['Claim', 'id-card-outline'],
};

function SubmitActions() {
  const story = useFeature('storySubmissions');
  const startup = useFeature('startupSubmissions');
  return (
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12, padding: 16 }}>
      {story ? <Button kind="outlined" icon="newspaper-outline" label="Submit a story" onPress={() => router.push('/submit/story')} /> : null}
      {startup ? <Button kind="outlined" icon="rocket-outline" label="Submit a startup" onPress={() => router.push('/submit/startup')} /> : null}
    </View>
  );
}

function SubmissionRow({ s }: { s: Submission }) {
  const p = usePalette();
  const [kind, icon] = KIND[s.kind];
  const positive = s.status === 'accepted' || s.status === 'published' || s.status === 'approved';
  return (
    <View>
      <Row>
        <Ionicons name={icon} size={22} color={p.accentText} />
        <View style={{ flex: 1, gap: 2 }}>
          <AppText variant="label" numberOfLines={2}>
            {s.title}
          </AppText>
          <AppText variant="caption" color="subtle">
            {[kind, s.createdAt ? relativeDate(s.createdAt.toISOString()) : null].filter(Boolean).join(' · ')}
          </AppText>
          {s.editorNote ? (
            <AppText variant="bodySmall" color="muted">
              {`Editor: ${s.editorNote}`}
            </AppText>
          ) : null}
        </View>
        <View style={{ borderRadius: radius.pill, borderWidth: 1, borderColor: positive ? p.accentSoft : p.border, backgroundColor: positive ? p.accentSoft : 'transparent', paddingHorizontal: 10, paddingVertical: 4 }}>
          <AppText variant="caption" color={positive ? 'accent' : 'muted'}>
            {SUBMISSION_STATUS_LABELS[s.status]}
          </AppText>
        </View>
      </Row>
      <Divider />
    </View>
  );
}

/** The person's story and startup submissions and claims, with their review status. */
function MySubmissions() {
  const p = usePalette();
  const user = useUser();
  const q = useMySubmissions();
  if (!user) {
    return (
      <View style={{ padding: 20 }}>
        <JoinPrompt title="Your submissions" message="Sign in to send stories and startups to the editors and follow their review." />
      </View>
    );
  }
  if (q.isPending) return <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />;
  if (q.isError) return <ErrorView error={q.error} onRetry={() => q.refetch()} />;
  return (
    <ScrollView style={{ backgroundColor: p.background }} refreshControl={<RefreshControl refreshing={false} onRefresh={() => void q.refetch()} />}>
      {q.data.length ? (
        q.data.map((s) => <SubmissionRow key={`${s.kind}-${s.id}`} s={s} />)
      ) : (
        <StateView icon="create-outline" title="No submissions yet" body="Stories and startups you send to the editors show here with their review status." />
      )}
      <SubmitActions />
    </ScrollView>
  );
}

export default function MySubmissionsScreen() {
  return (
    <FeatureGate feature="accounts">
      <Stack.Screen options={{ title: 'My submissions' }} />
      <MySubmissions />
    </FeatureGate>
  );
}
