import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/community/community_providers.dart';
import '../../core/community/feature_flags.dart';
import '../../core/community/models.dart';
import '../../core/models/startup.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/text_utils.dart';
import '../../shared/widgets/state_views.dart';
import '../startups/startup_providers.dart';
import 'community_lists.dart';
import 'community_widgets.dart';

const _received =
    'Your submission has been received and is awaiting editorial review.';

/// Shared shell for the three forms: a scrolling form, a note that editors
/// review everything, and a submit button that signs in first.
class _SubmissionForm extends ConsumerStatefulWidget {
  const _SubmissionForm({
    required this.title,
    required this.intro,
    required this.fields,
    required this.submit,
  });

  final String title;
  final String intro;
  final List<Widget> Function(BuildContext context, bool busy) fields;

  /// Sends the form; returns the server's confirmation message.
  final Future<String> Function() submit;

  @override
  ConsumerState<_SubmissionForm> createState() => _SubmissionFormState();
}

class _SubmissionFormState extends ConsumerState<_SubmissionForm> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await requireAccount(
      context,
      ref,
      profile: false,
      verified: true,
      reason: 'Sign in to send a submission to the AllBioHub editors.',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final message = await widget.submit();
      if (!mounted) return;
      ref.invalidate(mySubmissionsProvider);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined),
          title: const Text('Thank you'),
          content: Text(message.isEmpty ? _received : message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(widget.intro, style: context.text.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Editors review every submission before anything appears on '
              'AllBioHub. Nothing is published automatically.',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 16),
            ...widget.fields(context, _busy),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.min = 0,
    this.max = 200,
    this.lines = 1,
    this.keyboard,
    this.url = false,
    this.email = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int min;
  final int max;
  final int lines;
  final TextInputType? keyboard;
  final bool url;
  final bool email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLength: max > 200 ? max : null,
        maxLines: lines,
        minLines: lines > 1 ? 3 : 1,
        keyboardType:
            keyboard ??
            (url
                ? TextInputType.url
                : email
                ? TextInputType.emailAddress
                : lines > 1
                ? TextInputType.multiline
                : TextInputType.text),
        decoration: InputDecoration(
          labelText: min > 0 ? '$label *' : label,
          hintText: hint,
          alignLabelWithHint: lines > 1,
        ),
        validator: (value) {
          final v = (value ?? '').trim();
          if (v.isEmpty) return min > 0 ? '$label is required.' : null;
          if (v.length < min) return '$label needs at least $min characters.';
          if (v.length > max) return '$label must be at most $max characters.';
          if (url && !_looksLikeUrl(v)) return 'Enter a web address.';
          if (email && !_looksLikeEmail(v)) {
            return 'Enter a valid email address.';
          }
          return null;
        },
      ),
    );
  }
}

bool _looksLikeUrl(String v) {
  final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
  return uri != null && uri.host.contains('.');
}

bool _looksLikeEmail(String v) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

String? _opt(TextEditingController c) {
  final v = c.text.trim();
  return v.isEmpty ? null : v;
}

/// Optional image attached to a submission (a screenshot or a logo).
class _ImageField extends ConsumerStatefulWidget {
  const _ImageField({required this.label, required this.onChanged});

  final String label;
  final ValueChanged<(Uint8List, String)?> onChanged;

  @override
  ConsumerState<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<_ImageField> {
  Uint8List? _bytes;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showMessage(context, 'Choose an image under 5 MB.');
      return;
    }
    final type =
        file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    setState(() => _bytes = bytes);
    widget.onChanged((bytes, type));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (_bytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _bytes!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.image_outlined),
              label: Text(_bytes == null ? widget.label : 'Change image'),
            ),
          ),
          if (_bytes != null)
            IconButton(
              tooltip: 'Remove image',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() => _bytes = null);
                widget.onChanged(null);
              },
            ),
        ],
      ),
    );
  }
}

Future<String?> _upload(WidgetRef ref, (Uint8List, String)? image) async {
  if (image == null) return null;
  return ref
      .read(communityApiProvider)
      .uploadSubmissionImage(image.$1, image.$2);
}

/// News tips, funding announcements, launches and press releases.
class SubmitStoryScreen extends ConsumerStatefulWidget {
  const SubmitStoryScreen({super.key});

  @override
  ConsumerState<SubmitStoryScreen> createState() => _SubmitStoryScreenState();
}

class _SubmitStoryScreenState extends ConsumerState<SubmitStoryScreen> {
  StoryType _type = StoryType.newsTip;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _source = TextEditingController();
  final _extra = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  (Uint8List, String)? _image;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _category,
      _source,
      _extra,
      _email,
      _phone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String> _submit() async {
    final message = await ref.read(communityApiProvider).submitStory({
      'type': _type.key,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'category': _category.text.trim(),
      'sourceUrl': _opt(_source),
      'additionalInfo': _extra.text.trim(),
      'imagePath': await _upload(ref, _image),
      'contactEmail': _opt(_email),
      'contactPhone': _phone.text.trim(),
    });
    ref.read(analyticsProvider).log(AnalyticsEvent.storySubmission, {
      'type': _type.key,
    });
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return _SubmissionForm(
      title: 'Submit a story',
      intro:
          'Share news, a funding round, a launch or an announcement with the '
          'AllBioHub newsroom.',
      submit: _submit,
      fields: (context, busy) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<StoryType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type *'),
            items: [
              for (final t in StoryType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: busy ? null : (t) => setState(() => _type = t ?? _type),
          ),
        ),
        _Field(controller: _title, label: 'Title', min: 5),
        _Field(
          controller: _description,
          label: 'Description',
          hint: 'What happened, who is involved, and why it matters',
          min: 20,
          max: 5000,
          lines: 8,
        ),
        _Field(
          controller: _category,
          label: 'Category',
          hint: 'e.g. Fintech, Funding, Health',
          max: 100,
        ),
        _Field(controller: _source, label: 'Source link', url: true, max: 500),
        _Field(
          controller: _extra,
          label: 'Anything else editors should know',
          max: 3000,
          lines: 4,
        ),
        _ImageField(label: 'Add an image', onChanged: (i) => _image = i),
        _Field(
          controller: _email,
          label: 'Contact email',
          hint: 'Leave empty to use your account email',
          email: true,
        ),
        _Field(
          controller: _phone,
          label: 'Phone',
          keyboard: TextInputType.phone,
          max: 30,
        ),
      ],
    );
  }
}

/// A startup for the directory; editors add it to the website after review.
class SubmitStartupScreen extends ConsumerStatefulWidget {
  const SubmitStartupScreen({super.key});

  @override
  ConsumerState<SubmitStartupScreen> createState() =>
      _SubmitStartupScreenState();
}

class _FounderFields {
  final name = TextEditingController();
  final role = TextEditingController();
  final linkedin = TextEditingController();

  void dispose() {
    name.dispose();
    role.dispose();
    linkedin.dispose();
  }
}

class _SubmitStartupScreenState extends ConsumerState<SubmitStartupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _industry = TextEditingController();
  final _year = TextEditingController();
  final _model = TextEditingController();
  final _stage = TextEditingController();
  final _funding = TextEditingController();
  final _employees = TextEditingController();
  final _linkedin = TextEditingController();
  final _x = TextEditingController();
  final _email = TextEditingController();
  final _founders = [_FounderFields()];
  (Uint8List, String)? _logo;

  List<TextEditingController> get _all => [
    _name,
    _description,
    _website,
    _country,
    _city,
    _industry,
    _year,
    _model,
    _stage,
    _funding,
    _employees,
    _linkedin,
    _x,
    _email,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    for (final f in _founders) {
      f.dispose();
    }
    super.dispose();
  }

  Future<String> _submit() async {
    final message = await ref.read(communityApiProvider).submitStartup({
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'website': _opt(_website),
      'country': _country.text.trim(),
      'city': _city.text.trim(),
      'industry': _industry.text.trim(),
      'foundedYear': _opt(_year),
      'businessModel': _model.text.trim(),
      'stage': _stage.text.trim(),
      'funding': _funding.text.trim(),
      'employees': _employees.text.trim(),
      'founders': [
        for (final f in _founders)
          if (f.name.text.trim().isNotEmpty)
            {
              'name': f.name.text.trim(),
              'role': f.role.text.trim(),
              'linkedin': _opt(f.linkedin),
            },
      ],
      'social': {'linkedin': ?_opt(_linkedin), 'x': ?_opt(_x)},
      'logoPath': await _upload(ref, _logo),
      'contactEmail': _opt(_email),
    });
    ref.read(analyticsProvider).log(AnalyticsEvent.startupSubmission, {
      'industry': _industry.text.trim(),
      'country': _country.text.trim(),
    });
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return _SubmissionForm(
      title: 'Submit a startup',
      intro:
          'Tell us about an African startup that should be in the directory.',
      submit: _submit,
      fields: (context, busy) => [
        _Field(controller: _name, label: 'Startup name', min: 2, max: 100),
        _Field(
          controller: _description,
          label: 'Description',
          hint: 'What the startup does and who it serves',
          min: 30,
          max: 5000,
          lines: 6,
        ),
        _Field(controller: _website, label: 'Website', url: true, max: 500),
        _Field(controller: _industry, label: 'Industry', min: 2, max: 60),
        _Field(controller: _country, label: 'Country', min: 2, max: 60),
        _Field(controller: _city, label: 'City', max: 60),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year founded'),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              final year = int.tryParse(s);
              if (year == null || year < 1900 || year > currentYear) {
                return 'Enter a year between 1900 and $currentYear.';
              }
              return null;
            },
          ),
        ),
        _Field(
          controller: _model,
          label: 'Business model',
          hint: 'e.g. B2B, B2C',
          max: 60,
        ),
        _Field(
          controller: _stage,
          label: 'Stage',
          hint: 'e.g. Seed, Series A',
          max: 60,
        ),
        _Field(controller: _funding, label: 'Funding raised', max: 100),
        _Field(
          controller: _employees,
          label: 'Employees',
          hint: 'e.g. 11-50',
          max: 30,
        ),
        const SizedBox(height: 8),
        Text('Founders', style: context.text.titleMedium),
        const SizedBox(height: 8),
        for (final (i, f) in _founders.indexed) ...[
          if (i > 0) const Divider(height: 24),
          _Field(controller: f.name, label: 'Founder name', max: 100),
          _Field(controller: f.role, label: 'Role', hint: 'e.g. CEO', max: 100),
          _Field(
            controller: f.linkedin,
            label: 'LinkedIn',
            url: true,
            max: 500,
          ),
        ],
        if (_founders.length < 10)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(() => _founders.add(_FounderFields())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another founder'),
            ),
          ),
        const SizedBox(height: 8),
        Text('Links', style: context.text.titleMedium),
        const SizedBox(height: 8),
        _Field(
          controller: _linkedin,
          label: 'Company LinkedIn',
          url: true,
          max: 500,
        ),
        _Field(controller: _x, label: 'X (Twitter)', url: true, max: 500),
        _ImageField(label: 'Add a logo', onChanged: (i) => _logo = i),
        _Field(
          controller: _email,
          label: 'Contact email',
          hint: 'Leave empty to use your account email',
          email: true,
        ),
      ],
    );
  }
}

/// A founder's or team member's claim on a startup profile. Editors check
/// it; a claim alone never marks the startup verified.
class ClaimStartupScreen extends ConsumerStatefulWidget {
  const ClaimStartupScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ClaimStartupScreen> createState() => _ClaimStartupScreenState();
}

class _ClaimStartupScreenState extends ConsumerState<ClaimStartupScreen> {
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _email = TextEditingController();
  final _linkedin = TextEditingController();
  final _info = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _role, _email, _linkedin, _info]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String> _submit(Startup startup) async {
    final message = await ref.read(communityApiProvider).claimStartup({
      'startupSlug': startup.slug,
      'startupName': startup.name,
      'name': _name.text.trim(),
      'role': _role.text.trim(),
      'companyEmail': _email.text.trim(),
      'linkedin': _opt(_linkedin),
      'verificationInfo': _info.text.trim(),
    });
    ref.read(analyticsProvider).log(AnalyticsEvent.startupClaim, {
      'startup_slug': startup.slug,
    });
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(startupProvider(widget.slug));
    return switch (async) {
      AsyncData(value: final startup) => _SubmissionForm(
        title: 'Claim ${startup.name}',
        intro:
            'Work at ${startup.name}? Ask the editors to connect you to this '
            'profile so you can help keep it accurate.',
        submit: () => _submit(startup),
        fields: (context, busy) => [
          _Field(controller: _name, label: 'Your full name', min: 2, max: 100),
          _Field(
            controller: _role,
            label: 'Your role',
            hint: 'e.g. Co-founder, CEO',
            min: 2,
            max: 100,
          ),
          _Field(
            controller: _email,
            label: 'Company email',
            hint: 'An address at the startup\'s own domain helps',
            email: true,
            min: 3,
          ),
          _Field(
            controller: _linkedin,
            label: 'Your LinkedIn',
            url: true,
            max: 500,
          ),
          _Field(
            controller: _info,
            label: 'How can editors confirm you work there?',
            max: 2000,
            lines: 4,
          ),
        ],
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(startupProvider(widget.slug)),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

/// The person's story and startup submissions and claims, with status.
class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final async = ref.watch(mySubmissionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My submissions')),
      body: user == null
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: JoinPrompt(
                title: 'Your submissions',
                message:
                    'Sign in to send stories and startups to the editors '
                    'and follow their review.',
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(mySubmissionsProvider.future),
              child: switch (async) {
                AsyncError(:final error) when !async.isLoading => ListView(
                  children: [
                    ErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(mySubmissionsProvider),
                    ),
                  ],
                ),
                AsyncData(value: final items) when items.isEmpty => ListView(
                  children: [
                    const MessageView(
                      icon: Icons.edit_note_rounded,
                      title: 'No submissions yet',
                      message:
                          'Stories and startups you send to the editors '
                          'show here with their review status.',
                    ),
                    _SubmitActions(),
                  ],
                ),
                AsyncData(value: final items) => ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final s in items) _SubmissionTile(s),
                    _SubmitActions(),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
    );
  }
}

class _SubmitActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(featureProvider(Feature.storySubmissions));
    final startup = ref.watch(featureProvider(Feature.startupSubmissions));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (story)
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.submitStory),
              icon: const Icon(Icons.article_outlined),
              label: const Text('Submit a story'),
            ),
          if (startup)
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.submitStartup),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Submit a startup'),
            ),
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile(this.s);

  final Submission s;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final kind = switch (s.kind) {
      SubmissionKind.story => 'Story',
      SubmissionKind.startup => 'Startup',
      SubmissionKind.claim => 'Claim',
    };
    final positive =
        s.status == SubmissionStatus.accepted ||
        s.status == SubmissionStatus.published ||
        s.status == SubmissionStatus.approved;
    return ListTile(
      leading: Icon(switch (s.kind) {
        SubmissionKind.story => Icons.article_outlined,
        SubmissionKind.startup => Icons.rocket_launch_outlined,
        SubmissionKind.claim => Icons.badge_outlined,
      }),
      title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          [
            kind,
            if (s.createdAt != null) relativeDate(s.createdAt!),
          ].join(' · '),
          if (s.editorNote != null && s.editorNote!.isNotEmpty)
            'Editor: ${s.editorNote}',
        ].join('\n'),
      ),
      isThreeLine: s.editorNote != null && s.editorNote!.isNotEmpty,
      trailing: Chip(
        label: Text(s.status.label),
        visualDensity: VisualDensity.compact,
        backgroundColor: positive ? brand.accentSoft : null,
      ),
    );
  }
}

// Keep the confirmation text in one place for tests.
@visibleForTesting
const submissionReceivedMessage = _received;
