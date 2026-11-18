import { Stack } from 'expo-router';
import { useState } from 'react';
import { ScrollView, Switch, View } from 'react-native';
import { AppText, Button } from '@/components/ui';
import { pushAvailable, requestPushPermission } from '@/features/push/notifications';
import { NOTIFICATION_TOPICS, usePreferences } from '@/stores/preferences';
import { usePalette } from '@/theme';

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
    </ScrollView>
  );
}
