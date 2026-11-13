import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/erp_colors.dart';
import '../../../core/updater/update_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateDialog.showIfAvailable(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: ErpColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: ErpColors.primaryNavy,
        elevation: 0,
        title: const Text(
          'WorkHub Orbit',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User greeting card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ErpColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ErpColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: ErpColors.lightBlue,
                    backgroundImage: user?.profilePhotoUrl != null
                        ? NetworkImage(user!.profilePhotoUrl!)
                        : null,
                    child: user?.profilePhotoUrl == null
                        ? Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ErpColors.primaryNavy,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ErpColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.employeeCode ?? user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ErpColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Modules header
            const Text(
              'Quick Modules',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: ErpColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Module grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildModuleCard(
                  icon: Icons.location_on_rounded,
                  title: 'Field Visits',
                  subtitle: 'GPS Check-in & Targets',
                  color: Colors.blue,
                  onTap: () {},
                ),
                _buildModuleCard(
                  icon: Icons.shopping_cart_rounded,
                  title: 'Sales Orders',
                  subtitle: 'Products & Cart',
                  color: Colors.indigo,
                  onTap: () {},
                ),
                _buildModuleCard(
                  icon: Icons.task_alt_rounded,
                  title: 'Tasks & EC',
                  subtitle: 'Reviews & Progress',
                  color: Colors.teal,
                  onTap: () {},
                ),
                _buildModuleCard(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Discussions',
                  subtitle: 'Customer Chats',
                  color: Colors.purple,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ErpColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ErpColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color.shade700, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ErpColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: ErpColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
