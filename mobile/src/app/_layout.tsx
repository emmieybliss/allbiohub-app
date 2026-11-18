import { Inter_400Regular, Inter_500Medium, Inter_600SemiBold, Inter_700Bold } from '@expo-google-fonts/inter';
import { PlayfairDisplay_700Bold, PlayfairDisplay_800ExtraBold } from '@expo-google-fonts/playfair-display';
import { QueryClientProvider } from '@tanstack/react-query';
import { useFonts } from 'expo-font';
import { DarkTheme, DefaultTheme, Stack, ThemeProvider, router } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import * as SystemUI from 'expo-system-ui';
import { useEffect, useState } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { queryClient } from '@/api/queries';
import { OptionSheetHost } from '@/components/OptionSheet';
import { openNotificationUrl } from '@/features/community/openUrl';
import { startCommunity, useFlags, useSavedEntities } from '@/features/community/store';
import { listenForOpenedNotifications, setupPush, syncTopics } from '@/features/push/notifications';
import { useBookmarks } from '@/stores/bookmarks';
import { usePreferences } from '@/stores/preferences';
import { fonts, usePalette } from '@/theme';

SplashScreen.preventAutoHideAsync().catch(() => {});
setupPush();

export const unstable_settings = { anchor: '(tabs)' };

function useHydrated() {
  const stores = [usePreferences, useBookmarks, useFlags, useSavedEntities] as const;
  const all = () => stores.every((s) => s.persist.hasHydrated());
  const [hydrated, setHydrated] = useState(all);
  useEffect(() => {
    const check = () => setHydrated(all());
    const offs = stores.map((s) => s.persist.onFinishHydration(check));
    // Hydration may have finished between the first render and this effect.
    queueMicrotask(check);
    return () => offs.forEach((off) => off());
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return hydrated;
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
    Inter_700Bold,
    PlayfairDisplay_700Bold,
    PlayfairDisplay_800ExtraBold,
  });
  const hydrated = useHydrated();
  const p = usePalette();
  const onboarded = usePreferences((s) => s.onboardingComplete);
  const topics = usePreferences((s) => s.notificationTopics);
  const ready = (fontsLoaded || !!fontError) && hydrated;

  useEffect(() => {
    SystemUI.setBackgroundColorAsync(p.background).catch(() => {});
  }, [p.background]);

  useEffect(() => {
    if (!ready) return;
    SplashScreen.hideAsync().catch(() => {});
    if (!onboarded) router.replace('/onboarding');
    // Only after onboarding, where the person chose their topics.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready]);

  useEffect(() => {
    if (ready && onboarded) syncTopics(topics);
  }, [ready, onboarded, topics]);

  useEffect(() => {
    if (!ready) return;
    // Personal notifications may carry an app path such as /me/submissions.
    return listenForOpenedNotifications(openNotificationUrl);
  }, [ready]);

  // Community features (COMMUNITY.md): switches, sign-in and the person's live data.
  useEffect(() => {
    if (!ready) return;
    return startCommunity();
  }, [ready]);

  if (!ready) return null;

  const navTheme = p.dark ? DarkTheme : DefaultTheme;
  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: p.background }}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider
            value={{
              ...navTheme,
              colors: { ...navTheme.colors, primary: p.accentText, background: p.background, card: p.background, text: p.text, border: p.border },
            }}
          >
            <StatusBar style={p.dark ? 'light' : 'dark'} />
            <Stack
              screenOptions={{
                headerShadowVisible: false,
                headerStyle: { backgroundColor: p.background },
                headerTintColor: p.text,
                headerTitleStyle: { fontFamily: fonts.semibold, fontSize: 17 },
                headerBackButtonDisplayMode: 'minimal',
                contentStyle: { backgroundColor: p.background },
              }}
            >
              <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
              <Stack.Screen name="onboarding" options={{ headerShown: false, gestureEnabled: false }} />
              <Stack.Screen name="search" options={{ headerShown: false, animation: 'fade' }} />
              <Stack.Screen name="article/[id]/index" options={{ title: '' }} />
              <Stack.Screen name="story/[slug]" options={{ title: '' }} />
              <Stack.Screen name="account/sign-in" options={{ presentation: 'modal' }} />
            </Stack>
            <OptionSheetHost />
          </ThemeProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
