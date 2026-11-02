/// Same six roles the JWT and every API carry.
const allRoles = ['ADMIN', 'COORDINATOR', 'TRAINER', 'STUDENT', 'PLACEMENT', 'FINANCE'];

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.roleDisplayName,
    required this.extraRoles,
    required this.mustChangePassword,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;
  final String roleDisplayName;
  final List<String> extraRoles;
  final bool mustChangePassword;

  /// Main role plus extra duties; never compare [role] directly for access.
  List<String> get roles => [role, ...extraRoles];

  bool hasRole(List<String> wanted) => roles.any(wanted.contains);

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        fullName: j['fullName'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: j['role'] as String,
        roleDisplayName: j['roleDisplayName'] as String? ?? j['role'] as String,
        extraRoles: ((j['extraRoles'] as List?) ?? const []).cast<String>(),
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
      );
}

class AuthResponse {
  AuthResponse(this.accessToken, this.refreshToken, this.expiresIn, this.user);

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        j['accessToken'] as String,
        j['refreshToken'] as String,
        (j['expiresIn'] as num).toInt(),
        AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}
