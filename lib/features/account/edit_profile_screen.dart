import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/community/community_exception.dart';
import '../../core/community/community_providers.dart';
import '../../core/theme/app_theme.dart';
import '../community/community_widgets.dart';

/// Edit picture, display name and bio.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  bool _busy = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    _name = TextEditingController(text: profile?.displayName ?? '');
    _bio = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) showMessage(context, 'Choose an image under 5 MB.');
      return;
    }
    final type = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    setState(() => _photoBusy = true);
    try {
      await ref.read(communityApiProvider).setProfilePhoto(bytes, type);
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await ref.read(communityApiProvider).removeProfilePhoto();
    } on Object catch (e) {
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(communityApiProvider)
          .updateProfile(displayName: _name.text.trim(), bio: _bio.text.trim());
      if (mounted) context.pop();
    } on CommunityException catch (e) {
      if (mounted) showCommunityError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  UserAvatar(
                    name: profile?.displayName,
                    photoUrl: profile?.photoUrl,
                    size: 96,
                  ),
                  if (_photoBusy) const CircularProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _photoBusy ? null : _pickPhoto,
                  child: const Text('Change picture'),
                ),
                if (profile?.photoUrl != null)
                  TextButton(
                    onPressed: _photoBusy ? null : _removePhoto,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bio,
              maxLength: 160,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Technology enthusiast',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile shows your name, username, picture, bio and when '
              'you joined. Your email is never shown.',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
