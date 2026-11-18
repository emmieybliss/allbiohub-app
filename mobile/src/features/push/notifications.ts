import { PermissionsAndroid, Platform } from 'react-native';
import { env } from '@/config/env';
import { NOTIFICATION_TOPICS, type NotificationTopic } from '@/stores/preferences';

/**
 * Push notifications through Firebase Cloud Messaging topics, the same topics
 * the Flutter app subscribed to, so pushes sent from the Firebase console keep
 * reaching people after the update. A notification whose data.url is an
 * allbiohub.com link opens that page in the app when tapped.
 *
 * Off when the build has no google-services.json (env.hasFirebase) and in
 * Expo Go, where the native module isn't available.
 */
type Messaging = typeof import('@react-native-firebase/messaging');

let messagingModule: Messaging | null | undefined;

function load(): Messaging | null {
  if (messagingModule !== undefined) return messagingModule;
  if (!env.hasFirebase) return (messagingModule = null);
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    messagingModule = require('@react-native-firebase/messaging') as Messaging;
  } catch {
    messagingModule = null;
  }
  return messagingModule;
}

/**
 * Call once at start-up. Registers a background handler (required by
 * Firebase on Android; notification messages are shown by the system).
 */
export function setupPush(): void {
  const m = load();
  if (!m) return;
  try {
    m.setBackgroundMessageHandler(m.getMessaging(), async () => {});
  } catch {
    // Firebase failed to start: continue without notifications.
  }
}

export function pushAvailable(): boolean {
  return load() !== null;
}

export async function requestPushPermission(): Promise<boolean> {
  const m = load();
  if (!m) return false;
  try {
    if (Platform.OS === 'android' && Number(Platform.Version) >= 33) {
      const result = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
      return result === PermissionsAndroid.RESULTS.GRANTED;
    }
    const status = await m.requestPermission(m.getMessaging());
    return status === m.AuthorizationStatus.AUTHORIZED || status === m.AuthorizationStatus.PROVISIONAL;
  } catch {
    return false;
  }
}

/**
 * Subscribes to the chosen topics and leaves the others. Every topic is sent
 * once per launch, since subscriptions can be lost (for example after the
 * app's data was cleared).
 */
export async function syncTopics(chosen: NotificationTopic[]): Promise<void> {
  const m = load();
  if (!m) return;
  const messaging = m.getMessaging();
  await Promise.all(
    NOTIFICATION_TOPICS.map(({ topic }) =>
      (chosen.includes(topic) ? m.subscribeToTopic(messaging, topic) : m.unsubscribeFromTopic(messaging, topic)).catch(() => {}),
    ),
  );
}

function urlOf(message: { data?: Record<string, unknown> } | null | undefined): string | null {
  const url = message?.data?.url;
  return typeof url === 'string' && url ? url : null;
}

/** Calls [onOpen] with the link of a notification that opened the app. Returns an unsubscribe. */
export function listenForOpenedNotifications(onOpen: (url: string) => void): () => void {
  const m = load();
  if (!m) return () => {};
  const messaging = m.getMessaging();
  m.getInitialNotification(messaging)
    .then((msg) => {
      const url = urlOf(msg);
      if (url) onOpen(url);
    })
    .catch(() => {});
  return m.onNotificationOpenedApp(messaging, (msg) => {
    const url = urlOf(msg);
    if (url) onOpen(url);
  });
}
