import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/legal_repository.dart';

enum LegalDocument { privacyPolicy, terms, communityGuidelines }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final content = _content(document);
    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              content.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Version $currentPolicyVersion',
              style: const TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 20),
            for (final section in content.sections) ...[
              Text(
                section.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(section.body),
              const SizedBox(height: 18),
            ],
            const Text(
              'version 1.0.0',
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

_LegalContent _content(LegalDocument document) {
  switch (document) {
    case LegalDocument.privacyPolicy:
      return const _LegalContent(
        title: 'Privacy Policy',
        sections: [
          _LegalSection(
            title: 'Data We Collect',
            body:
                'SIVIQ collects account details such as email, username, SIVIQ code, county, sub-county, profile image URL, and app activity needed to operate civic features.',
          ),
          _LegalSection(
            title: 'Why We Collect It',
            body:
                'We use this information to verify accounts, reduce abuse, personalize local civic content, secure your account, and support moderation, appeals, and recovery.',
          ),
          _LegalSection(
            title: 'Location And Identity',
            body:
                'County and sub-county selections are used for local relevance. Full email addresses are not shown publicly. Public profile identity should use your username and SIVIQ code.',
          ),
          _LegalSection(
            title: 'Your Choices',
            body:
                'You can request data export or account deletion from Settings. Deletion may use a recovery period before permanent purge to protect against mistakes and disputes.',
          ),
          _LegalSection(
            title: 'Kenya Data Protection',
            body:
                'SIVIQ is designed to follow the Kenya Data Protection Act 2019, including purpose limitation, access control, and user data rights.',
          ),
        ],
      );
    case LegalDocument.terms:
      return const _LegalContent(
        title: 'Terms of Service',
        sections: [
          _LegalSection(
            title: 'User-Generated Content',
            body:
                'Posts, ratings, comments, and reports are created by users. SIVIQ does not guarantee that user submissions are true, complete, or official.',
          ),
          _LegalSection(
            title: 'No Government Affiliation',
            body:
                'SIVIQ is not affiliated with, endorsed by, or approved by the Government of Kenya, county governments, elected officials, or public agencies.',
          ),
          _LegalSection(
            title: 'Accuracy',
            body:
                'Users are responsible for posting truthful information. Posts without evidence such as photos, location, or sources may be marked unverified or given lower ranking weight.',
          ),
          _LegalSection(
            title: 'Liability',
            body:
                'You are responsible for your posts and comments. SIVIQ may remove reported content that violates these terms or community guidelines.',
          ),
          _LegalSection(
            title: 'Right of Reply',
            body:
                'Public leaders and authorized representatives may request verification and respond to ratings or project reports through the app process.',
          ),
        ],
      );
    case LegalDocument.communityGuidelines:
      return const _LegalContent(
        title: 'Community Guidelines',
        sections: [
          _LegalSection(
            title: 'What Is Allowed',
            body:
                'Post real civic projects, photos, ratings, comments, and local observations. Keep discussion factual, local, and respectful.',
          ),
          _LegalSection(
            title: 'What Is Not Allowed',
            body:
                'Fake projects, fake photos, spam, fraud, pornography, hate speech, incitement to violence, betting content, and coordinated rating manipulation are not allowed.',
          ),
          _LegalSection(
            title: 'Defamation And Proof',
            body:
                'Do not make serious accusations without evidence. Claims about corruption, theft, or criminal conduct should include a source, location, or supporting material.',
          ),
          _LegalSection(
            title: 'Enforcement',
            body:
                'Reported posts may be hidden, reviewed, removed, or escalated. Repeated false or abusive activity can lead to account restrictions or bans.',
          ),
          _LegalSection(
            title: 'Your Responsibility',
            body:
                'You are responsible for what you post. If you are unsure whether something is true, do not publish it as fact.',
          ),
        ],
      );
  }
}

class _LegalContent {
  const _LegalContent({required this.title, required this.sections});

  final String title;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}
