import { Stack } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { Field } from '@/components/Field';
import { AppText, Button, Divider } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate } from '@/features/community/components';
import { ImageField, SubmissionForm, uploadImage, useForm, validateField } from '@/features/community/SubmissionForm';

type Founder = { name: string; role: string; linkedin: string };

/** A startup for the directory; editors add it to the website after review. */
function SubmitStartup() {
  const [logo, setLogo] = useState<{ uri: string; type: string } | null>(null);
  const [founders, setFounders] = useState<Founder[]>([{ name: '', role: '', linkedin: '' }]);
  const [founderErrors, setFounderErrors] = useState<Record<number, string>>({});
  const form = useForm({
    name: { label: 'Startup name', min: 2, max: 100 },
    description: { label: 'Description', hint: 'What the startup does and who it serves', min: 30, max: 5000, lines: 6 },
    website: { label: 'Website', kind: 'url', max: 500 },
    industry: { label: 'Industry', min: 2, max: 60 },
    country: { label: 'Country', min: 2, max: 60 },
    city: { label: 'City', max: 60 },
    year: { label: 'Year founded', kind: 'year' },
    model: { label: 'Business model', hint: 'e.g. B2B, B2C', max: 60 },
    stage: { label: 'Stage', hint: 'e.g. Seed, Series A', max: 60 },
    funding: { label: 'Funding raised', max: 100 },
    employees: { label: 'Employees', hint: 'e.g. 11-50', max: 30 },
    linkedin: { label: 'Company LinkedIn', kind: 'url', max: 500 },
    x: { label: 'X (Twitter)', kind: 'url', max: 500 },
    email: { label: 'Contact email', hint: 'Leave empty to use your account email', kind: 'email' },
  });

  const setFounder = (i: number, change: Partial<Founder>) => setFounders((list) => list.map((f, j) => (j === i ? { ...f, ...change } : f)));

  const validate = () => {
    const errors: Record<number, string> = {};
    founders.forEach((f, i) => {
      const e = validateField({ label: 'LinkedIn', kind: 'url', max: 500 }, f.linkedin) ?? validateField({ label: 'Founder name', max: 100 }, f.name);
      if (e) errors[i] = e;
    });
    setFounderErrors(errors);
    return form.validate() && Object.keys(errors).length === 0;
  };

  const submit = async () => {
    const social: Record<string, string> = {};
    if (form.opt('linkedin')) social.linkedin = form.text('linkedin');
    if (form.opt('x')) social.x = form.text('x');
    return community().api.submitStartup({
      name: form.text('name'),
      description: form.text('description'),
      website: form.opt('website'),
      country: form.text('country'),
      city: form.text('city'),
      industry: form.text('industry'),
      foundedYear: form.opt('year'),
      businessModel: form.text('model'),
      stage: form.text('stage'),
      funding: form.text('funding'),
      employees: form.text('employees'),
      founders: founders
        .filter((f) => f.name.trim())
        .map((f) => ({ name: f.name.trim(), role: f.role.trim(), linkedin: f.linkedin.trim() || null })),
      social,
      logoPath: await uploadImage(logo),
      contactEmail: form.opt('email'),
    });
  };

  return (
    <SubmissionForm intro="Tell us about an African startup that should be in the directory." validate={validate} submit={submit}>
      {(['name', 'description', 'website', 'industry', 'country', 'city', 'year', 'model', 'stage', 'funding', 'employees'] as const).map(form.field)}
      <AppText variant="subtitle" style={{ marginTop: 8 }}>
        Founders
      </AppText>
      {founders.map((f, i) => (
        <View key={i} style={{ gap: 14 }}>
          {i > 0 ? <Divider /> : null}
          <Field label="Founder name" value={f.name} onChangeText={(name) => setFounder(i, { name })} autoCapitalize="words" />
          <Field label="Role" placeholder="e.g. CEO" value={f.role} onChangeText={(role) => setFounder(i, { role })} />
          <Field
            label="LinkedIn"
            value={f.linkedin}
            onChangeText={(linkedin) => setFounder(i, { linkedin })}
            keyboardType="url"
            autoCapitalize="none"
            error={founderErrors[i]}
          />
        </View>
      ))}
      {founders.length < 10 ? (
        <Button
          kind="text"
          icon="add"
          label="Add another founder"
          style={{ alignSelf: 'flex-start' }}
          onPress={() => setFounders((list) => [...list, { name: '', role: '', linkedin: '' }])}
        />
      ) : null}
      <AppText variant="subtitle" style={{ marginTop: 8 }}>
        Links
      </AppText>
      {form.field('linkedin')}
      {form.field('x')}
      <ImageField label="Add a logo" value={logo} onChange={setLogo} />
      {form.field('email')}
    </SubmissionForm>
  );
}

export default function SubmitStartupScreen() {
  return (
    <FeatureGate feature="startupSubmissions">
      <Stack.Screen options={{ title: 'Submit a startup' }} />
      <SubmitStartup />
    </FeatureGate>
  );
}
