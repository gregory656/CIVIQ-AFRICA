import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _bioController = TextEditingController();
  final _picker = ImagePicker();
  File? _image;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 74,
    );
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _save(CiviqProfile profile) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw Exception('You need to sign in again.');

      String? avatarUrl;
      if (_image != null) {
        avatarUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadMedia(_image!);
      }

      await ref
          .read(profileRepositoryProvider)
          .upsertProfile(
            userId: user.id,
            email: user.email ?? profile.email,
            bio: _bioController.text.trim(),
            avatarUrl: avatarUrl,
          );
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        context.pop();
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found.'));
            }
            if (!_loaded) {
              _bioController.text = profile.bio ?? '';
              _loaded = true;
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _saving ? null : _pickImage,
                    child: _EditableAvatar(
                      file: _image,
                      url: profile.avatarUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Change profile picture'),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _bioController,
                  maxLines: 5,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.dangerRed),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : () => _save(profile),
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.file, required this.url});

  final File? file;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppColors.border,
          backgroundImage: file == null ? null : FileImage(file!),
          child: file == null ? _NetworkOrEmptyAvatar(url: imageUrl) : null,
        ),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }
}

class _NetworkOrEmptyAvatar extends StatelessWidget {
  const _NetworkOrEmptyAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Icon(Icons.person_outline, size: 42);
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) =>
            const Icon(Icons.person_outline, size: 42),
      ),
    );
  }
}
