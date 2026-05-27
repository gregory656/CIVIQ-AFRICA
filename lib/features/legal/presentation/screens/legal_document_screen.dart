import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/legal_repository.dart';

enum LegalDocument {
  privacyPolicy,
  terms,
  communityGuidelines,
  faq,
  about,
  appeals,
  contact,
}

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
                'SIVIQ collects account details such as email, username, SIVIQ code, county, sub-county, profile image URL, and app activity needed to operate SIVIQ features.',
          ),
          _LegalSection(
            title: 'Why We Collect It',
            body:
                'We use this information to verify accounts, reduce abuse, personalize local SIVIQ content, secure your account, and support moderation, appeals, and recovery.',
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
                'Post real SIVIQ projects, photos, ratings, comments, and local observations. Keep discussion factual, local, and respectful.',
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
    case LegalDocument.faq:
      return const _LegalContent(
        title: 'FAQ',
        sections: [
          _LegalSection(
            title: 'What Is SIVIQ?',
            body:
                'SIVIQ is an independent civic community platform for sharing local issues, project updates, ideas, and public conversations.',
          ),
          _LegalSection(
            title: 'Is SIVIQ A Government App?',
            body:
                'No. SIVIQ is an independent civic platform and is not affiliated with any government institution.',
          ),
          _LegalSection(
            title: 'How Do Posts Work?',
            body:
                'People can post local updates, ask questions, share civic ideas, and discuss what is happening around them.',
          ),
          _LegalSection(
            title: 'How Do Project Posts Work?',
            body:
                'Project posts help communities document public works, stalled projects, completed work, and local concerns with context and evidence where possible.',
          ),
          _LegalSection(
            title: 'How Do I Report Harmful Content?',
            body:
                'Use the three-dot menu on a post, project, comment, or profile where available. Reports may lead to review, hiding, removal, or account action.',
          ),
          _LegalSection(
            title: 'What If My Account Is Suspended?',
            body:
                'Open Appeals from the menu and send your username, contact details, and a short explanation through WhatsApp or email.',
          ),
        ],
      );
    case LegalDocument.about:
      return const _LegalContent(
        title: 'About SIVIQ',
        sections: [
          _LegalSection(
            title: 'Our Purpose',
            body:
                'SIVIQ is a civic community platform built to help people share local issues, projects, ideas, and public updates in one place.',
          ),
          _LegalSection(
            title: 'What You Can Do',
            body:
                'You can create community posts, follow profiles, discuss local civic matters, share project updates, and report unsafe or harmful content.',
          ),
          _LegalSection(
            title: 'Independence',
            body:
                'SIVIQ is independent and is not affiliated with any government institution, county office, elected leader, or public agency.',
          ),
          _LegalSection(
            title: 'Contact',
            body: 'WhatsApp: +254719637416\nEmail: gregorysteve656@gmail.com',
          ),
        ],
      );
    case LegalDocument.appeals:
      return const _LegalContent(
        title: 'Appeals',
        sections: [
          _LegalSection(
            title: 'When To Appeal',
            body:
                'Use appeals if your account was suspended, your content was removed, or you believe a moderation restriction was applied unfairly.',
          ),
          _LegalSection(
            title: 'What To Include',
            body:
                'Include your username, phone or email, the affected post or account, and a short explanation of why you believe the decision should be reviewed.',
          ),
          _LegalSection(
            title: 'Send Your Appeal',
            body: 'WhatsApp: +254719637416\nEmail: gregorysteve656@gmail.com',
          ),
          _LegalSection(
            title: 'Fair Use',
            body:
                'Abusive appeals, threats, spam, or false information may be ignored.',
          ),
        ],
      );
    case LegalDocument.contact:
      return const _LegalContent(
        title: 'Contact SIVIQ',
        sections: [
          _LegalSection(
            title: 'Support',
            body: 'WhatsApp: +254719637416\nEmail: gregorysteve656@gmail.com',
          ),
          _LegalSection(
            title: 'Report An Issue',
            body:
                'When reporting a problem, include your username, what you were doing, and any error message you saw.',
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
