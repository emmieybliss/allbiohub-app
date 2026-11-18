import { Ionicons } from '@expo/vector-icons';
import { Tabs } from 'expo-router/js-tabs';
import { fonts, usePalette } from '@/theme';

type Icon = keyof typeof Ionicons.glyphMap;

const TABS: { name: string; title: string; icon: Icon; active: Icon }[] = [
  { name: 'index', title: 'Home', icon: 'home-outline', active: 'home' },
  { name: 'discover', title: 'Discover', icon: 'compass-outline', active: 'compass' },
  { name: 'startups', title: 'Startups', icon: 'rocket-outline', active: 'rocket' },
  { name: 'saved', title: 'Saved', icon: 'bookmark-outline', active: 'bookmark' },
  { name: 'profile', title: 'Profile', icon: 'person-circle-outline', active: 'person-circle' },
];

export default function TabsLayout() {
  const p = usePalette();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: p.accentText,
        tabBarInactiveTintColor: p.subtle,
        tabBarStyle: { backgroundColor: p.surface, borderTopColor: p.border },
        tabBarLabelStyle: { fontFamily: fonts.medium, fontSize: 11 },
        sceneStyle: { backgroundColor: p.background },
      }}
    >
      {TABS.map((t) => (
        <Tabs.Screen
          key={t.name}
          name={t.name}
          options={{
            title: t.title,
            tabBarIcon: ({ focused, color, size }) => <Ionicons name={focused ? t.active : t.icon} color={color as string} size={size} />,
          }}
        />
      ))}
    </Tabs>
  );
}
