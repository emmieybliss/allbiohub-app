import { Stack } from 'expo-router';
import { useState } from 'react';
import { ScrollView, Switch, View } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { community } from '@/features/community/api';
import { showCommunityError } from '@/features/community/gate';
import { COMMUNITY_NOTIFICATION_PREFS, type CommunityNotificationPref, wants } from '@/features/community/models';
import { useFeature, useSession } from '@/features/community/store';
import { pushAvailable, requestPushPermission } from '@/features/push/notifications';
import { NOTIFICATION_TOPICS, usePreferences } from '@/stores/preferences';
import { usePalette } from '@/theme';

/** What the account sends: replies, followed topics and startups, submissions. Kept on the account, so it follows the person to other phones. */
function AccountPreferences() {
  const p = usePalette();
  const on = useFeature('notificationCenter');
  const user = useSession((s) => s.user);
  const account = useSession((s) => s.account);
  // Switches flip at once; the account's copy replaces this when it arrives.
  const [pending, setPending] = useState<Partial<Record<CommunityNotificationPref, boolean>>>({});
  if (!on || !user || !account) return null;

  async function change(key: CommunityNotificationPref, value: boolean) {
    setPending((x) => ({ ...x, [key]: value }));
    try {
      await community().api.updateNotificationPrefs({ [key]: value });
    } catch (e) {
      showCommunityError(e);
    } finally {
      setPending((x) => {
        const next = { ...x };
        delete next[key];
        return next;
      });
    }
  }

  return (
    <View style={{ marginTop: 16, gap: 4 }}>
      <AppText variant="title">Your account</AppText>
      <AppText variant="bodySmall" color="muted" style={{ marginBottom: 4 }}>
        Sent to every phone you sign in on.
      </AppText>
      {COMMUNITY_NOTIFICATION_PREFS.map((pref) => {
        const value = pending[pref.key] ?? wants(account, pref.key);
        return (
          <View key={pref.key} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 56, gap: 12 }}>
            <View style={{ flex: 1 }}>
              <AppText variant="label">{pref.label}</AppText>
              <AppText variant="caption" color="muted">
                {pref.description}
              </AppText>
            </View>
            <Switch
              value={value}
              disabled={pref.key in pending}
              onValueChange={(v) => void change(pref.key, v)}
              trackColor={{ true: p.accent, false: p.border }}
              thumbColor="#FFFFFF"
              accessibilityLabel={pref.label}
            />
          </View>
        );
      })}
    </View>
  );
}

export default function NotificationSettingsScreen() {
  const p = usePalette();
  const topics = usePreferences((s) => s.notificationTopics);
  const setTopics = usePreferences((s) => s.setNotificationTopics);
  const available = pushAvailable();
  const [denied, setDenied] = useState(false);

  return (
    <ScrollView contentContainerStyle={{ padding: 16, gap: 8 }}>
      <Stack.Screen options={{ title: 'Notifications' }} />
      <AppText color="muted" style={{ marginBottom: 8 }}>
        {available
          ? 'Choose what AllBioHub sends you. You can change this at any time.'
          : 'Notifications are not switched on in this version of the app yet. Your choices are saved and used once they are.'}
      </AppText>
      {available ? (
        <Button
          kind="outlined"
          icon="notifications-outline"
          label="Allow notifications on this phone"
          onPress={async () => setDenied(!(await requestPushPermission()))}
          style={{ marginBottom: 8 }}
        />
      ) : null}
      {denied ? (
        <AppText variant="bodySmall" color="muted">
          Notifications are blocked for AllBioHub. Turn them on in your phone’s settings.
        </AppText>
      ) : null}
      {NOTIFICATION_TOPICS.map((t) => (
        <View key={t.topic} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 52 }}>
          <AppText variant="label" style={{ flex: 1 }}>
            {t.label}
          </AppText>
          <Switch
            value={topics.includes(t.topic)}
            onValueChange={(on) => setTopics(on ? [...topics, t.topic] : topics.filter((x) => x !== t.topic))}
            trackColor={{ true: p.accent, false: p.border }}
            thumbColor="#FFFFFF"
            accessibilityLabel={t.label}
          />
        </View>
      ))}
      <AccountPreferences />
    </ScrollView>
  );
}
