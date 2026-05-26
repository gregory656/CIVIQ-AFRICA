import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/widgets/verified_badge.dart';
import '../../data/models/chat_models.dart';
import '../../data/repositories/chat_repository.dart';
import '../widgets/chat_avatar.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Map<String, ChatProfileResult> _selected = {};
  Timer? _debounce;
  String _query = '';
  File? _photo;
  bool _setupStep = false;
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_setupStep ? 'Group Setup' : 'Select Members'),
      ),
      body: _setupStep ? _buildSetup() : _buildSelector(),
      bottomNavigationBar: _setupStep
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(() => _setupStep = true),
                  child: Text('Next (${_selected.length}/49)'),
                ),
              ),
            ),
    );
  }

  Widget _buildSelector() {
    final results = ref.watch(chatSearchProvider(_query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search username or SIVIQ code',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (_selected.isNotEmpty)
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _selected.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final member = _selected.values.elementAt(index);
                return InputChip(
                  avatar: CircleAvatar(
                    backgroundImage: member.avatarUrl == null
                        ? null
                        : NetworkImage(member.avatarUrl!),
                    child: member.avatarUrl == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  label: Text(member.username ?? 'SIVIQ Member'),
                  onDeleted: () => setState(() => _selected.remove(member.id)),
                );
              },
            ),
          ),
        Expanded(
          child: _query.length < 2
              ? const Center(child: Text('Type at least 2 characters.'))
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Could not search users: $error')),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = _selected.containsKey(item.id);
                        return CheckboxListTile(
                          value: selected,
                          secondary: ChatAvatar(imageUrl: item.avatarUrl),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (item.isVerified) ...[
                                const SizedBox(width: 4),
                                const CiviqVerifiedBadge(size: 15),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            item.civiqCode ?? item.roleLabel ?? '',
                          ),
                          onChanged: (_) => _toggleMember(item),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSetup() {
    final nameLength = _nameController.text.characters.length;
    return AbsorbPointer(
      absorbing: _creating,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(46),
              onTap: _pickPhoto,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.background,
                    backgroundImage: _photo == null ? null : FileImage(_photo!),
                    child: _photo == null
                        ? const Icon(Icons.groups_outlined, size: 42)
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryGreen,
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nameController,
            maxLength: 50,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              counterText: '',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$nameLength/50',
              style: const TextStyle(color: AppColors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 220,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _creating ? null : _createGroup,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              _creating
                  ? 'Creating your group...\nPlease wait.'
                  : 'Create Group',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _toggleMember(ChatProfileResult item) {
    setState(() {
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else if (_selected.length < 49) {
        _selected[item.id] = item;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Groups are limited to 50 members.')),
        );
      }
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _photo = File(picked.path));
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group name is required.')));
      return;
    }
    setState(() => _creating = true);
    try {
      String? photoUrl;
      final photo = _photo;
      if (photo != null) {
        photoUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadMedia(photo, folder: 'civiq/groups');
      }
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .createGroupConversation(
            title: name,
            description: _descriptionController.text.trim(),
            photoUrl: photoUrl,
            memberIds: _selected.keys.toList(growable: false),
          );
      ref.invalidate(conversationsProvider);
      if (!mounted) return;
      context.go('/chats/$conversationId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create group: $error')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
