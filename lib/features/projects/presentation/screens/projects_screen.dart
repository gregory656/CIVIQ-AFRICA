import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../features/locations/data/location_repository.dart';
import '../../../../features/profile/data/profile_repository.dart';
import '../../../../shared/models/kenya_location.dart';
import '../../data/project_repository.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CIVIQ Projects'),
        actions: [
          IconButton(
            tooltip: 'Create project',
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProjectError(error: error),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(projectsProvider),
          child: items.isEmpty
              ? const _EmptyProjects()
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return ProjectFeedCard(project: items[index]);
                  },
                ),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
    );
  }
}

class ProjectFeedCard extends ConsumerWidget {
  const ProjectFeedCard({super.key, required this.project});

  final CiviqProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProjectDetailScreen(project: project),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectThumb(url: project.imageUrl),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _CompactStatus(type: project.projectType),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        project.countyName,
                        project.subcountyName,
                      ].whereType<String>().join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.description?.trim().isNotEmpty == true
                          ? project.description!
                          : 'No description provided.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(project.approvalCount.toString()),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.thumb_down_alt_outlined,
                          size: 16,
                          color: AppColors.dangerRed,
                        ),
                        const SizedBox(width: 4),
                        Text(project.disapprovalCount.toString()),
                        const Spacer(),
                        Text(
                          project.verificationStatus.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  String _type = 'ongoing';
  KenyaCounty? _county;
  KenyaSubcounty? _subcounty;
  XFile? _image;
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final locations = ref.watch(governanceLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Project')),
      body: locations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _form(context, kenyaCounties, profile),
        data: (counties) => _form(context, counties, profile),
      ),
    );
  }

  Widget _form(
    BuildContext context,
    List<KenyaCounty> counties,
    CiviqProfile? profile,
  ) {
    _county ??= _findCounty(counties, profile?.countyId) ?? counties.first;
    _subcounty ??=
        _findSubcounty(_county, profile?.subcountyId) ??
        _county!.subcounties.first;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ongoing', label: Text('Ongoing')),
            ButtonSegment(value: 'completed', label: Text('Completed')),
            ButtonSegment(value: 'stalled', label: Text('Stalled')),
            ButtonSegment(value: 'excellent', label: Text('Excellent')),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() => _type = value.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            prefixIcon: Icon(Icons.title),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Description',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 12),
        _ReadonlyPicker(
          label: 'County',
          value: _county?.name ?? '',
          icon: Icons.location_on_outlined,
          onTap: () async {
            final county = await _chooseCounty(context, counties);
            if (county == null) return;
            setState(() {
              _county = county;
              _subcounty = county.subcounties.first;
            });
          },
        ),
        const SizedBox(height: 12),
        _ReadonlyPicker(
          label: 'Sub-county / Constituency',
          value: _subcounty?.name ?? '',
          icon: Icons.map_outlined,
          onTap: () async {
            final subcounty = await _chooseSubcounty(
              context,
              _county?.subcounties ?? const [],
            );
            if (subcounty != null) setState(() => _subcounty = subcounty);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_image == null ? 'Add evidence image' : 'Change image'),
        ),
        if (_image != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_image!.path),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          onChanged: (value) => setState(() => _confirmed = value ?? false),
          title: const Text(
            'I confirm this information is accurate to my knowledge.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.dangerRed)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'Submitting civic report...' : 'Submit'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image != null) setState(() => _image = image);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Add a project title.');
      return;
    }
    if (!_confirmed) {
      setState(() => _error = 'Confirm the report accuracy before submitting.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await ref
            .read(cloudinaryServiceProvider)
            .uploadMedia(File(_image!.path), folder: 'civiq/projects');
      }
      await ref
          .read(projectRepositoryProvider)
          .createProject(
            CreateProjectInput(
              title: title,
              description: _descriptionController.text.trim(),
              projectType: _type,
              countyId: _county?.id,
              subcountyId: _subcounty?.id,
              locationName: _locationController.text.trim(),
              imageUrl: imageUrl,
              confirmedAccuracy: _confirmed,
            ),
          );
      ref.invalidate(projectsProvider);
      ref.invalidate(localProjectFeedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<KenyaCounty?> _chooseCounty(
    BuildContext context,
    List<KenyaCounty> counties,
  ) {
    return showModalBottomSheet<KenyaCounty>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: counties
            .map(
              (county) => ListTile(
                title: Text(county.name),
                subtitle: Text('${county.subcounties.length} constituencies'),
                onTap: () => Navigator.of(context).pop(county),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<KenyaSubcounty?> _chooseSubcounty(
    BuildContext context,
    List<KenyaSubcounty> subcounties,
  ) {
    return showModalBottomSheet<KenyaSubcounty>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        children: subcounties
            .map(
              (subcounty) => ListTile(
                title: Text(subcounty.name),
                subtitle: Text(
                  subcounty.mpName == null
                      ? 'MP details pending'
                      : 'MP: ${subcounty.mpName}',
                ),
                onTap: () => Navigator.of(context).pop(subcounty),
              ),
            )
            .toList(),
      ),
    );
  }

  KenyaCounty? _findCounty(List<KenyaCounty> counties, int? id) {
    if (id == null) return null;
    for (final county in counties) {
      if (county.id == id) return county;
    }
    return null;
  }

  KenyaSubcounty? _findSubcounty(KenyaCounty? county, int? id) {
    if (county == null || id == null) return null;
    for (final subcounty in county.subcounties) {
      if (subcounty.id == id) return subcounty;
    }
    return null;
  }
}

class _ReadonlyPicker extends StatelessWidget {
  const _ReadonlyPicker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.expand_more),
      ),
      onTap: onTap,
    );
  }
}

class _ProjectThumb extends StatelessWidget {
  const _ProjectThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 92,
        height: 132,
        color: AppColors.background,
        child: const Icon(Icons.image_outlined, color: AppColors.grey),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      width: 92,
      height: 132,
      fit: BoxFit.cover,
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'completed' || 'excellent' => AppColors.success,
      'stalled' => AppColors.dangerRed,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.work_outline, size: 62, color: AppColors.primaryGreen),
        SizedBox(height: 12),
        Text(
          'No project reports yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}

class _ProjectError extends StatelessWidget {
  const _ProjectError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load projects: $error'),
      ),
    );
  }
}
