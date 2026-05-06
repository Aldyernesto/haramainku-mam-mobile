enum UserRole { admin, fieldCrew, editor }

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: _parseRole(json['role']),
      active: json['active'] ?? true,
      avatarUrl: json['avatarUrl'],
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'ADMIN':
        return UserRole.admin;
      case 'FIELD_CREW':
        return UserRole.fieldCrew;
      case 'EDITOR':
        return UserRole.editor;
      default:
        return UserRole.editor;
    }
  }

  String get roleLabel {
    switch (role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.fieldCrew:
        return 'FIELD_CREW';
      case UserRole.editor:
        return 'EDITOR';
    }
  }

  bool get canUpload => role == UserRole.admin || role == UserRole.fieldCrew;
  bool get canDownload => role == UserRole.admin || role == UserRole.editor;
  bool get canManageUsers => role == UserRole.admin;
  bool get isAdmin => role == UserRole.admin;
}
