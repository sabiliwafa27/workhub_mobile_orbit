import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/passkey_service.dart';

final _userPasskeysProvider =
    FutureProvider.autoDispose<List<PasskeyCredentialModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  try {
    return await ref.watch(passkeyServiceProvider).fetchPasskeys();
  } catch (_) {
    return user?.passkeys ?? const [];
  }
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _passkeyBusy = false;

  Future<void> _promptAndRegisterPasskey() async {
    if (_passkeyBusy) return;
    var draftName = 'WorkHub Android Phone';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Passkey'),
        content: TextFormField(
          initialValue: draftName,
          autofocus: true,
          onChanged: (value) => draftName = value,
          decoration: const InputDecoration(
            labelText: 'Device / Passkey Name',
            hintText: 'e.g. My Work Phone',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, draftName.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: OrbitColors.primaryNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;

    setState(() => _passkeyBusy = true);
    try {
      await ref.read(authProvider.notifier).registerPasskey(
            name: name.isEmpty ? 'WorkHub Android Phone' : name,
          );
      ref.invalidate(_userPasskeysProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passkey registered successfully.'),
            backgroundColor: OrbitColors.kpiGreen,
          ),
        );
      }
    } on PasskeyCancelledException {
      // User dismissed prompt; no error message needed.
    } on PasskeyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: OrbitColors.kpiRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: OrbitColors.kpiRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _passkeyBusy = false);
    }
  }

  Future<void> _confirmAndDeletePasskey(PasskeyCredentialModel passkey) async {
    if (_passkeyBusy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Passkey'),
        content: Text('Remove "${passkey.name}" from your Orbit account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: OrbitColors.kpiRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _passkeyBusy = true);
    try {
      await ref.read(authProvider.notifier).deletePasskey(passkey.id);
      ref.invalidate(_userPasskeysProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passkey removed.'),
            backgroundColor: OrbitColors.primaryNavy,
          ),
        );
      }
    } on PasskeyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: OrbitColors.kpiRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: OrbitColors.kpiRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _passkeyBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final passkeysAsync = ref.watch(_userPasskeysProvider);
    final passkeys = passkeysAsync.valueOrNull ?? user?.passkeys ?? const [];
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

                  const SizedBox(height: 20),

                  // Security & Passkeys Section
                  const _SectionHeader(title: 'Security & Passkeys'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OrbitColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: OrbitColors.bubbleBlue
                                    .withValues(alpha: .5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.key_rounded,
                                size: 18,
                                color: OrbitColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Passkeys',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: OrbitColors.textNavy,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sign in faster with device biometrics or screen lock.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: OrbitColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _passkeyBusy
                                  ? null
                                  : _promptAndRegisterPasskey,
                              icon: _passkeyBusy
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        if (passkeys.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const _Divider(),
                          for (var i = 0; i < passkeys.length; i++) ...[
                            if (i > 0) const _Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.fingerprint_rounded,
                                    size: 20,
                                    color: OrbitColors.primaryNavy,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          passkeys[i].name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: OrbitColors.textNavy,
                                          ),
                                        ),
                                        if (passkeys[i].createdAt != null &&
                                            passkeys[i]
                                                .createdAt!
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Added ${passkeys[i].createdAt!.split('T').first}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: OrbitColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove passkey',
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: OrbitColors.kpiRed,
                                    ),
                                    onPressed: _passkeyBusy
                                        ? null
                                        : () => _confirmAndDeletePasskey(
                                              passkeys[i],
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 10),
                          const Text(
                            'No passkeys registered yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: OrbitColors.textMuted,
                            ),
                          ),
                        ],
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
    'preferred_name',
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
    'passkeys',
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
