import { Stack, useLocalSearchParams } from 'expo-router';
import { ActivityIndicator } from 'react-native';
import { useStartup } from '@/api/queries';
import { ErrorView } from '@/components/ui';
import { community } from '@/features/community/api';
import { FeatureGate } from '@/features/community/components';
import { SubmissionForm, useForm } from '@/features/community/SubmissionForm';
import type { Startup } from '@/models/types';
import { usePalette } from '@/theme';

/** A founder's or team member's claim on a startup profile. Editors check it; a claim never marks the startup verified. */
function ClaimForm({ startup }: { startup: Startup }) {
  const form = useForm({
    name: { label: 'Your full name', min: 2, max: 100 },
    role: { label: 'Your role', hint: 'e.g. Co-founder, CEO', min: 2, max: 100 },
    email: { label: 'Company email', hint: 'An address at the startup’s own domain helps', kind: 'email', min: 3 },
    linkedin: { label: 'Your LinkedIn', kind: 'url', max: 500 },
    info: { label: 'How can editors confirm you work there?', max: 2000, lines: 4 },
  });
  return (
    <SubmissionForm
      intro={`Work at ${startup.name}? Ask the editors to connect you to this profile so you can help keep it accurate.`}
      validate={form.validate}
      submit={() =>
        community().api.claimStartup({
          startupSlug: startup.slug,
          startupName: startup.name,
          name: form.text('name'),
          role: form.text('role'),
          companyEmail: form.text('email'),
          linkedin: form.opt('linkedin'),
          verificationInfo: form.text('info'),
        })
      }
    >
      {(['name', 'role', 'email', 'linkedin', 'info'] as const).map(form.field)}
    </SubmissionForm>
  );
}

function Claim() {
  const p = usePalette();
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const q = useStartup(slug);
  if (q.isPending) return <ActivityIndicator style={{ marginTop: 40 }} color={p.accentText} />;
  if (q.isError || !q.data) return <ErrorView error={q.error} onRetry={() => q.refetch()} />;
  return (
    <>
      <Stack.Screen options={{ title: `Claim ${q.data.name}` }} />
      <ClaimForm startup={q.data} />
    </>
  );
}

export default function ClaimStartupScreen() {
  return (
    <FeatureGate feature="startupClaims">
      <Stack.Screen options={{ title: 'Claim this startup' }} />
      <Claim />
    </FeatureGate>
  );
}
