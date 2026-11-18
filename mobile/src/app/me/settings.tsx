import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, Switch, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Field } from '@/components/Field';
import { Row } from '@/components/Screen';
import { AppText, Button, StateView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate } from '@/features/community/components';
import { communityMessage } from '@/features/community/errors';
import { showCommunityError, verifyEmail } from '@/features/community/gate';
import { usesPassword } from '@/features/community/models';
import { signOut, unregisterDevice, useSession } from '@/features/community/store';
import { showMessage } from '@/lib/toast';
import { radius, usePalette } from '@/theme';

type Icon = keyof typeof Ionicons.glyphMap;

function Group({ title }: { title: string }) {
  return (
    <AppText variant="overline" color="subtle" style={{ paddingHorizontal: 16, paddingTop: 24, paddingBottom: 6 }}>
      {title}
    </AppText>
  );
}

function Item({ icon, title, subtitle, onPress, color, right }: { icon: Icon; title: string; subtitle?: string; onPress?: () => void; color?: string; right?: React.ReactNode }) {
  const p = usePalette();
  return (
    <Row onPress={onPress} label={title}>
      <Ionicons name={icon} size={22} color={color ?? p.accentText} />
      <View style={{ flex: 1 }}>
        <AppText variant="label" color={color}>
          {title}
        </AppText>
        {subtitle ? (
          <AppText variant="caption" color="muted">
            {subtitle}
          </AppText>
        ) : null}
      </View>
      {right}
    </Row>
  );
}

/**
 * Explains exactly what deletion removes, confirms the person's identity and
 * only says the account is deleted once the server has done it.
 */
function DeleteAccountSheet({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const user = useSession((s) => s.user);
  const [password, setPassword] = useState('');
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const needsPassword = !!user && usesPassword(user);

  async function remove() {
    setBusy(true);
    setError(null);
    const { auth, api } = community();
    try {
      await auth.reauthenticate(needsPassword ? password : undefined);
      await unregisterDevice();
      await api.deleteAccount();
      await auth.signOut().catch(() => {});
      onClose();
      router.dismissTo('/profile');
      showMessage('Your account has been deleted.');
    } catch (e) {
      setError(communityMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <Pressable style={styles.backdrop} onPress={busy ? undefined : onClose} accessibilityLabel="Close" />
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.sheetWrap}>
        <ScrollView style={[styles.sheet, { backgroundColor: p.surface }]} contentContainerStyle={{ padding: 24, gap: 12, paddingBottom: 24 + insets.bottom }}>
          <AppText variant="headline">Delete your account?</AppText>
          <AppText>
            This permanently deletes your profile, username, follows, saved items on your account, notifications and reactions. Your comments are emptied
            and shown as “Deleted”. Stories and startups you submitted stay with our editors without your contact details. This can’t be undone.
          </AppText>
          <AppText variant="bodySmall" color="muted">
            Stories saved on this phone stay on this phone.
          </AppText>
          {needsPassword ? <Field label="Your password" value={password} onChangeText={setPassword} secureTextEntry autoCapitalize="none" /> : null}
          <Pressable
            onPress={() => setConfirmed(!confirmed)}
            accessibilityRole="checkbox"
            accessibilityState={{ checked: confirmed }}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 10, minHeight: 44 }}
          >
            <Ionicons name={confirmed ? 'checkbox' : 'square-outline'} size={24} color={p.accentText} />
            <AppText>I understand this is permanent</AppText>
          </Pressable>
          {error ? <AppText color={p.danger}>{error}</AppText> : null}
          <View style={{ flexDirection: 'row', gap: 12 }}>
            <Button kind="outlined" label="Keep account" onPress={onClose} disabled={busy} style={{ flex: 1 }} />
            <Pressable
              onPress={remove}
              disabled={!confirmed || busy || (needsPassword && !password)}
              accessibilityRole="button"
              style={[styles.danger, { backgroundColor: p.danger, opacity: !confirmed || busy || (needsPassword && !password) ? 0.5 : 1 }]}
            >
              <AppText variant="label" color="#FFFFFF">
                {busy ? 'Deleting…' : 'Delete'}
              </AppText>
            </Pressable>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </Modal>
  );
}

function AccountSettings() {
  const p = usePalette();
  const user = useSession((s) => s.user);
  const profile = useSession((s) => s.profile);
  const [deleting, setDeleting] = useState(false);
  const { api, auth } = community();

  if (!user) return <StateView icon="person-outline" title="You are signed out." />;

  const privacy = (changes: Parameters<typeof api.updateProfile>[0]) => api.updateProfile(changes).catch(showCommunityError);

  return (
    <ScrollView style={{ backgroundColor: p.background }} contentContainerStyle={{ paddingBottom: 40 }}>
      <Group title="Sign-in" />
      <Item
        icon="mail-outline"
        title={user.email ?? 'No email'}
        subtitle={user.emailVerified ? 'Verified · only you can see this' : 'Not verified yet'}
        right={!user.emailVerified ? <Button kind="text" label="Verify" onPress={() => void verifyEmail()} /> : undefined}
      />
      {profile ? <Item icon="at" title={`@${profile.username}`} subtitle="Change username" onPress={() => router.push('/account/username?change=1')} /> : null}
      {profile ? (
        <>
          <Group title="Privacy" />
          <Item
            icon="globe-outline"
            title="Public profile"
            subtitle="When off, only your name and username show next to your comments."
            right={<Switch value={profile.visibility === 'public'} onValueChange={(on) => privacy({ visibility: on ? 'public' : 'private' })} />}
          />
          <Item
            icon="time-outline"
            title="Show my activity"
            subtitle="Comment count and followed topics on your profile"
            right={<Switch value={profile.showActivity} onValueChange={(on) => privacy({ showActivity: on })} />}
          />
        </>
      ) : null}
      <Item icon="notifications-outline" title="Notification preferences" onPress={() => router.push('/notifications')} />
      <Group title="Account" />
      <Item
        icon="log-out-outline"
        title="Sign out"
        onPress={async () => {
          await signOut().catch(showCommunityError);
          router.dismissTo('/profile');
        }}
      />
      <Item icon="trash-outline" title="Delete account" color={p.danger} onPress={() => setDeleting(true)} />
      <Group title="AllBioHub team" />
      <Item
        icon="shield-outline"
        title={user.isAdmin ? 'Editor access is on' : 'Editor access'}
        subtitle={user.isAdmin ? 'You can moderate in the Firebase console (COMMUNITY.md).' : 'For AllBioHub editors on the admin list'}
        onPress={
          user.isAdmin
            ? undefined
            : async () => {
                try {
                  await api.claimAdmin();
                  await auth.reload();
                  showMessage('Editor access is on.');
                } catch (e) {
                  showCommunityError(e);
                }
              }
        }
      />
      <DeleteAccountSheet visible={deleting} onClose={() => setDeleting(false)} />
    </ScrollView>
  );
}

export default function AccountSettingsScreen() {
  return (
    <FeatureGate feature="accounts">
      <Stack.Screen options={{ title: 'Account' }} />
      <AccountSettings />
    </FeatureGate>
  );
}

const styles = StyleSheet.create({
  backdrop: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheetWrap: { position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '90%' },
  sheet: { borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg },
  danger: { flex: 1, minHeight: 48, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center' },
});
