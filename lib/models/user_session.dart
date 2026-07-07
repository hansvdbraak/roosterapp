import 'user.dart';

class UserSession {
  final String userName;
  final UserRole role;

  UserSession({
    required this.userName,
    required this.role,
  });

  bool get isSuperuser => role == UserRole.superuser;
  bool get isCoordinator => role == UserRole.coordinator || role == UserRole.superuser;
  bool get canBookHalfHour => role.canBookHalfHour;
  bool get canOnlyBookDayParts => role.canOnlyBookDayParts;
  bool get canViewPersonBreakdown => role.canViewPersonBreakdown;
  bool get canManageRooms => role.canManageRooms;
  bool get canAssignRoles => role.canAssignRoles;

  UserSession copyWith({
    String? userName,
    UserRole? role,
  }) {
    return UserSession(
      userName: userName ?? this.userName,
      role: role ?? this.role,
    );
  }
}
