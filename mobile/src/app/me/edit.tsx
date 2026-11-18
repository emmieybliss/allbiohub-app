import { Stack, router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, ScrollView, View } from 'react-native';
import { Field } from '@/components/Field';
import { AppText, Button } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate, UserAvatar } from '@/features/community/components';
import { showCommunityError } from '@/features/community/gate';
import { useSession } from '@/features/community/store';
import { pickImage } from '@/features/community/pickImage';
import { usePalette } from '@/theme';

function EditProfile() {
  const p = usePalette();
  const profile = useSession((s) => s.profile);
  const [name, setName] = useState(profile?.displayName ?? '');
  const [bio, setBio] = useState(profile?.bio ?? '');
  const [busy, setBusy] = useState(false);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [nameError, setNameError] = useState<string | null>(null);
  const { api } = community();

  async function photo(remove: boolean) {
    const picked = remove ? null : await pickImage(true);
    if (!remove && !picked) return;
    setPhotoBusy(true);
    try {
      if (picked) await api.setProfilePhoto(picked.uri, picked.type);
      else await api.removeProfilePhoto();
    } catch (e) {
      showCommunityError(e);
    } finally {
      setPhotoBusy(false);
    }
  }

  async function save() {
    if (!name.trim()) {
      setNameError('Enter your name');
      return;
    }
    setBusy(true);
    try {
      await api.updateProfile({ displayName: name.trim(), bio: bio.trim() });
      router.back();
    } catch (e) {
      showCommunityError(e);
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView style={{ backgroundColor: p.background }} contentContainerStyle={{ padding: 24, gap: 16 }} keyboardShouldPersistTaps="handled">
      <Stack.Screen options={{ title: 'Edit profile', headerRight: () => <Button kind="text" label="Save" onPress={save} loading={busy} /> }} />
      <View style={{ alignItems: 'center', gap: 8 }}>
        <View style={{ alignItems: 'center', justifyContent: 'center' }}>
          <UserAvatar name={profile?.displayName} photoUrl={profile?.photoUrl} size={96} />
          {photoBusy ? <ActivityIndicator style={{ position: 'absolute' }} color={p.accentText} /> : null}
        </View>
        <View style={{ flexDirection: 'row' }}>
          <Button kind="text" label="Change picture" onPress={() => photo(false)} disabled={photoBusy} />
          {profile?.photoUrl ? <Button kind="text" label="Remove" onPress={() => photo(true)} disabled={photoBusy} /> : null}
        </View>
      </View>
      <Field label="Display name" value={name} onChangeText={setName} maxLength={50} autoCapitalize="words" error={nameError} />
      <Field label="Bio" value={bio} onChangeText={setBio} maxLength={160} multiline placeholder="Technology enthusiast" helper={`${bio.length}/160`} />
      <AppText variant="bodySmall" color="muted">
        Your profile shows your name, username, picture, bio and when you joined. Your email is never shown.
      </AppText>
    </ScrollView>
  );
}

export default function EditProfileScreen() {
  return (
    <FeatureGate feature="accounts">
      <EditProfile />
    </FeatureGate>
  );
}
