import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText, Button } from '@/components/ui';
import { TopicPicker } from '@/features/onboarding/TopicPicker';
import { requestPushPermission, syncTopics } from '@/features/push/notifications';
import { usePreferences } from '@/stores/preferences';
import { usePalette } from '@/theme';

const INTRO: { icon: keyof typeof Ionicons.glyphMap; title: string; body: string }[] = [
  { icon: 'earth', title: 'Discover the people, stories and ideas shaping Africa.', body: 'Biography, celebrity news, money, careers and more, all in one hub.' },
  { icon: 'book', title: 'Stories worth your time', body: 'Read the latest from AllBioHub in a clean, fast reader. Save stories for later.' },
  { icon: 'rocket', title: 'Explore African startups', body: 'Find startups, founders and companies, and the AllBioHub coverage behind them.' },
];

export default function OnboardingScreen() {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const [index, setIndex] = useState(0);
  const [interests, setInterests] = useState<string[]>([]);
  const complete = usePreferences((s) => s.completeOnboarding);
  const topics = usePreferences((s) => s.notificationTopics);
  const last = index === INTRO.length;

  const finish = async () => {
    complete(interests);
    // Ask for notification permission once, after the person has seen the app's value.
    if (await requestPushPermission()) syncTopics(topics);
    router.replace('/');
  };

  return (
    <View style={{ flex: 1, backgroundColor: p.background, paddingTop: insets.top, paddingBottom: insets.bottom + 16 }}>
      <View style={styles.top}>
        <View style={styles.dots} accessibilityLabel={`Step ${index + 1} of ${INTRO.length + 1}`}>
          {Array.from({ length: INTRO.length + 1 }, (_, i) => (
            <View key={i} style={[styles.dot, { backgroundColor: i === index ? p.accent : p.border, width: i === index ? 20 : 8 }]} />
          ))}
        </View>
        {!last ? <Button kind="text" label="Skip" onPress={finish} /> : null}
      </View>
      {last ? (
        <ScrollView contentContainerStyle={{ padding: 24, gap: 16 }}>
          <AppText variant="display" accessibilityRole="header">
            What do you want to read?
          </AppText>
          <AppText color="muted">Pick a few topics. They come first on Home, and you can change them in Profile.</AppText>
          <TopicPicker selected={interests} onChange={setInterests} />
        </ScrollView>
      ) : (
        <View style={styles.slide}>
          <View style={[styles.icon, { backgroundColor: p.accentSoft }]}>
            <Ionicons name={INTRO[index].icon} size={56} color={p.accentText} />
          </View>
          <AppText variant="display" style={{ textAlign: 'center' }} accessibilityRole="header">
            {INTRO[index].title}
          </AppText>
          <AppText color="muted" style={{ textAlign: 'center' }}>
            {INTRO[index].body}
          </AppText>
        </View>
      )}
      <View style={{ paddingHorizontal: 24 }}>
        <Button label={last ? 'Start reading' : 'Next'} onPress={() => (last ? finish() : setIndex(index + 1))} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, minHeight: 56 },
  dots: { flexDirection: 'row', gap: 6 },
  dot: { height: 8, borderRadius: 4 },
  slide: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32, gap: 16 },
  icon: { width: 120, height: 120, borderRadius: 60, alignItems: 'center', justifyContent: 'center', marginBottom: 16 },
});
