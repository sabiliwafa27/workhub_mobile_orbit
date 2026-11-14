import 'package:flutter/material.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/orbit_workspace.dart';

class ErpaScreen extends StatelessWidget {
  const ErpaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OrbitWorkspaceScaffold(
      subtitle: 'Enterprise Workspace & Modules',
      headerIcon: Icons.grid_view_rounded,
      appBar: AppBar(
        title: const Text('ERPa'),
      ),
      body: OrbitDetailList(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: OrbitColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: OrbitColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1006244D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: OrbitColors.bubbleBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: OrbitColors.primaryNavy,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ERPa Workspace',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: OrbitColors.textNavy,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Integrated enterprise modules and workflow tools.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: OrbitColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Enterprise Modules',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: OrbitColors.textNavy,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Mail Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'The Mail module is planned for a future update.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrbitColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OrbitColors.cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C06244D),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: OrbitColors.bubbleBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: OrbitColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Mail',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: OrbitColors.textNavy,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: OrbitColors.creamCard,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: OrbitColors.creamBorder,
                                  ),
                                ),
                                child: const Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: OrbitColors.brandOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Corporate mail, shared inbox & official communications.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OrbitColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: OrbitColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
