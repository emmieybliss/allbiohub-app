import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

/** Push topics. Values are the FCM topic names the Flutter app used: never change them. */
export const NOTIFICATION_TOPICS = [
  { topic: 'breaking', label: 'Breaking stories' },
  { topic: 'celebrity', label: 'Celebrity' },
  { topic: 'technology', label: 'Technology' },
  { topic: 'startups', label: 'Startups' },
  { topic: 'money', label: 'Money & Career' },
  { topic: 'biography', label: 'Biography' },
  { topic: 'spotlight', label: 'Spotlight' },
] as const;

export type NotificationTopic = (typeof NOTIFICATION_TOPICS)[number]['topic'];

export const TEXT_SIZES = [
  { key: 'small', scale: 0.9, label: 'Small' },
  { key: 'medium', scale: 1, label: 'Default' },
  { key: 'large', scale: 1.15, label: 'Large' },
  { key: 'extraLarge', scale: 1.3, label: 'Extra large' },
] as const;

export type TextSize = (typeof TEXT_SIZES)[number]['key'];
export type ThemeMode = 'system' | 'light' | 'dark';

type PreferencesState = {
  themeMode: ThemeMode;
  textSize: TextSize;
  onboardingComplete: boolean;
  interestSlugs: string[];
  notificationTopics: NotificationTopic[];
  setThemeMode: (m: ThemeMode) => void;
  setTextSize: (s: TextSize) => void;
  completeOnboarding: (interests: string[]) => void;
  setInterests: (slugs: string[]) => void;
  setNotificationTopics: (topics: NotificationTopic[]) => void;
};

export const usePreferences = create<PreferencesState>()(
  persist(
    (set) => ({
      themeMode: 'system',
      textSize: 'medium',
      onboardingComplete: false,
      interestSlugs: [],
      notificationTopics: ['breaking'],
      setThemeMode: (themeMode) => set({ themeMode }),
      setTextSize: (textSize) => set({ textSize }),
      completeOnboarding: (interestSlugs) => set({ interestSlugs, onboardingComplete: true }),
      setInterests: (interestSlugs) => set({ interestSlugs }),
      setNotificationTopics: (notificationTopics) => set({ notificationTopics }),
    }),
    { name: 'abh.preferences', version: 1, storage: createJSONStorage(() => AsyncStorage) },
  ),
);

export function textScale(size: TextSize): number {
  return TEXT_SIZES.find((t) => t.key === size)?.scale ?? 1;
}
