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
    final myProfileAsync = ref.watch(myProfileProvider);
    final profileData = myProfileAsync.valueOrNull;
    final employee = profileData?.employee ?? user?.employee;
    final passkeysAsync = ref.watch(_userPasskeysProvider);
    final passkeys = passkeysAsync.valueOrNull ?? user?.passkeys ?? const [];
    final photo = user?.profilePhotoUrl ??
        _stringVal(employee?['photo_url']) ??
        _stringVal(employee?['profile_photo_url']);

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: () {
              ref.invalidate(myProfileProvider);
              ref.invalidate(_userPasskeysProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: user == null && profileData == null
          ? (myProfileAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('No employee profile loaded.')))
          : RefreshIndicator(
              color: OrbitColors.primaryNavy,
              onRefresh: () async {
                ref.invalidate(myProfileProvider);
                ref.invalidate(_userPasskeysProvider);
                await ref.read(myProfileProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    // Profile Header Card
                    _buildHeaderCard(user, employee, photo),

                    const SizedBox(height: 20),

                    // Employee Information Section
                    const _SectionHeader(title: 'Employee Information'),
                    const SizedBox(height: 10),
                    _buildEmployeeInfoCard(user, employee),

                    if (_hasReportingLines(employee)) ...[
                      const SizedBox(height: 20),
                      const _SectionHeader(title: 'Organization & Approvers'),
                      const SizedBox(height: 10),
                      _buildOrganizationCard(employee!),
                    ],

                    if (_hasPersonalOrBankDetails(employee)) ...[
                      const SizedBox(height: 20),
                      const _SectionHeader(title: 'Payroll Info'),
                      const SizedBox(height: 10),
                      _buildPersonalAndBankCard(employee!),
                    ],

                    const SizedBox(height: 20),

                    // Security & Passkeys Section
                    const _SectionHeader(title: 'Security & Passkeys'),
                    const SizedBox(height: 10),
                    _buildPasskeysCard(passkeys),

                    ..._buildRelationCollectionSections(employee),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  String? _resolveJobTitle(UserModel? user, Map<String, dynamic>? employee) {
    for (final candidate in [
      user?.title,
      employee?['primary_role'],
      employee?['primaryRole'],
      employee?['role'],
      employee?['job_title'],
      employee?['jobTitle'],
      employee?['position'],
      employee?['position_name'],
      employee?['role_name'],
      employee?['roleName'],
      employee?['primary_role_name'],
      employee?['primaryRoleName'],
      employee?['title'],
      employee?['designation'],
    ]) {
      final label = _labelFromRelation(candidate);
      if (label != null && label.isNotEmpty) return label;
    }
    final roles = employee?['roles'];
    if (roles is List && roles.isNotEmpty) {
      final first = _labelFromRelation(roles.first);
      if (first != null && first.isNotEmpty) return first;
    }
    final assignments = employee?['assignment_histories'] ??
        employee?['assignmentHistories'];
    if (assignments is List && assignments.isNotEmpty) {
      for (final a in assignments.whereType<Map>()) {
        final label = _labelFromRelation(a['primary_role'] ??
            a['primaryRole'] ??
            a['role'] ??
            a['role_name'] ??
            a['job_title'] ??
            a['position'] ??
            a['title']);
        if (label != null && label.isNotEmpty) return label;
      }
    }
    return null;
  }

  String? _resolveDepartment(UserModel? user, Map<String, dynamic>? employee) {
    for (final candidate in [
      user?.department,
      employee?['department'],
      employee?['department_name'],
      employee?['departmentName'],
      employee?['division'],
      employee?['division_name'],
      employee?['unit'],
      employee?['unit_name'],
      employee?['section'],
    ]) {
      final label = _labelFromRelation(candidate);
      if (label != null && label.isNotEmpty) return label;
    }
    final assignments = employee?['assignment_histories'] ??
        employee?['assignmentHistories'];
    if (assignments is List && assignments.isNotEmpty) {
      for (final a in assignments.whereType<Map>()) {
        final label = _labelFromRelation(
            a['department'] ?? a['department_name'] ?? a['division']);
        if (label != null && label.isNotEmpty) return label;
      }
    }
    return null;
  }

  String? _resolvePhone(UserModel? user, Map<String, dynamic>? employee) {
    for (final candidate in [
      employee?['phone'],
      employee?['mobile_phone'],
      employee?['mobilePhone'],
      employee?['phone_number'],
      employee?['phoneNumber'],
      employee?['whatsapp'],
      employee?['whatsapp_number'],
      employee?['personal_phone'],
      employee?['work_phone'],
      employee?['contact_phone'],
      user?.rawJson?['phone'],
      user?.rawJson?['mobile_phone'],
      user?.rawJson?['phone_number'],
    ]) {
      final val = _stringVal(candidate);
      if (val != null && val.isNotEmpty) return val;
    }
    return null;
  }

  Widget _buildHeaderCard(
    UserModel? user,
    Map<String, dynamic>? employee,
    String? photo,
  ) {
    final displayName = _stringVal(employee?['full_name']) ??
        user?.name ??
        _stringVal(employee?['name']) ??
        'Employee';
    final preferred = user?.preferredName ??
        _stringVal(employee?['preferred_name']) ??
        _stringVal(employee?['preferredName']);
    final resolvedTitle = _resolveJobTitle(user, employee);
    final resolvedDept = _resolveDepartment(user, employee);
    final badgeTitle = resolvedTitle ?? resolvedDept ?? 'Employee';
    final statusLabel = _labelFromRelation(employee?['status']) ??
        _stringVal(employee?['employment_status']);
    final empCode = user?.employeeCode ??
        _stringVal(employee?['employee_code']) ??
        _stringVal(employee?['employee_id_number']) ??
        _stringVal(employee?['nik']);

    return Container(
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
                      errorBuilder: (_, __, ___) => _initials(displayName),
                    )
                  : _initials(displayName),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: OrbitColors.primaryNavy,
            ),
          ),
          if (preferred != null &&
              preferred.isNotEmpty &&
              preferred.toLowerCase() != displayName.toLowerCase()) ...[
            const SizedBox(height: 2),
            Text(
              '($preferred)',
              style: const TextStyle(
                fontSize: 13,
                color: OrbitColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: OrbitColors.bubbleBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OrbitColors.primaryNavy,
                  ),
                ),
              ),
              if (empCode != null && empCode.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    empCode,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.textNavy,
                    ),
                  ),
                ),
              if (statusLabel != null && statusLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: OrbitColors.kpiGreenBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: OrbitColors.kpiGreen,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfoCard(
      UserModel? user, Map<String, dynamic>? employee) {
    final email = user?.email.isNotEmpty == true
        ? user!.email
        : (_stringVal(employee?['work_email']) ??
            _stringVal(employee?['email']) ??
            '—');
    final phone = _resolvePhone(user, employee) ?? '—';
    final username = user?.username;
    final title = _resolveJobTitle(user, employee) ?? '—';
    final department = _resolveDepartment(user, employee) ?? '—';
    final organization = _labelFromRelation(employee?['organization']);
    final branch = _labelFromRelation(employee?['branch']);
    final joinDate = _stringVal(employee?['join_date']) ??
        _stringVal(employee?['hire_date']);

    return Container(
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
            value: email,
          ),
          const _Divider(),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: phone,
          ),
          if (username != null && username.isNotEmpty) ...[
            const _Divider(),
            _DetailRow(
              icon: Icons.account_circle_outlined,
              label: 'Username',
              value: username,
            ),
          ],
          const _Divider(),
          _DetailRow(
            icon: Icons.work_outline_rounded,
            label: 'Job Title / Position',
            value: title,
          ),
          const _Divider(),
          _DetailRow(
            icon: Icons.corporate_fare_rounded,
            label: 'Department / Division',
            value: department,
          ),
          if (organization != null) ...[
            const _Divider(),
            _DetailRow(
              icon: Icons.business_rounded,
              label: 'Organization',
              value: organization,
            ),
          ],
          if (branch != null) ...[
            const _Divider(),
            _DetailRow(
              icon: Icons.location_city_rounded,
              label: 'Branch / Location',
              value: branch,
            ),
          ],
          if (joinDate != null) ...[
            const _Divider(),
            _DetailRow(
              icon: Icons.event_available_rounded,
              label: 'Join Date',
              value: joinDate,
            ),
          ],
        ],
      ),
    );
  }

  bool _hasReportingLines(Map<String, dynamic>? employee) {
    if (employee == null) return false;
    return _labelFromRelation(employee['manager']) != null ||
        _labelFromRelation(
                employee['responsible_hr'] ?? employee['responsibleHr']) !=
            null ||
        _labelFromRelation(
                employee['time_off_approver'] ?? employee['timeOffApprover']) !=
            null ||
        _labelFromRelation(employee['attendance_approver'] ??
                employee['attendanceApprover']) !=
            null ||
        (employee['direct_reports'] is List &&
            (employee['direct_reports'] as List).isNotEmpty) ||
        (employee['directReports'] is List &&
            (employee['directReports'] as List).isNotEmpty);
  }

  Widget _buildOrganizationCard(Map<String, dynamic> employee) {
    final manager = _labelFromRelation(employee['manager']);
    final hr = _labelFromRelation(
        employee['responsible_hr'] ?? employee['responsibleHr']);
    final timeOffApprover = _labelFromRelation(
        employee['time_off_approver'] ?? employee['timeOffApprover']);
    final attendanceApprover = _labelFromRelation(
        employee['attendance_approver'] ?? employee['attendanceApprover']);
    final directReportsList = (employee['direct_reports'] ??
        employee['directReports']) as List<dynamic>?;
    final directReportsNames = directReportsList
        ?.map(_labelFromRelation)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    final rows = <Widget>[];
    void addRow(IconData icon, String label, String? val) {
      if (val == null || val.isEmpty) return;
      if (rows.isNotEmpty) rows.add(const _Divider());
      rows.add(_DetailRow(icon: icon, label: label, value: val));
    }

    addRow(Icons.supervisor_account_rounded, 'Manager', manager);
    addRow(Icons.support_agent_rounded, 'Responsible HR', hr);
    addRow(
        Icons.beach_access_rounded, 'Time-Off Approver', timeOffApprover);
    addRow(Icons.fact_check_outlined, 'Attendance Approver',
        attendanceApprover);
    if (directReportsNames != null && directReportsNames.isNotEmpty) {
      addRow(
        Icons.groups_2_outlined,
        'Direct Reports (${directReportsNames.length})',
        directReportsNames.join(', '),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrbitColors.cardBorder),
      ),
      child: Column(children: rows),
    );
  }

  bool _hasPersonalOrBankDetails(Map<String, dynamic>? employee) {
    if (employee == null) return false;
    return _labelFromRelation(employee['bank']) != null ||
        _stringVal(employee['bank_name']) != null ||
        _stringVal(employee['bank_account_number']) != null ||
        _stringVal(employee['tax_id'] ?? employee['npwp']) != null;
  }

  Widget _buildPersonalAndBankCard(Map<String, dynamic> employee) {
    final bank = _labelFromRelation(employee['bank']) ??
        _stringVal(employee['bank_name']);
    final bankAccount = _stringVal(employee['bank_account_number']);
    final taxId = _stringVal(employee['tax_id'] ?? employee['npwp']);

    final rows = <Widget>[];
    void addRow(IconData icon, String label, String? val) {
      if (val == null || val.isEmpty) return;
      if (rows.isNotEmpty) rows.add(const _Divider());
      rows.add(_DetailRow(icon: icon, label: label, value: val));
    }

    addRow(Icons.account_balance_outlined, 'Bank', bank);
    addRow(Icons.credit_card_rounded, 'Bank Account', bankAccount);
    addRow(Icons.assignment_ind_outlined, 'Tax ID / NPWP', taxId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OrbitColors.cardBorder),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildPasskeysCard(List<PasskeyCredentialModel> passkeys) {
    return Container(
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
                  color: OrbitColors.bubbleBlue.withValues(alpha: .5),
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
                onPressed: _passkeyBusy ? null : _promptAndRegisterPasskey,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              passkeys[i].createdAt!.isNotEmpty) ...[
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
    );
  }

  List<Widget> _buildRelationCollectionSections(
      Map<String, dynamic>? employee) {
    if (employee == null) return const [];
    final specs = <(String, List<String>, IconData)>[
      ('Skills', ['skills'], Icons.psychology_outlined),
      ('Certifications', ['certifications'], Icons.verified_outlined),
      ('Education', ['educations'], Icons.school_outlined),
      (
        'Assignment History',
        ['assignment_histories', 'assignmentHistories'],
        Icons.work_history_outlined
      ),
      (
        'Documents',
        ['documents'],
        Icons.description_outlined
      ),
      ('Resumes', ['resumes'], Icons.badge_outlined),
      (
        'Test Results',
        ['test_results', 'testResults'],
        Icons.assessment_outlined
      ),
      (
        'Notes History',
        ['notes_history', 'notesHistory'],
        Icons.sticky_note_2_outlined
      ),
      (
        'Sales Schedule',
        ['sales_schedule', 'salesSchedule'],
        Icons.calendar_month_outlined
      ),
    ];

    final widgets = <Widget>[];
    for (final spec in specs) {
      dynamic rawVal;
      for (final key in spec.$2) {
        if (employee[key] != null) {
          rawVal = employee[key];
          break;
        }
      }
      final items = _extractListLabels(rawVal);
      if (items.isEmpty) continue;

      widgets.add(const SizedBox(height: 20));
      widgets.add(_SectionHeader(title: spec.$1));
      widgets.add(const SizedBox(height: 10));
      widgets.add(
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OrbitColors.cardBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const _Divider(),
                _DetailRow(
                  icon: spec.$3,
                  label: '${spec.$1} #${i + 1}',
                  value: items[i],
                ),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  List<String> _extractListLabels(dynamic rawVal) {
    if (rawVal == null) return const [];
    if (rawVal is List) {
      return rawVal
          .map(_formatCollectionEntry)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (rawVal is Map && rawVal.isNotEmpty) {
      final formatted = _formatCollectionEntry(rawVal);
      return formatted != null && formatted.isNotEmpty ? [formatted] : const [];
    }
    return const [];
  }

  String? _formatCollectionEntry(dynamic item) {
    if (item == null) return null;
    if (item is String) return item.trim();
    if (item is Map) {
      final primary = _stringVal(item['name']) ??
          _stringVal(item['title']) ??
          _stringVal(item['skill_name']) ??
          _stringVal(item['institution']) ??
          _stringVal(item['school_name']) ??
          _stringVal(item['document_name']) ??
          _stringVal(item['role_name']) ??
          _stringVal(item['position']) ??
          _stringVal(item['note']) ??
          _stringVal(item['day']) ??
          _stringVal(item['label']);
      final secondary = _stringVal(item['level']) ??
          _stringVal(item['proficiency']) ??
          _stringVal(item['degree']) ??
          _stringVal(item['major']) ??
          _stringVal(item['issuer']) ??
          _stringVal(item['department']) ??
          _stringVal(item['score']) ??
          _stringVal(item['status']);
      if (primary != null && secondary != null) {
        return '$primary • $secondary';
      }
      if (primary != null) return primary;
      final nonNullVals = item.entries
          .where((e) =>
              e.key != 'id' &&
              e.key != 'employee_id' &&
              e.value != null &&
              e.value is! Map &&
              e.value is! List &&
              e.value.toString().trim().isNotEmpty)
          .map((e) => e.value.toString().trim())
          .take(3)
          .toList();
      return nonNullVals.isEmpty ? null : nonNullVals.join(' • ');
    }
    return item.toString().trim();
  }

  static String? _stringVal(dynamic val) {
    if (val == null || val is Map || val is List) return null;
    final s = val.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _labelFromRelation(dynamic val) {
    if (val == null) return null;
    if (val is String) {
      final s = val.trim();
      return s.isEmpty ? null : s;
    }
    if (val is Map) {
      for (final key in const [
        'full_name',
        'name',
        'preferred_name',
        'role_name',
        'department_name',
        'organization_name',
        'branch_name',
        'job_title',
        'position_name',
        'position',
        'title',
        'label',
        'bank_name',
        'code',
      ]) {
        final v = _stringVal(val[key]);
        if (v != null) return v;
      }
      for (final subKey in const ['role', 'department', 'position', 'job']) {
        if (val[subKey] is Map) {
          final subLabel = _labelFromRelation(val[subKey]);
          if (subLabel != null) return subLabel;
        }
      }
    }
    return null;
  }

  Widget _initials(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
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
    'uuid',
    'name',
    'full_name',
    'preferred_name',
    'preferredName',
    'email',
    'work_email',
    'employee_id',
    'employee_uuid',
    'employee_code',
    'employee_id_number',
    'nik',
    'profile_photo_url',
    'photo_url',
    'photo_path',
    'username',
    'title',
    'job_title',
    'position',
    'department',
    'division',
    'organization',
    'branch',
    'bank',
    'bank_name',
    'bank_account_number',
    'tax_id',
    'npwp',
    'phone',
    'mobile_phone',
    'whatsapp',
    'status',
    'employment_status',
    'join_date',
    'hire_date',
    'manager',
    'primary_role',
    'primaryRole',
    'responsible_hr',
    'responsibleHr',
    'time_off_approver',
    'timeOffApprover',
    'attendance_approver',
    'attendanceApprover',
    'direct_reports',
    'directReports',
    'skills',
    'documents',
    'certifications',
    'educations',
    'assignment_histories',
    'assignmentHistories',
    'resumes',
    'test_results',
    'testResults',
    'notes_history',
    'notesHistory',
    'sales_schedule',
    'salesSchedule',
    'employee',
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
