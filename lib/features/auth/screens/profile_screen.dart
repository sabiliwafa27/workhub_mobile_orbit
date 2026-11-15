import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final photo = user?.profilePhotoUrl;

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('No employee profile loaded.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: OrbitColors.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A06244D),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: OrbitColors.bubbleBlue,
                          child: ClipOval(
                            child: photo != null && photo.isNotEmpty
                                ? Image.network(
                                    photo,
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _initials(user),
                                  )
                                : _initials(user),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: OrbitColors.bubbleBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.title?.isNotEmpty == true
                                ? user.title!
                                : (user.department?.isNotEmpty == true
                                    ? user.department!
                                    : 'Employee'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: OrbitColors.primaryNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Employee Details Section
                  _SectionHeader(title: 'Employee Information'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OrbitColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user.email.isNotEmpty ? user.email : '—',
                        ),
                        if (user.username != null &&
                            user.username!.isNotEmpty) ...[
                          const _Divider(),
                          _DetailRow(
                            icon: Icons.account_circle_outlined,
                            label: 'Username',
                            value: user.username!,
                          ),
                        ],
                        const _Divider(),
                        _DetailRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Job Title / Position',
                          value: user.title?.isNotEmpty == true
                              ? user.title!
                              : '—',
                        ),
                        const _Divider(),
                        _DetailRow(
                          icon: Icons.corporate_fare_rounded,
                          label: 'Department / Division',
                          value: user.department?.isNotEmpty == true
                              ? user.department!
                              : '—',
                        ),
                      ],
                    ),
                  ),

                  // Additional Employee Fields from raw JSON if present
                  if (_buildExtraEmployeeFields(user.rawJson).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Additional Records'),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: OrbitColors.cardBorder),
                      ),
                      child: Column(
                        children: _buildExtraEmployeeRows(user.rawJson),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _initials(UserModel user) {
    return Center(
      child: Text(
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: OrbitColors.primaryNavy,
        ),
      ),
    );
  }

  static const _ignoredKeys = {
    'id',
    'name',
    'email',
    'employee_id',
    'employee_uuid',
    'employee_code',
    'profile_photo_url',
    'username',
    'title',
    'job_title',
    'position',
    'department',
    'division',
    'orbit',
    'permissions',
    'modules',
    'token',
    'device_name',
    'remember_me',
  };

  Map<String, dynamic> _buildExtraEmployeeFields(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    final extra = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (!_ignoredKeys.contains(entry.key) &&
          entry.value != null &&
          entry.value.toString().trim().isNotEmpty) {
        if (entry.value is Map) {
          final m = entry.value as Map;
          for (final sub in m.entries) {
            if (sub.value != null && sub.value.toString().trim().isNotEmpty) {
              extra['${entry.key} ${sub.key}'] = sub.value;
            }
          }
        } else if (entry.value is! List) {
          extra[entry.key] = entry.value;
        }
      }
    }
    return extra;
  }

  List<Widget> _buildExtraEmployeeRows(Map<String, dynamic>? raw) {
    final fields = _buildExtraEmployeeFields(raw);
    final rows = <Widget>[];
    final entries = fields.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final label = e.key
          .replaceAll('_', ' ')
          .split(' ')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '')
          .join(' ');
      rows.add(_DetailRow(
        icon: Icons.info_outline_rounded,
        label: label,
        value: e.value.toString(),
      ));
      if (i < entries.length - 1) {
        rows.add(const _Divider());
      }
    }
    return rows;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: OrbitColors.textMuted,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: OrbitColors.bubbleBlue.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: OrbitColors.primaryNavy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: OrbitColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.textNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9));
  }
}
