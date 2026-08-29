import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_card.dart';

/// Help & FAQ — grouped expandable answers with a contact-support CTA.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const _faqGroups = <_FaqGroup>[
    _FaqGroup(
      title: 'Getting Started',
      icon: Icons.rocket_launch_outlined,
      items: [
        _FaqItem(
          question: 'How do I become a blood donor?',
          answer:
              'Sign up, open Profile → Verification Status, and submit your '
              'CNIC photos plus a selfie. Our team reviews submissions within '
              '48 hours — once approved, a Verified badge appears on your '
              'profile and you start receiving requests.',
        ),
        _FaqItem(
          question: 'What is the difference between Seeker and Donor?',
          answer:
              'Seekers create blood requests and search for donors. Donors '
              'receive and respond to nearby requests. You can switch roles '
              'anytime from the Home screen or Profile → Active Role.',
        ),
      ],
    ),
    _FaqGroup(
      title: 'Requests & Donations',
      icon: Icons.bloodtype_outlined,
      items: [
        _FaqItem(
          question: 'How long does a blood request stay active?',
          answer:
              'Every request stays active for 72 hours by default. After '
              'that it expires automatically. You can hold up to 3 active '
              'requests at the same time.',
        ),
        _FaqItem(
          question: 'How often can I donate blood?',
          answer:
              'After a donation you enter a 90-day cooldown to protect your '
          'health. Your Profile → Donation History shows how many days '
              'remain until you are eligible again.',
        ),
        _FaqItem(
          question: 'What does "Compensated for travel/time" mean?',
          answer:
              'Some donors accept reimbursement for travel or time — never '
              'payment for blood itself. Volunteer donors receive nothing '
              'beyond our gratitude. Both are equally welcome.',
        ),
      ],
    ),
    _FaqGroup(
      title: 'Safety & Privacy',
      icon: Icons.shield_outlined,
      items: [
        _FaqItem(
          question: 'Is my personal information safe?',
          answer:
              'Your CNIC and verification documents are private and visible '
              'only to our review team. Donors never see your phone number '
              'unless you enable phone contact on a request — chat is the '
              'default.',
        ),
        _FaqItem(
          question: 'Can I delete my account?',
          answer:
              'Yes. Profile → Account Actions → Delete Account removes your '
              'profile, requests, and messages permanently. This cannot be '
              'undone.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Help & FAQ'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final group in _faqGroups) ...[
            _GroupHeader(title: group.title, icon: group.icon),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, item) in group.items.indexed) ...[
                    if (i > 0) Divider(height: 1, color: colors.border),
                    _FaqTile(item: item),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Still stuck? ─────────────────────────────────────
          Text(
            'Still need help?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textMedium,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.support_agent,
                  size: 24, color: colors.secondary),
              title: const Text('Contact Support'),
              subtitle: const Text('support@donora.app'),
              trailing: Icon(Icons.chevron_right,
                  size: 20, color: colors.textMedium),
              onTap: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textMedium,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});

  final _FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textHigh,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 22,
                    color: colors.textMedium,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.item.answer,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textMedium,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqGroup {
  const _FaqGroup({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_FaqItem> items;
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
