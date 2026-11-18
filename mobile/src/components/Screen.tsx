import { router } from 'expo-router';
import type { ReactNode } from 'react';
import { Image, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { usePalette } from '@/theme';
import { AppText, IconButton } from './ui';

/** Large title bar for the tab screens, with the search button. */
export function TabHeader({ title, logo, right }: { title: string; logo?: boolean; right?: ReactNode }) {
  const insets = useSafeAreaInsets();
  const p = usePalette();
  return (
    <View style={[styles.header, { paddingTop: insets.top + 8, backgroundColor: p.background }]}>
      {logo ? (
        <View style={styles.brand} accessibilityRole="header" accessibilityLabel="AllBioHub">
          <Image source={require('../../assets/images/logo-mark.png')} style={styles.logo} />
          <AppText variant="headline">
            AllBio<AppText variant="headline" color="highlight">Hub</AppText>
          </AppText>
        </View>
      ) : (
        <AppText variant="headline" accessibilityRole="header" style={{ flex: 1 }}>
          {title}
        </AppText>
      )}
      {right}
      <IconButton icon="search" label="Search" onPress={() => router.push('/search')} />
    </View>
  );
}

export function Row({ children, onPress, label }: { children: ReactNode; onPress?: () => void; label?: string }) {
  const p = usePalette();
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole={onPress ? 'button' : undefined}
      accessibilityLabel={label}
      style={({ pressed }) => [styles.row, { backgroundColor: pressed && onPress ? p.accentSoft : 'transparent' }]}
    >
      {children}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 8, gap: 4 },
  brand: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8 },
  logo: { width: 32, height: 32 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 16, minHeight: 56, paddingVertical: 10 },
});
