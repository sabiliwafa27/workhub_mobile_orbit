class UserModel {
  final int id;
  final String name;
  final String email;
  final int? employeeId;
  final String? employeeUuid;
  final String? employeeCode;
  final String? profilePhotoUrl;
  final List<String> permissions;
  final List<String> modules;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.employeeId,
    this.employeeUuid,
    this.employeeCode,
    this.profilePhotoUrl,
    required this.permissions,
    required this.modules,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final orbit = json['orbit'] as Map<String, dynamic>?;
    final perms = (orbit?['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final mods = (orbit?['modules'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      employeeId: json['employee_id'] as int?,
      employeeUuid: json['employee_uuid'] as String?,
      employeeCode: json['employee_code'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      permissions: perms,
      modules: mods,
    );
  }

  bool can(String permission) => permissions.contains(permission);
  bool hasModule(String module) => modules.contains(module);
}
