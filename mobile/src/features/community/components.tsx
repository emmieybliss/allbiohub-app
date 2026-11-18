import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { Image } from 'expo-image';
import { Redirect } from 'expo-router';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { pickOption } from '@/components/OptionSheet';
import { AppText, Button } from '@/components/ui';
import { showMessage } from '@/lib/toast';
import { radius, usePalette } from '@/theme';
import { community } from './api';
import { requireAccount, showCommunityError } from './gate';
import { type Feature, followFeature, type FollowTarget, REPORT_REASONS, type ReportReason, type SavedEntity, type UserProfile } from './models';
import { setFollow, useFeature, useIsEntitySaved, useIsFollowing, useSavedEntities } from './store';

/** Shows its children only while [feature] is on; a link to a page that's off opens Home. */
export function FeatureGate({ feature, children }: { feature: Feature; children: ReactNode }) {
  const on = useFeature(feature);
  if (!on) return <Redirect href="/" />;
  return <>{children}</>;
}

/** Round profile picture with the person's initial behind it. */
export function UserAvatar({ name, photoUrl, size = 36 }: { name?: string; photoUrl?: string; size?: number }) {
  const p = usePalette();
  const initial = name?.trim() ? name.trim()[0].toUpperCase() : '?';
  return (
    <View
      style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}
      accessible={false}
      importantForAccessibility="no-hide-descendants"
    >
      <AppText style={{ fontSize: size * 0.42, lineHeight: size * 0.6 }} color="accent">
        {initial}
      </AppText>
      {photoUrl ? <Image source={{ uri: photoUrl }} style={StyleSheet.absoluteFill} contentFit="cover" /> : null}
    </View>
  );
}

/** "+ Follow" / "Following". Hidden while following this kind of thing is off. Changes at once and rolls back on failure. */
export function FollowButton({ target, dense }: { target: FollowTarget; dense?: boolean }) {
  const p = usePalette();
  const on = useFeature(followFeature(target.kind));
  const following = useIsFollowing(target);
  if (!on) return null;
  const press = async () => {
    Haptics.selectionAsync().catch(() => {});
    const ok = await requireAccount({
      profile: false,
      reason: `Sign in to follow ${target.label || 'this'} and hear about new stories.`,
    });
    if (!ok) return;
    try {
      await setFollow(target, !following);
    } catch (e) {
      showCommunityError(e);
    }
  };
  return (
    <Pressable
      onPress={press}
      accessibilityRole="button"
      accessibilityState={{ checked: following }}
      accessibilityLabel={following ? `Following ${target.label}` : `Follow ${target.label}`}
      style={({ pressed }) => [
        styles.follow,
        dense && styles.followDense,
        {
          backgroundColor: following ? 'transparent' : p.accentSoft,
          borderColor: following ? p.border : p.accentSoft,
          opacity: pressed ? 0.8 : 1,
        },
      ]}
    >
      <Ionicons name={following ? 'checkmark' : 'add'} size={dense ? 16 : 18} color={p.accentText} />
      <AppText variant="label" color="accent">
        {following ? 'Following' : 'Follow'}
      </AppText>
    </Pressable>
  );
}

/** Save toggle for a startup or founder (works without an account). */
export function SaveEntityButton({ entity, color }: { entity: SavedEntity; color?: string }) {
  const p = usePalette();
  const saved = useIsEntitySaved(entity);
  return (
    <Pressable
      onPress={() => {
        Haptics.selectionAsync().catch(() => {});
        const now = useSavedEntities.getState().toggle(entity);
        showMessage(now ? 'Saved' : 'Removed from saved');
      }}
      accessibilityRole="button"
      accessibilityLabel={saved ? 'Remove from saved' : 'Save'}
      hitSlop={8}
      style={{ minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}
    >
      <Ionicons name={saved ? 'bookmark' : 'bookmark-outline'} size={22} color={saved ? p.accentText : (color ?? p.text)} />
    </Pressable>
  );
}

/** A card inviting guests to sign in, where a community section would otherwise be empty. */
export function JoinPrompt({ title, message }: { title: string; message: string }) {
  const p = usePalette();
  return (
    <View style={{ backgroundColor: p.accentSoft, borderRadius: radius.lg, padding: 16, gap: 6 }}>
      <AppText variant="subtitle">{title}</AppText>
      <AppText color="muted">{message}</AppText>
      <Button label="Sign in or create an account" onPress={() => void requireAccount({ profile: false })} style={{ marginTop: 8 }} />
    </View>
  );
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/** Picture, name, @username, bio, joined date and counts. Never email or ids. */
export function ProfileHeader({ profile, isMe }: { profile: UserProfile; isMe?: boolean }) {
  const facts = [
    profile.joinedAt ? `Joined AllBioHub ${MONTHS[profile.joinedAt.getMonth()]} ${profile.joinedAt.getFullYear()}` : null,
    ...(isMe || profile.showActivity
      ? [`${profile.followingCount} following`, `${profile.commentCount} ${profile.commentCount === 1 ? 'comment' : 'comments'}`]
      : []),
  ].filter(Boolean);
  return (
    <View style={{ gap: 10 }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
        <UserAvatar name={profile.displayName} photoUrl={profile.photoUrl} size={64} />
        <View style={{ flex: 1 }}>
          <AppText variant="title">{profile.displayName}</AppText>
          <AppText color="muted">@{profile.username}</AppText>
        </View>
      </View>
      {profile.bio ? <AppText>{profile.bio}</AppText> : null}
      <AppText variant="caption" color="subtle">
        {facts.join('   ')}
      </AppText>
    </View>
  );
}

/** Asks why, then reports a comment or person to the moderators. */
export async function reportContent(targetType: 'comment' | 'user', targetId: string) {
  const reason = await pickOption<ReportReason>(
    REPORT_REASONS.map((r) => ({ value: r.key, label: r.label })),
    'What’s wrong?',
  );
  if (!reason) return;
  try {
    await community().api.report(targetType, targetId, reason);
    showMessage('Thanks. Our moderators will review it.');
  } catch (e) {
    showCommunityError(e);
  }
}

/** A tappable row with an icon in a soft circle, a title and a line of explanation. */
export function IconRow({
  icon,
  title,
  subtitle,
  trailing,
  onPress,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
  onPress?: () => void;
}) {
  const p = usePalette();
  return (
    <Pressable onPress={onPress} disabled={!onPress} style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }} accessibilityRole={onPress ? 'button' : undefined}>
      <View style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: p.accentSoft, alignItems: 'center', justifyContent: 'center' }}>
        <Ionicons name={icon} size={18} color={p.accentText} />
      </View>
      <View style={{ flex: 1 }}>
        <AppText variant="label">{title}</AppText>
        {subtitle ? (
          <AppText variant="bodySmall" color="muted">
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {trailing}
    </Pressable>
  );
}

/** Small count bubble, e.g. unread notifications. */
export function CountBadge({ count }: { count: number }) {
  const p = usePalette();
  if (count <= 0) return null;
  return (
    <View style={{ minWidth: 20, height: 20, borderRadius: 10, paddingHorizontal: 5, backgroundColor: p.highlight, alignItems: 'center', justifyContent: 'center' }}>
      <AppText variant="caption" color="#FFFFFF">
        {count > 99 ? '99+' : String(count)}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  follow: { flexDirection: 'row', alignItems: 'center', gap: 6, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 16, minHeight: 40 },
  followDense: { paddingHorizontal: 12, minHeight: 34 },
});
