import { Stack } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { AppText, Chip } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate } from '@/features/community/components';
import { STORY_TYPES, type StoryType } from '@/features/community/models';
import { ImageField, SubmissionForm, uploadImage, useForm } from '@/features/community/SubmissionForm';

/** News tips, funding announcements, launches and press releases. */
function SubmitStory() {
  const [type, setType] = useState<StoryType>('news_tip');
  const [image, setImage] = useState<{ uri: string; type: string } | null>(null);
  const form = useForm({
    title: { label: 'Title', min: 5 },
    description: { label: 'Description', hint: 'What happened, who is involved, and why it matters', min: 20, max: 5000, lines: 8 },
    category: { label: 'Category', hint: 'e.g. Fintech, Funding, Health', max: 100 },
    source: { label: 'Source link', kind: 'url', max: 500 },
    extra: { label: 'Anything else editors should know', max: 3000, lines: 4 },
    email: { label: 'Contact email', hint: 'Leave empty to use your account email', kind: 'email' },
    phone: { label: 'Phone', kind: 'phone', max: 30 },
  });

  const submit = async () =>
    community().api.submitStory({
      type,
      title: form.text('title'),
      description: form.text('description'),
      category: form.text('category'),
      sourceUrl: form.opt('source'),
      additionalInfo: form.text('extra'),
      imagePath: await uploadImage(image),
      contactEmail: form.opt('email'),
      contactPhone: form.text('phone'),
    });

  return (
    <SubmissionForm
      intro="Share news, a funding round, a launch or an announcement with the AllBioHub newsroom."
      validate={form.validate}
      submit={submit}
    >
      <AppText variant="label">Type *</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {STORY_TYPES.map((t) => (
          <Chip key={t.key} label={t.label} selected={type === t.key} onPress={() => setType(t.key)} />
        ))}
      </View>
      {form.field('title')}
      {form.field('description')}
      {form.field('category')}
      {form.field('source')}
      {form.field('extra')}
      <ImageField label="Add an image" value={image} onChange={setImage} />
      {form.field('email')}
      {form.field('phone')}
    </SubmissionForm>
  );
}

export default function SubmitStoryScreen() {
  return (
    <FeatureGate feature="storySubmissions">
      <Stack.Screen options={{ title: 'Submit a story' }} />
      <SubmitStory />
    </FeatureGate>
  );
}
