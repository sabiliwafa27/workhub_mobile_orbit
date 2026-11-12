class UserModel {
  final int id;
  final String name;
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

  UserModel({
    required this.id,
    required this.name,
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
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final orbit = json['orbit'] as Map<String, dynamic>?;

    // permissions is a List<String>
    List<String> perms = [];
    if (orbit?['permissions'] is List) {
      perms = (orbit!['permissions'] as List)
          .map((e) => e.toString())
          .toList();
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

    final emailStr = json['email'] as String? ?? '';
    final defaultUsername = emailStr.contains('@') ? emailStr.split('@').first : null;

    return UserModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: emailStr,
      employeeId: json['employee_id'] as int?,
      employeeUuid: json['employee_uuid'] as String?,
      employeeCode: json['employee_code'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      username: json['username'] as String? ?? defaultUsername,
      title: json['title'] as String? ?? json['job_title'] as String? ?? json['position'] as String?,
      department: json['department'] as String? ?? json['division'] as String?,
      permissions: perms,
      modules: mods,
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
