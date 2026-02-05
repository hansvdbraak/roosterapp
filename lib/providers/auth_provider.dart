import 'package:flutter/foundation.dart';
import 'package:rooster_client/rooster_client.dart' as server;
import '../models/user.dart';
import '../models/user_session.dart';
import '../services/serverpod_client.dart';
import '../utils/password_validator.dart';

class AuthProvider extends ChangeNotifier {
  UserSession? _currentSession;
  server.User? _serverUser;
  List<server.User> _allUsers = [];

  UserSession? get currentSession => _currentSession;

  // Converteer server User naar lokale User
  User? get currentUser {
    if (_serverUser == null) return null;
    return _serverUserToLocal(_serverUser!);
  }

  bool get isLoggedIn => _currentSession != null;
  bool get isSuperuser => _currentSession?.isSuperuser ?? false;
  bool get isCoordinator => _currentSession?.isCoordinator ?? false;
  String get userName => _currentSession?.userName ?? '';
  UserRole get userRole => _currentSession?.role ?? UserRole.gebruikerEenvoud;

  List<User> get allUsers => _allUsers.map(_serverUserToLocal).toList();

  AuthProvider() {
    _loadAllUsers();
  }

  /// Laad alle gebruikers van de server
  Future<void> _loadAllUsers() async {
    try {
      _allUsers = await serverpodClient.auth.getAllUsers();
      notifyListeners();
    } catch (e) {
      debugPrint('Fout bij laden gebruikers: $e');
    }
  }

  /// Converteer server User naar lokale User
  User _serverUserToLocal(server.User serverUser) {
    return User(
      id: serverUser.id ?? 0,
      name: serverUser.name,
      email: serverUser.email,
      phoneNumber: serverUser.phoneNumber,
      passwordHash: serverUser.passwordHash,
      role: _stringToUserRole(serverUser.role),
      address: serverUser.address,
      postalCode: serverUser.postalCode,
      city: serverUser.city,
      comment: serverUser.comment,
      createdAt: serverUser.createdAt,
    );
  }

  /// Converteer rol string naar UserRole enum
  UserRole _stringToUserRole(String role) {
    switch (role) {
      case 'superuser':
        return UserRole.superuser;
      case 'coordinator':
        return UserRole.coordinator;
      case 'gebruiker':
        return UserRole.gebruiker;
      case 'gebruikerEenvoud':
      default:
        return UserRole.gebruikerEenvoud;
    }
  }

  /// Converteer UserRole enum naar string
  String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.superuser:
        return 'superuser';
      case UserRole.coordinator:
        return 'coordinator';
      case UserRole.gebruiker:
        return 'gebruiker';
      case UserRole.gebruikerEenvoud:
        return 'gebruikerEenvoud';
    }
  }

  /// Check of gebruikersnaam bestaat
  Future<bool> isUsernameRegistered(String username) async {
    try {
      return await serverpodClient.auth.isUsernameRegistered(username);
    } catch (e) {
      debugPrint('Fout bij controleren gebruikersnaam: $e');
      return false;
    }
  }

  /// Registreer nieuwe gebruiker
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String address,
    required String postalCode,
    required String city,
    String? comment,
  }) async {
    // Client-side validatie
    if (name.trim().isEmpty) {
      throw Exception('Naam mag niet leeg zijn');
    }

    final validation = PasswordValidator.validate(password);
    if (!validation.isValid) {
      throw Exception('Wachtwoord voldoet niet aan de eisen:\n${validation.errors.join('\n')}');
    }

    try {
      final session = await serverpodClient.auth.register(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        address: address,
        postalCode: postalCode,
        city: city,
        comment: comment,
      );

      // Haal gebruiker op
      final user = await serverpodClient.auth.getUserById(session.userId);
      _serverUser = user;

      _currentSession = UserSession(
        userName: session.userName,
        role: _stringToUserRole(session.role),
      );

      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Login met gebruikersnaam en wachtwoord
  Future<void> loginWithUsername({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty) {
      throw Exception('Voer je gebruikersnaam in');
    }

    if (password.isEmpty) {
      throw Exception('Voer je wachtwoord in');
    }

    try {
      final session = await serverpodClient.auth.login(
        username: username,
        password: password,
      );

      // Haal gebruiker op
      final user = await serverpodClient.auth.getUserById(session.userId);
      _serverUser = user;

      _currentSession = UserSession(
        userName: session.userName,
        role: _stringToUserRole(session.role),
      );

      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNKNOWN_USER')) {
        throw Exception('UNKNOWN_USER');
      }
      throw Exception(errorMsg.replaceAll('Exception: ', ''));
    }
  }

  /// Gebruiker rol wijzigen (alleen voor superuser)
  Future<void> updateUserRole({
    required int userId,
    required UserRole newRole,
  }) async {
    if (_currentSession == null || !_currentSession!.canAssignRoles) {
      throw Exception('Geen rechten om rollen te wijzigen');
    }

    if (newRole == UserRole.superuser) {
      throw Exception('Superuser rol kan niet worden toegekend');
    }

    if (_serverUser?.id == userId) {
      throw Exception('Je kunt je eigen rol niet wijzigen');
    }

    try {
      await serverpodClient.auth.updateUserRole(
        userId: userId,
        newRole: _userRoleToString(newRole),
      );

      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update eigen profiel
  Future<void> updateProfile({
    required String email,
    required String phoneNumber,
    required String address,
    required String postalCode,
    required String city,
    String? comment,
    String? newPassword,
  }) async {
    if (_serverUser == null) {
      throw Exception('Niet ingelogd');
    }

    // Client-side validatie
    if (newPassword != null && newPassword.isNotEmpty) {
      final validation = PasswordValidator.validate(newPassword);
      if (!validation.isValid) {
        throw Exception('Wachtwoord voldoet niet aan de eisen:\n${validation.errors.join('\n')}');
      }
    }

    try {
      final updatedUser = await serverpodClient.auth.updateProfile(
        userId: _serverUser!.id!,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        postalCode: postalCode,
        city: city,
        comment: comment,
        newPassword: newPassword,
      );

      _serverUser = updatedUser;

      // Update sessie met mogelijk gewijzigde gegevens
      _currentSession = UserSession(
        userName: updatedUser.name,
        role: _stringToUserRole(updatedUser.role),
      );

      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Verwijder gebruiker (alleen voor superuser)
  Future<void> deleteUser(int userId) async {
    if (_currentSession == null || !_currentSession!.isSuperuser) {
      throw Exception('Geen rechten om gebruikers te verwijderen');
    }

    if (_serverUser?.id == userId) {
      throw Exception('Je kunt jezelf niet verwijderen');
    }

    try {
      await serverpodClient.auth.deleteUser(userId);
      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Uitloggen
  Future<void> logout() async {
    _currentSession = null;
    _serverUser = null;
    notifyListeners();
  }

  /// Helper om gebruikers per rol te krijgen
  List<User> getUsersByRole(UserRole role) {
    final roleString = _userRoleToString(role);
    return _allUsers
        .where((u) => u.role == roleString)
        .map(_serverUserToLocal)
        .toList();
  }

  /// Krijg gebruiker op ID
  User? getUserById(int id) {
    try {
      final serverUser = _allUsers.firstWhere((u) => u.id == id);
      return _serverUserToLocal(serverUser);
    } catch (e) {
      return null;
    }
  }

  /// Krijg gebruiker op naam
  User? getUserByName(String name) {
    try {
      final serverUser = _allUsers.firstWhere((u) => u.name == name);
      return _serverUserToLocal(serverUser);
    } catch (e) {
      return null;
    }
  }

  /// Refresh gebruikers van server
  Future<void> refreshUsers() async {
    await _loadAllUsers();
  }

  /// Update commentaar voor een gebruiker (alleen voor superuser)
  Future<void> updateUserComment({
    required int userId,
    required String comment,
  }) async {
    if (_currentSession == null || !_currentSession!.isSuperuser) {
      throw Exception('Geen rechten om commentaar te wijzigen');
    }

    try {
      await serverpodClient.auth.updateUserComment(
        userId: userId,
        comment: comment,
      );
      await _loadAllUsers();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
