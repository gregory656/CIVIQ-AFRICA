import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';

class AvatarUploadScreen extends ConsumerStatefulWidget {
  const AvatarUploadScreen({super.key});

  @override
  ConsumerState<AvatarUploadScreen> createState() => _AvatarUploadScreenState();
}

class _AvatarUploadScreenState extends ConsumerState<AvatarUploadScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 86,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _upload() async {
    if (_image == null) {
      context.go('/civiq-code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('You need to sign in again.');

      final url = await ref
          .read(cloudinaryServiceProvider)
          .uploadMedia(_image!);
      await ref
          .read(profileRepositoryProvider)
          .upsertProfile(
            userId: user.id,
            email: user.email ?? '',
            avatarUrl: url,
          );
      ref.invalidate(currentProfileProvider);

      if (mounted) context.go('/civiq-code');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Picture')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 86,
                  backgroundColor: AppColors.border,
                  backgroundImage: _image == null ? null : FileImage(_image!),
                  child: _image == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 42)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upload a profile pic.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can always change this later in settings',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.dangerRed),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Pic a photo'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _loading ? null : _upload,
                child: Text(_loading ? 'Uploading...' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
