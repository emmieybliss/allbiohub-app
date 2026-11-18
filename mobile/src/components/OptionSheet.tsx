import { Ionicons } from '@expo/vector-icons';
import { Modal, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { create } from 'zustand';
import { radius, usePalette } from '@/theme';
import { AppText } from './ui';

export type SheetOption<T extends string> = { value: T; label: string; icon?: keyof typeof Ionicons.glyphMap; danger?: boolean };

type SheetState = {
  title?: string;
  options: SheetOption<string>[];
  resolve: ((value: string | null) => void) | null;
};

const useSheet = create<SheetState>(() => ({ options: [], resolve: null }));

/** Shows a list of choices from the bottom of the screen. Resolves with the choice, or null when closed. */
export function pickOption<T extends string>(options: SheetOption<T>[], title?: string): Promise<T | null> {
  useSheet.getState().resolve?.(null);
  return new Promise((resolve) => {
    useSheet.setState({ title, options, resolve: resolve as (v: string | null) => void });
  });
}

function close(value: string | null) {
  const { resolve } = useSheet.getState();
  useSheet.setState({ resolve: null });
  resolve?.(value);
}

/** Mounted once in the root layout. */
export function OptionSheetHost() {
  const p = usePalette();
  const insets = useSafeAreaInsets();
  const { title, options, resolve } = useSheet();
  return (
    <Modal visible={resolve !== null} transparent animationType="fade" onRequestClose={() => close(null)}>
      <Pressable style={styles.backdrop} onPress={() => close(null)} accessibilityLabel="Close" />
      <View style={[styles.sheet, { backgroundColor: p.surface, paddingBottom: 12 + insets.bottom }]}>
        {title ? (
          <AppText variant="title" style={{ paddingHorizontal: 20, paddingVertical: 12 }}>
            {title}
          </AppText>
        ) : null}
        {options.map((o) => (
          <Pressable
            key={o.value}
            onPress={() => close(o.value)}
            accessibilityRole="button"
            style={({ pressed }) => [styles.option, { backgroundColor: pressed ? p.accentSoft : 'transparent' }]}
          >
            {o.icon ? <Ionicons name={o.icon} size={22} color={o.danger ? p.danger : p.text} /> : null}
            <AppText color={o.danger ? p.danger : 'text'}>{o.label}</AppText>
          </Pressable>
        ))}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(0,0,0,0.4)' },
  sheet: { position: 'absolute', left: 0, right: 0, bottom: 0, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, paddingTop: 8 },
  option: { flexDirection: 'row', alignItems: 'center', gap: 16, paddingHorizontal: 20, minHeight: 52 },
});
