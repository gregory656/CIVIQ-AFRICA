import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: Text(content.title),
        elevation: 0,
        backgroundColor: content.color,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share functionality could be added here
            },
          ),
        ],
      ),
      body: Container(
        color: AppColors.background,
        child: CustomScrollView(
          slivers: [
            // Hero Section
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: content.color,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            content.icon,
                            size: 32,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version $currentPolicyVersion',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (content.subtitle != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        content.subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Content Sections
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final section = content.sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SectionCard(
                        section: section,
                        color: content.color,
                        index: index,
                      ),
                    );
                  },
                  childCount: content.sections.length,
                ),
              ),
            ),
            // Quick Actions
            if (content.quickActions.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...content.quickActions.map((action) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _QuickActionButton(
                              action: action,
                              color: content.color,
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            // Footer
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Last Updated: $currentPolicyVersion',
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SIVIQ © 2026 - Building Better Communities',
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

_LegalContent2 _content(LegalDocument document) {
  switch (document) {
    case LegalDocument.privacyPolicy:
      return _LegalContent2(
        title: 'Privacy Policy',
        color: Colors.green,
        icon: Icons.privacy_tip_outlined,
        subtitle: 'Your data, your rights. Learn how we protect your information.',
        sections: [
          _LegalSection(
            title: '📊 Data We Collect',
            body:
                'SIVIQ collects account details such as email, display name, username, SIVIQ code, county, sub-county, profile image URL, and app activity needed to operate SIVIQ features. We also collect device information for security and performance optimization.',
          ),
          _LegalSection(
            title: '🎯 Why We Collect It',
            body:
                'We use this information to verify accounts, reduce abuse, personalize local SIVIQ content, secure your account, and support moderation, appeals, and recovery. Your data helps us improve the platform and provide relevant local content.',
          ),
          _LegalSection(
            title: '📍 Location And Identity',
            body:
                'County and sub-county selections are used for local relevance. Full email addresses are not shown publicly. Public profile identity can show your display name, username, and SIVIQ code. You control what information is visible to others.',
          ),
          _LegalSection(
            title: '✨ Your Choices',
            body:
                'You can request data export or account deletion from Settings. Deletion may use a recovery period before permanent purge to protect against mistakes and disputes. You can also update your profile information and privacy settings at any time.',
          ),
          _LegalSection(
            title: '🇰🇪 Kenya Data Protection',
            body:
                'SIVIQ is designed to follow the Kenya Data Protection Act 2019, including purpose limitation, access control, and user data rights. We implement industry-standard security measures to protect your personal information.',
          ),
          _LegalSection(
            title: '🔒 Security Measures',
            body:
                'We use encryption, secure authentication, and regular security audits to protect your data. Your information is stored securely and only accessible to authorized personnel for legitimate purposes.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Request Data Export',
            icon: Icons.download_outlined,
            route: '/settings/export',
          ),
          _QuickAction(
            label: 'Delete Account',
            icon: Icons.delete_outline,
            route: '/settings/account-status',
          ),
        ],
      );
    case LegalDocument.terms:
      return _LegalContent2(
        title: 'Terms of Service',
        color: Colors.orange,
        icon: Icons.gavel_outlined,
        subtitle: 'Rules that keep our community safe and respectful.',
        sections: [
          _LegalSection(
            title: '✍️ User-Generated Content',
            body:
                'Posts, ratings, comments, and reports are created by users. SIVIQ does not guarantee that user submissions are true, complete, or official. Users are responsible for the content they share.',
          ),
          _LegalSection(
            title: '🏛️ No Government Affiliation',
            body:
                'SIVIQ is not affiliated with, endorsed by, or approved by the Government of Kenya, county governments, elected officials, or public agencies. We are an independent civic platform.',
          ),
          _LegalSection(
            title: '✅ Accuracy And Truthfulness',
            body:
                'Users are responsible for posting truthful information. Posts without evidence such as photos, location, or sources may be marked unverified or given lower ranking weight. False information can lead to account restrictions.',
          ),
          _LegalSection(
            title: '⚖️ Liability And Responsibility',
            body:
                'You are responsible for your posts and comments. SIVIQ may remove reported content that violates these terms or community guidelines. We reserve the right to suspend accounts that repeatedly violate our policies.',
          ),
          _LegalSection(
            title: '🔄 Right of Reply',
            body:
                'Public leaders and authorized representatives may request verification and respond to ratings or project reports through the app process. This ensures fair representation and balanced discourse.',
          ),
          _LegalSection(
            title: '🚫 Prohibited Content',
            body:
                'Content that promotes illegal activities, hate speech, violence, fraud, or violates Kenyan law is strictly prohibited. Such content will be removed and may result in account suspension.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Report Violation',
            icon: Icons.report_outlined,
            route: '/',
          ),
        ],
      );
    case LegalDocument.communityGuidelines:
      return _LegalContent2(
        title: 'Community Guidelines',
        color: Colors.purple,
        icon: Icons.groups_outlined,
        subtitle: 'Be respectful, be factual, be constructive.',
        sections: [
          _LegalSection(
            title: '✅ What Is Allowed',
            body:
                'Post real SIVIQ projects, photos, ratings, comments, and local observations. Keep discussion factual, local, and respectful. Share constructive feedback and engage in meaningful civic dialogue.',
          ),
          _LegalSection(
            title: '🚫 What Is Not Allowed',
            body:
                'Fake projects, fake photos, spam, fraud, pornography, hate speech, incitement to violence, betting content, and coordinated rating manipulation are not allowed. Such behavior will result in immediate action.',
          ),
          _LegalSection(
            title: '📝 Defamation And Proof',
            body:
                'Do not make serious accusations without evidence. Claims about corruption, theft, or criminal conduct should include a source, location, or supporting material. Unsubstantiated claims may be removed.',
          ),
          _LegalSection(
            title: '🛡️ Enforcement',
            body:
                'Reported posts may be hidden, reviewed, removed, or escalated. Repeated false or abusive activity can lead to account restrictions or bans. We believe in fair but firm moderation.',
          ),
          _LegalSection(
            title: '🤝 Your Responsibility',
            body:
                'You are responsible for what you post. If you are unsure whether something is true, do not publish it as fact. Think before you post and consider the impact on your community.',
          ),
          _LegalSection(
            title: '💡 Constructive Engagement',
            body:
                'Focus on solutions rather than complaints. Offer suggestions, share resources, and help build a positive civic environment. Respect different viewpoints and engage in good faith discussions.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Learn About Moderation',
            icon: Icons.info_outline,
            route: '/legal/about',
          ),
        ],
      );
    case LegalDocument.faq:
      return _LegalContent2(
        title: 'FAQ',
        color: Colors.blue,
        icon: Icons.help_outline,
        subtitle: 'Common questions about SIVIQ answered.',
        sections: [
          _LegalSection(
            title: '❓ What Is SIVIQ?',
            body:
                'SIVIQ is an independent civic community platform for sharing local issues, project updates, ideas, and public conversations. We connect citizens and promote transparency in governance.',
          ),
          _LegalSection(
            title: '🏛️ Is SIVIQ A Government App?',
            body:
                'No. SIVIQ is an independent civic platform and is not affiliated with any government institution. We are built by citizens, for citizens, to foster civic engagement.',
          ),
          _LegalSection(
            title: '📱 How Do Posts Work?',
            body:
                'People can post local updates, ask questions, share civic ideas, and discuss what is happening around them. Posts can include photos, locations, and tags for better organization.',
          ),
          _LegalSection(
            title: '🏗️ How Do Project Posts Work?',
            body:
                'Project posts help communities document public works, stalled projects, completed work, and local concerns with context and evidence where possible. Track progress and hold leaders accountable.',
          ),
          _LegalSection(
            title: '🚨 How Do I Report Harmful Content?',
            body:
                'Use the three-dot menu on a post, project, comment, or profile where available. Reports may lead to review, hiding, removal, or account action. Your reports help keep the community safe.',
          ),
          _LegalSection(
            title: '⚠️ What If My Account Is Suspended?',
            body:
                'Open Appeals from the menu and send your username, contact details, and a short explanation through WhatsApp or email. We review all appeals fairly and promptly.',
          ),
          _LegalSection(
            title: '🔐 Is My Data Safe?',
            body:
                'Yes. We follow Kenya Data Protection Act 2019 guidelines and use industry-standard security measures. Your data is encrypted and never sold to third parties.',
          ),
          _LegalSection(
            title: '🌐 Can I Use SIVIQ Anonymously?',
            body:
                'While you need an account to participate, you can control what information is visible on your profile. Your email is never shown publicly, and you can use a username instead of your real name.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Contact Support',
            icon: Icons.support_agent_outlined,
            route: '/legal/contact',
          ),
          _QuickAction(
            label: 'Visit Website',
            icon: Icons.language,
            url: 'https://siviq.top',
          ),
        ],
      );
    case LegalDocument.about:
      return _LegalContent2(
        title: 'About SIVIQ',
        color: Colors.cyan,
        icon: Icons.info_outline,
        subtitle: 'Empowering communities through civic engagement.',
        sections: [
          _LegalSection(
            title: '🎯 Our Purpose',
            body:
                'SIVIQ is a civic community platform built to help people share local issues, projects, ideas, and public updates in one place. We believe in the power of informed citizens to drive positive change.',
          ),
          _LegalSection(
            title: '🛠️ What You Can Do',
            body:
                'You can create community posts, follow profiles, discuss local civic matters, share project updates, and report unsafe or harmful content. Join thousands of citizens already making a difference.',
          ),
          _LegalSection(
            title: '🏛️ Independence',
            body:
                'SIVIQ is independent and is not affiliated with any government institution, county office, elected leader, or public agency. We are citizen-driven and committed to transparency.',
          ),
          _LegalSection(
            title: '🌍 Our Vision',
            body:
                'To create a more informed, engaged, and accountable society where every citizen has a voice in shaping their community. We envision Kenya where civic participation is easy, accessible, and impactful.',
          ),
          _LegalSection(
            title: '📈 Our Impact',
            body:
                'Since launch, SIVIQ has helped citizens document hundreds of projects, report issues, and hold leaders accountable. Join us in building better communities through civic technology.',
          ),
          _LegalSection(
            title: '📞 Contact',
            body: 'WhatsApp: +254719637416\nEmail: adminsiviq@gmail.com\nWebsite: siviq.top',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Visit Website',
            icon: Icons.language,
            url: 'https://siviq.top',
          ),
          _QuickAction(
            label: 'Contact Us',
            icon: Icons.mail_outline,
            route: '/legal/contact',
          ),
        ],
      );
    case LegalDocument.appeals:
      return _LegalContent2(
        title: 'Appeals Process',
        color: Colors.red,
        icon: Icons.assignment_return_outlined,
        subtitle: 'Fair process for reviewing moderation decisions.',
        sections: [
          _LegalSection(
            title: '⏰ When To Appeal',
            body:
                'Use appeals if your account was suspended, your content was removed, or you believe a moderation restriction was applied unfairly. You have the right to a fair review of any action taken against your account.',
          ),
          _LegalSection(
            title: '📋 What To Include',
            body:
                'Include your username, phone or email, the affected post or account, and a short explanation of why you believe the decision should be reviewed. The more information you provide, the faster we can process your appeal.',
          ),
          _LegalSection(
            title: '📤 Send Your Appeal',
            body: 'WhatsApp: +254719637416\nEmail: adminsiviq@gmail.com\n\nWe typically respond within 24-48 hours during business days.',
          ),
          _LegalSection(
            title: '⚖️ Fair Use',
            body:
                'Abusive appeals, threats, spam, or false information may be ignored. We expect respectful communication and honest representation of the situation.',
          ),
          _LegalSection(
            title: '🔄 Appeal Outcomes',
            body:
                'If your appeal is successful, your content will be restored or your account reinstated. If denied, we will explain why. You may submit a new appeal if you have additional information.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Contact via WhatsApp',
            icon: Icons.chat_outlined,
            url: 'https://wa.me/254719637416',
          ),
          _QuickAction(
            label: 'Send Email',
            icon: Icons.email_outlined,
            url: 'mailto:adminsiviq@gmail.com',
          ),
        ],
      );
    case LegalDocument.contact:
      return _LegalContent2(
        title: 'Contact SIVIQ',
        color: Colors.indigo,
        icon: Icons.mail_outline,
        subtitle: 'We\'re here to help. Reach out anytime.',
        sections: [
          _LegalSection(
            title: '💬 Support Channels',
            body: 'WhatsApp: +254719637416 (Fastest response)\nEmail: adminsiviq@gmail.com\n\nWe typically respond within 24 hours.',
          ),
          _LegalSection(
            title: '🐛 Report An Issue',
            body:
                'When reporting a problem, include your username, what you were doing, and any error message you saw. Screenshots help us diagnose issues faster.',
          ),
          _LegalSection(
            title: '💡 Feature Requests',
            body:
                'Have an idea to improve SIVIQ? We love hearing from our users! Share your suggestions and we\'ll consider them for future updates.',
          ),
          _LegalSection(
            title: '🤝 Partnerships',
            body:
                'Interested in partnering with SIVIQ? We collaborate with civic organizations, media, and community groups. Contact us to discuss opportunities.',
          ),
          _LegalSection(
            title: '📢 Media Inquiries',
            body:
                'For press, interviews, or media-related questions, please email adminsiviq@gmail.com with "Media Inquiry" in the subject line.',
          ),
        ],
        quickActions: [
          _QuickAction(
            label: 'Chat on WhatsApp',
            icon: Icons.chat_outlined,
            url: 'https://wa.me/254719637416',
          ),
          _QuickAction(
            label: 'Send Email',
            icon: Icons.email_outlined,
            url: 'mailto:adminsiviq@gmail.com',
          ),
          _QuickAction(
            label: 'Visit Website',
            icon: Icons.language,
            url: 'https://siviq.top',
          ),
        ],
      );
  }
}

class _LegalContent2 {
  const _LegalContent2({
    required this.title,
    required this.color,
    required this.icon,
    required this.sections,
    this.subtitle,
    this.quickActions = const [],
  });

  final String title;
  final Color color;
  final IconData icon;
  final String? subtitle;
  final List<_LegalSection> sections;
  final List<_QuickAction> quickActions;
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    this.route,
    this.url,
  });

  final String label;
  final IconData icon;
  final String? route;
  final String? url;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.color,
    required this.index,
  });

  final _LegalSection section;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with accent
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              section.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.action,
    required this.color,
  });

  final _QuickAction action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (action.url != null) {
          final Uri url = Uri.parse(action.url!);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        } else if (action.route != null && context.mounted) {
          context.push(action.route!);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(action.icon, color: AppColors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.white,
              size: 16,
            ),
          ],
        ),
      ),
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
