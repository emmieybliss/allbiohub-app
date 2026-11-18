import { Ionicons } from '@expo/vector-icons';
import { Stack, router, useLocalSearchParams } from 'expo-router';
import { Linking, Pressable, RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { AppError } from '@/api/errors';
import { isDirectoryUnavailable, refreshAll, useStartup, useStartupCoverage } from '@/api/queries';
import { startupLocation } from '@/api/startups';
import { RowCard } from '@/components/ArticleCards';
import { StartupBadges, StartupLogo } from '@/components/StartupCards';
import { AppText, Button, Divider, ErrorView, IconButton, SectionHeader, SkeletonBox, StateView } from '@/components/ui';
import { sitePage } from '@/config/env';
import { FollowButton, SaveEntityButton } from '@/features/community/components';
import { slugify } from '@/features/community/models';
import { useFeature } from '@/features/community/store';
import { DirectoryUnavailable } from '@/features/startups/DirectoryUnavailable';
import { imageUrlFor } from '@/lib/images';
import { paths } from '@/lib/deepLinks';
import { openLink } from '@/lib/links';
import { shareStartup } from '@/lib/share';
import { fullDate } from '@/lib/text';
import { radius, usePalette } from '@/theme';

const SOCIAL_ICONS: Record<string, keyof typeof Ionicons.glyphMap> = {
  linkedin: 'logo-linkedin',
  x: 'logo-x',
  twitter: 'logo-x',
  facebook: 'logo-facebook',
  instagram: 'logo-instagram',
  youtube: 'logo-youtube',
  tiktok: 'logo-tiktok',
  github: 'logo-github',
};

function externalUrl(url: string) {
  return url.startsWith('http') ? url : `https://${url}`;
}

export default function StartupProfileScreen() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const p = usePalette();
  const q = useStartup(slug);
  const s = q.data;
  const coverage = useStartupCoverage(s?.name);
  const follows = useFeature('startupFollows');
  const founderPages = useFeature('founderFollows');
  const inAppClaim = useFeature('startupClaims');

  if (q.isPending) {
    return (
      <View style={{ padding: 16, gap: 16 }}>
        <Stack.Screen options={{ title: '' }} />
        <SkeletonBox height={72} width={72} radius={16} />
        <SkeletonBox height={24} width="60%" />
        <SkeletonBox height={16} />
        <SkeletonBox height={160} radius={16} />
      </View>
    );
  }
  if (q.isError) {
    return (
      <>
        <Stack.Screen options={{ title: '' }} />
        {isDirectoryUnavailable(q.error) ? (
          <DirectoryUnavailable />
        ) : q.error instanceof AppError && q.error.kind === 'notFound' ? (
          <StateView
            icon="rocket-outline"
            title="Open this startup on allbiohub.com"
            body="We couldn't find this profile in the app."
            action={{ label: 'Open on allbiohub.com', onPress: () => Linking.openURL(sitePage(`startups/${slug}/`)) }}
          />
        ) : (
          <ErrorView error={q.error} onRetry={() => q.refetch()} />
        )}
      </>
    );
  }
  if (!s) return null;

  const details: [string, string | undefined][] = [
    ['Industry', s.industry],
    ['Location', startupLocation(s)],
    ['Founded', s.founded ? String(s.founded) : undefined],
    ['Stage', s.stage],
    ['Funding', s.funding],
    ['Business model', s.businessModel],
    ['Team size', s.employees],
    ['Status', s.status],
    ['Verified on', s.verified && s.verifiedAt ? fullDate(s.verifiedAt) : undefined],
  ];
  const shownDetails = details.filter((d): d is [string, string] => !!d[1]);

  return (
    <View style={{ flex: 1, backgroundColor: p.background }}>
      <Stack.Screen
        options={{
          title: '',
          headerRight: () => (
            <View style={{ flexDirection: 'row' }}>
              <SaveEntityButton
                entity={{
                  kind: 'startup',
                  id: s.slug,
                  title: s.name,
                  subtitle: [s.industry, s.country].filter(Boolean).join(' · ') || undefined,
                  image: s.logo ? imageUrlFor(s.logo, 200, true) : undefined,
                  url: s.link,
                }}
              />
              <IconButton icon="share-social-outline" label="Share" onPress={() => shareStartup(s)} />
            </View>
          ),
        }}
      />
      <ScrollView
        contentContainerStyle={{ paddingBottom: 40 }}
        refreshControl={<RefreshControl refreshing={q.isRefetching} onRefresh={() => refreshAll(q.refetch)} tintColor={p.accentText} colors={[p.accent]} />}
      >
        <View style={{ padding: 16, gap: 12 }}>
          <View style={{ flexDirection: 'row', gap: 14, alignItems: 'center' }}>
            <StartupLogo startup={s} size={72} />
            <View style={{ flex: 1, gap: 6 }}>
              <AppText variant="headline" accessibilityRole="header">
                {s.name}
              </AppText>
              <StartupBadges startup={s} />
            </View>
          </View>
          {s.tagline ? <AppText variant="subtitle" color="muted">{s.tagline}</AppText> : null}
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
            {s.website ? <Button icon="globe-outline" label="Visit website" onPress={() => openLink(externalUrl(s.website!))} /> : null}
            <Button kind="outlined" icon="share-social-outline" label="Share" onPress={() => shareStartup(s)} />
          </View>
          {follows ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <FollowButton target={{ kind: 'startup', id: s.slug, label: s.name }} />
              <AppText variant="bodySmall" color="muted" style={{ flex: 1 }}>
                Get alerts about new coverage and profile updates.
              </AppText>
            </View>
          ) : null}
        </View>

        {s.description ? (
          <View style={styles.section}>
            <AppText variant="title">About</AppText>
            <AppText selectable>{s.description}</AppText>
          </View>
        ) : null}

        {shownDetails.length ? (
          <View style={styles.section}>
            <AppText variant="title">Company details</AppText>
            <View style={[styles.box, { borderColor: p.border, backgroundColor: p.card }]}>
              {shownDetails.map(([label, value], i) => (
                <View key={label}>
                  {i ? <Divider /> : null}
                  <View style={styles.detail}>
                    <AppText color="muted" style={{ width: 130 }}>
                      {label}
                    </AppText>
                    <AppText variant="label" style={{ flex: 1 }}>
                      {value}
                    </AppText>
                  </View>
                </View>
              ))}
            </View>
          </View>
        ) : null}

        {s.founders.length ? (
          <View style={styles.section}>
            <AppText variant="title">Founders</AppText>
            {s.founders.map((f) => {
              const founderSlug = founderPages ? slugify(f.name) : '';
              const open = founderSlug
                ? () =>
                    router.push({
                      pathname: '/founder/[slug]',
                      params: { slug: founderSlug, name: f.name, role: f.role ?? '', startup: s.slug, startupName: s.name, startupLink: s.link, url: f.url ?? '' },
                    })
                : f.url
                  ? () => openLink(externalUrl(f.url!))
                  : undefined;
              return (
                <Pressable
                  key={f.name}
                  disabled={!open}
                  onPress={open}
                  accessibilityRole={open ? 'link' : undefined}
                  style={[styles.founder, { backgroundColor: p.card, borderColor: p.border }]}
                >
                  <View style={[styles.avatar, { backgroundColor: p.accentSoft }]}>
                    <AppText variant="label" color="accent">
                      {f.name[0]?.toUpperCase()}
                    </AppText>
                  </View>
                  <View style={{ flex: 1 }}>
                    <AppText variant="label">{f.name}</AppText>
                    {f.role ? (
                      <AppText variant="caption" color="muted">
                        {f.role}
                      </AppText>
                    ) : null}
                  </View>
                  {founderSlug ? (
                    <FollowButton dense target={{ kind: 'founder', id: founderSlug, label: f.name }} />
                  ) : f.url ? (
                    <Ionicons name="open-outline" size={16} color={p.subtle} />
                  ) : null}
                </Pressable>
              );
            })}
          </View>
        ) : null}

        {s.products.length ? (
          <View style={styles.section}>
            <AppText variant="title">Products</AppText>
            {s.products.map((prod) => (
              <AppText key={prod}>• {prod}</AppText>
            ))}
          </View>
        ) : null}

        {Object.keys(s.social).length ? (
          <View style={styles.section}>
            <AppText variant="title">Social</AppText>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
              {Object.entries(s.social).map(([network, url]) => (
                <Button key={network} kind="outlined" icon={SOCIAL_ICONS[network.toLowerCase()] ?? 'link-outline'} label={network === 'x' ? 'X' : network[0].toUpperCase() + network.slice(1)} onPress={() => openLink(externalUrl(url))} />
              ))}
            </View>
          </View>
        ) : null}

        <View style={[styles.section, { flexDirection: 'row', flexWrap: 'wrap', gap: 10 }]}>
          <Button kind="text" icon="create-outline" label="Suggest an update" onPress={() => openLink(sitePage('claim-startup/'))} />
          {!s.claimed ? (
            <Button
              kind="outlined"
              label="Claim this startup"
              onPress={() => (inAppClaim ? router.push(paths.claimStartup(s.slug) as never) : openLink(sitePage('claim-startup/')))}
            />
          ) : null}
        </View>

        {coverage.data?.length ? (
          <>
            <SectionHeader title="AllBioHub coverage" subtitle="Stories that mention this startup" />
            {coverage.data.map((a) => (
              <RowCard key={a.id} article={a} />
            ))}
          </>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  section: { paddingHorizontal: 16, paddingTop: 20, gap: 10 },
  box: { borderWidth: StyleSheet.hairlineWidth, borderRadius: radius.lg },
  detail: { flexDirection: 'row', padding: 12, gap: 8 },
  founder: { flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12, borderRadius: radius.md, borderWidth: StyleSheet.hairlineWidth },
  avatar: { width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center' },
});
