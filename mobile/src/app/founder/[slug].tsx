import { Stack, router, useLocalSearchParams } from 'expo-router';
import { ActivityIndicator, ScrollView, Share, View } from 'react-native';
import { useStartupCoverage } from '@/api/queries';
import { RowCard } from '@/components/ArticleCards';
import { AppText, Button, IconButton } from '@/components/ui';
import { env } from '@/config/env';
import { FeatureGate, FollowButton, SaveEntityButton } from '@/features/community/components';
import { titleFromSlug } from '@/features/community/models';
import { useSavedEntities, useSession } from '@/features/community/store';
import { paths } from '@/lib/deepLinks';
import { openLink } from '@/lib/links';
import { usePalette } from '@/theme';

/**
 * A founder: follow for new stories, save, share, and AllBioHub coverage. The
 * directory has no founder records, so the startup profile passes what it
 * knows (name, role, startup, profile link); a page opened from a follow or
 * a saved item shows the name and coverage only.
 */
function Founder() {
  const p = usePalette();
  const params = useLocalSearchParams<{ slug: string; name?: string; role?: string; startup?: string; startupName?: string; startupLink?: string; url?: string }>();
  const { slug } = params;
  const followed = useSession((s) => s.follows.find((f) => f.target.kind === 'founder' && f.target.id === slug)?.target.label);
  const saved = useSavedEntities((s) => s.items.find((e) => e.kind === 'founder' && e.id === slug)?.title);
  const name = params.name || followed || saved || titleFromSlug(slug);
  const subtitle = [params.role, params.startupName].filter(Boolean).join(' · ');
  const coverage = useStartupCoverage(name);
  const initials = name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('');

  return (
    <ScrollView style={{ backgroundColor: p.background }} contentContainerStyle={{ paddingBottom: 32 }}>
      <Stack.Screen
        options={{
          title: '',
          headerRight: () => (
            <View style={{ flexDirection: 'row' }}>
              <SaveEntityButton entity={{ kind: 'founder', id: slug, title: name, subtitle: subtitle || undefined, url: params.url }} />
              <IconButton
                icon="share-outline"
                label="Share"
                onPress={() =>
                  Share.share({
                    message: [subtitle ? `${name}, ${subtitle}` : name, params.startupLink || env.siteUrl].join('\n'),
                  }).catch(() => {})
                }
              />
            </View>
          ),
        }}
      />
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16, paddingHorizontal: 20 }}>
        <View style={{ width: 64, height: 64, borderRadius: 32, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
          <AppText variant="title" color="accent">
            {initials}
          </AppText>
        </View>
        <View style={{ flex: 1 }}>
          <AppText variant="headline">{name}</AppText>
          {subtitle ? <AppText color="muted">{subtitle}</AppText> : null}
        </View>
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingHorizontal: 20, paddingTop: 16 }}>
        <FollowButton target={{ kind: 'founder', id: slug, label: name }} />
        {params.startup ? (
          <Button kind="outlined" icon="rocket-outline" label={params.startupName || 'Startup'} onPress={() => router.push(paths.startup(params.startup!) as never)} />
        ) : null}
        {params.url ? <Button kind="outlined" icon="open-outline" label="Profile" onPress={() => openLink(params.url!)} /> : null}
      </View>
      <AppText variant="title" style={{ paddingHorizontal: 20, paddingTop: 24, paddingBottom: 8 }}>
        On AllBioHub
      </AppText>
      {coverage.isPending ? (
        <ActivityIndicator style={{ margin: 16 }} color={p.accentText} />
      ) : coverage.isError ? (
        <AppText color="muted" style={{ paddingHorizontal: 20 }}>
          Stories could not be loaded.
        </AppText>
      ) : coverage.data.length ? (
        coverage.data.map((a) => <RowCard key={a.id} article={a} />)
      ) : (
        <AppText color="muted" style={{ paddingHorizontal: 20 }}>
          {`No AllBioHub stories mention ${name} yet.`}
        </AppText>
      )}
    </ScrollView>
  );
}

export default function FounderScreen() {
  return (
    <FeatureGate feature="founderFollows">
      <Founder />
    </FeatureGate>
  );
}
