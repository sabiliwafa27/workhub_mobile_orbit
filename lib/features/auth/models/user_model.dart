class PasskeyCredentialModel {
  final int id;
  final String name;
  final String? createdAt;
  final String? lastUsedAt;

  const PasskeyCredentialModel({
    required this.id,
    required this.name,
    this.createdAt,
    this.lastUsedAt,
  });

  factory PasskeyCredentialModel.fromJson(Map<String, dynamic> json) {
    return PasskeyCredentialModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Passkey').toString(),
      createdAt: json['created_at']?.toString(),
      lastUsedAt: json['last_used_at']?.toString(),
    );
  }
}

class LoginBackgroundModel {
  final String webpUrl;
  final String? jpgUrl;
  final String? directWebpUrl;
  final String? version;
  final String? updatedAt;

  const LoginBackgroundModel({
    required this.webpUrl,
    this.jpgUrl,
    this.directWebpUrl,
    this.version,
    this.updatedAt,
  });

  factory LoginBackgroundModel.fromJson(Map<String, dynamic> json,
      {String fallbackBaseUrl = 'https://orbit.kecapsawi.net'}) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final webp = (data['webp_url'] ??
            data['direct_webp_url'] ??
            '$fallbackBaseUrl/login-desktop.webp')
        .toString();
    return LoginBackgroundModel(
      webpUrl: webp,
      jpgUrl: data['jpg_url']?.toString(),
      directWebpUrl: data['direct_webp_url']?.toString(),
      version: data['version']?.toString(),
      updatedAt: data['updated_at']?.toString(),
    );
  }
}

class MyProfileResponse {
  final bool hasLinkedEmployee;
  final int? employeeId;
  final UserModel? user;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic> rawData;

  const MyProfileResponse({
    required this.hasLinkedEmployee,
    this.employeeId,
    this.user,
    this.employee,
    this.rawData = const {},
  });

  factory MyProfileResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final empMap = data['employee'] is Map
        ? Map<String, dynamic>.from(data['employee'] as Map)
        : null;
    Map<String, dynamic>? userMap;
    if (data['user'] is Map) {
      userMap = Map<String, dynamic>.from(data['user'] as Map);
      if (empMap != null && userMap['employee'] == null) {
        userMap['employee'] = empMap;
      }
    }
    return MyProfileResponse(
      hasLinkedEmployee:
          data['has_linked_employee'] == true || empMap != null,
      employeeId: (data['employee_id'] as num?)?.toInt() ??
          (empMap?['id'] as num?)?.toInt(),
      user: userMap != null ? UserModel.fromJson(userMap) : null,
      employee: empMap,
      rawData: data,
    );
  }
}

class UserModel {
  final int id;
  final String name;
  final String? preferredName;
  final String email;
  final int? employeeId;
  final String? employeeUuid;
  final String? employeeCode;
  final String? profilePhotoUrl;
  final String? username;
  final String? title;
  final String? department;
  final List<String> permissions;
  final Map<String, dynamic> modules;
  final List<PasskeyCredentialModel> passkeys;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? rawJson;

  UserModel({
    required this.id,
    required this.name,
    this.preferredName,
    required this.email,
    this.employeeId,
    this.employeeUuid,
    this.employeeCode,
    this.profilePhotoUrl,
    this.username,
    this.title,
    this.department,
    required this.permissions,
    required this.modules,
    this.passkeys = const [],
    this.employee,
    this.rawJson,
  });

  static String? _nestedLabel(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      for (final key in const [
        'name',
        'full_name',
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
        'code',
      ]) {
        final v = value[key];
        if (v != null && v is! Map && v is! List && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      for (final subKey in const ['role', 'department', 'position', 'job']) {
        if (value[subKey] is Map) {
          final subLabel = _nestedLabel(value[subKey]);
          if (subLabel != null) return subLabel;
        }
      }
    }
    return null;
  }

  static String? _resolveRoleTitle(
    Map<String, dynamic> json,
    Map<String, dynamic>? employeeMap,
    Map<String, dynamic>? orbit,
  ) {
    for (final candidate in [
      json['title'],
      json['job_title'],
      json['jobTitle'],
      json['position'],
      json['role_name'],
      json['roleName'],
      json['primary_role_name'],
      employeeMap?['job_title'],
      employeeMap?['jobTitle'],
      employeeMap?['position'],
      employeeMap?['position_name'],
      employeeMap?['title'],
      employeeMap?['role_name'],
      employeeMap?['roleName'],
      employeeMap?['primary_role_name'],
      employeeMap?['primaryRoleName'],
      employeeMap?['designation'],
      employeeMap?['primary_role'],
      employeeMap?['primaryRole'],
      employeeMap?['role'],
      orbit?['job_title'],
      orbit?['title'],
      orbit?['role_name'],
    ]) {
      final label = _nestedLabel(candidate);
      if (label != null) return label;
    }
    final rolesList = employeeMap?['roles'] ?? json['roles'];
    if (rolesList is List && rolesList.isNotEmpty) {
      final firstRole = _nestedLabel(rolesList.first);
      if (firstRole != null) return firstRole;
    }
    final assignments = employeeMap?['assignment_histories'] ??
        employeeMap?['assignmentHistories'];
    if (assignments is List && assignments.isNotEmpty) {
      for (final a in assignments.whereType<Map>()) {
        final label = _nestedLabel(a['primary_role'] ??
            a['primaryRole'] ??
            a['role'] ??
            a['role_name'] ??
            a['job_title'] ??
            a['position'] ??
            a['title']);
        if (label != null) return label;
      }
    }
    return null;
  }

  static String? _resolveDepartmentName(
    Map<String, dynamic> json,
    Map<String, dynamic>? employeeMap,
    Map<String, dynamic>? orbit,
  ) {
    for (final candidate in [
      json['department'],
      json['department_name'],
      json['departmentName'],
      json['division'],
      json['division_name'],
      employeeMap?['department'],
      employeeMap?['department_name'],
      employeeMap?['departmentName'],
      employeeMap?['division'],
      employeeMap?['division_name'],
      employeeMap?['unit'],
      employeeMap?['unit_name'],
      employeeMap?['section'],
      employeeMap?['organization'],
      employeeMap?['organization_name'],
      orbit?['department'],
      orbit?['department_name'],
    ]) {
      final label = _nestedLabel(candidate);
      if (label != null) return label;
    }
    final assignments = employeeMap?['assignment_histories'] ??
        employeeMap?['assignmentHistories'];
    if (assignments is List && assignments.isNotEmpty) {
      for (final a in assignments.whereType<Map>()) {
        final label = _nestedLabel(
            a['department'] ?? a['department_name'] ?? a['division']);
        if (label != null) return label;
      }
    }
    return null;
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null) return null;
    if (value is Map || value is List) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final orbit = json['orbit'] as Map<String, dynamic>?;

    // permissions is a List<String>
    List<String> perms = [];
    if (orbit?['permissions'] is List) {
      perms = (orbit!['permissions'] as List).map((e) => e.toString()).toList();
    }

    // modules is a Map<String, dynamic> (e.g. {"sales_order": {"enabled": true}, ...})
    Map<String, dynamic> mods = {};
    if (orbit?['modules'] is Map) {
      mods = Map<String, dynamic>.from(orbit!['modules'] as Map);
    } else if (orbit?['modules'] is List) {
      for (final item in (orbit!['modules'] as List)) {
        mods[item.toString()] = true;
      }
    }

    List<PasskeyCredentialModel> passkeys = [];
    if (json['passkeys'] is List) {
      passkeys = (json['passkeys'] as List)
          .whereType<Map>()
          .map((e) =>
              PasskeyCredentialModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final emailStr = _nonEmptyString(json['email']) ?? '';
    final defaultUsername =
        emailStr.contains('@') ? emailStr.split('@').first : null;
    final employeeMap = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : null;
    final rawPreferred = (json['preferred_name'] ??
            json['preferredName'] ??
            employeeMap?['preferred_name'] ??
            employeeMap?['preferredName'] ??
            orbit?['preferred_name'])
        ?.toString()
        .trim();

    final resolvedPhotoUrl = _nonEmptyString(json['profile_photo_url']) ??
        _nonEmptyString(employeeMap?['photo_url']) ??
        _nonEmptyString(employeeMap?['profile_photo_url']);

    final resolvedTitle = _resolveRoleTitle(json, employeeMap, orbit);
    final resolvedDepartment = _resolveDepartmentName(json, employeeMap, orbit);

    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: _nonEmptyString(json['name']) ??
          _nonEmptyString(employeeMap?['full_name']) ??
          _nonEmptyString(employeeMap?['name']) ??
          '',
      preferredName:
          (rawPreferred != null && rawPreferred.isNotEmpty) ? rawPreferred : null,
      email: emailStr.isNotEmpty
          ? emailStr
          : (_nonEmptyString(employeeMap?['work_email']) ??
              _nonEmptyString(employeeMap?['email']) ??
              ''),
      employeeId: (json['employee_id'] as num?)?.toInt() ??
          (employeeMap?['id'] as num?)?.toInt(),
      employeeUuid: _nonEmptyString(json['employee_uuid']) ??
          _nonEmptyString(employeeMap?['uuid']),
      employeeCode: _nonEmptyString(json['employee_code']) ??
          _nonEmptyString(employeeMap?['employee_code']) ??
          _nonEmptyString(employeeMap?['employee_id_number']) ??
          _nonEmptyString(employeeMap?['nik']),
      profilePhotoUrl: resolvedPhotoUrl,
      username: _nonEmptyString(json['username']) ?? defaultUsername,
      title: resolvedTitle,
      department: resolvedDepartment,
      permissions: perms,
      modules: mods,
      passkeys: passkeys,
      employee: employeeMap,
      rawJson: json,
    );
  }

  bool can(String permission) => permissions.contains(permission);

  bool hasModule(String module) {
    final mod = modules[module];
    if (mod is Map && mod['enabled'] == true) return true;
    if (mod is bool && mod == true) return true;
    return false;
  }
}
