import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms Agreement')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before creating your account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'SIVIQ is built for responsible SIVIQ participation. Please agree to the community rules before continuing.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LegalChip(
                    label: 'Privacy Policy',
                    route: '/legal/privacy-policy',
                  ),
                  _LegalChip(label: 'Terms', route: '/legal/terms'),
                  _LegalChip(
                    label: 'Community Guidelines',
                    route: '/legal/community-guidelines',
                  ),
                ],
              ),
              const Spacer(),
              CheckboxListTile(
                value: _accepted,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primaryGreen,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                title: const Text('I agree to Community Guidelines and Terms.'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _accepted
                    ? () => context.go('/auth?mode=signup&acceptedLegal=true')
                    : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalChip extends StatelessWidget {
  const _LegalChip({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: () => context.push(route),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.white,
    );
  }
}
