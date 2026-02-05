enum UserRole {
  gebruikerEenvoud, // Kan boeken in dagdelen (ochtend/middag/avond)
  gebruiker,        // Kan boeken per 30 minuten
  coordinator,      // + weekoverzichten met uitsplitsing per persoon
  superuser,        // + ruimtes beheren, rollen toewijzen
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.gebruikerEenvoud:
        return 'Eenvoudige gebruiker';
      case UserRole.gebruiker:
        return 'Gebruiker';
      case UserRole.coordinator:
        return 'Coördinator';
      case UserRole.superuser:
        return 'Superuser';
    }
  }

  String get description {
    switch (this) {
      case UserRole.gebruikerEenvoud:
        return 'Kan ruimtes boeken per dagdeel (ochtend/middag/avond)';
      case UserRole.gebruiker:
        return 'Kan ruimtes boeken per 30 minuten';
      case UserRole.coordinator:
        return 'Gebruiker + weekoverzichten met uitsplitsing per persoon';
      case UserRole.superuser:
        return 'Coördinator + ruimtes en rollen beheren';
    }
  }

  /// Kan per 30 minuten boeken (gebruiker en hoger)
  bool get canBookHalfHour =>
      this == UserRole.gebruiker ||
      this == UserRole.coordinator ||
      this == UserRole.superuser;

  /// Kan alleen per dagdeel boeken
  bool get canOnlyBookDayParts => this == UserRole.gebruikerEenvoud;

  /// Kan weekoverzichten met personen zien
  bool get canViewPersonBreakdown =>
      this == UserRole.coordinator ||
      this == UserRole.superuser;

  /// Kan ruimtes aanmaken/overbodig maken
  bool get canManageRooms => this == UserRole.superuser;

  /// Kan rollen toewijzen (eenvoud t/m coordinator)
  bool get canAssignRoles => this == UserRole.superuser;

  /// Niveau van de rol (voor vergelijking)
  int get level {
    switch (this) {
      case UserRole.gebruikerEenvoud:
        return 0;
      case UserRole.gebruiker:
        return 1;
      case UserRole.coordinator:
        return 2;
      case UserRole.superuser:
        return 3;
    }
  }
}

/// Dagdeel voor eenvoudige gebruikers
enum DayPart {
  ochtend,  // 10:00 - 13:00
  middag,   // 13:00 - 16:00
  avond,    // 19:00 - 22:00
}

extension DayPartExtension on DayPart {
  String get displayName {
    switch (this) {
      case DayPart.ochtend:
        return 'Ochtend';
      case DayPart.middag:
        return 'Middag';
      case DayPart.avond:
        return 'Avond';
    }
  }

  String get timeRange {
    switch (this) {
      case DayPart.ochtend:
        return '10:00 - 13:00';
      case DayPart.middag:
        return '13:00 - 16:00';
      case DayPart.avond:
        return '19:00 - 22:00';
    }
  }

  /// Start slot index (0 = 08:00, elke slot = 30 min)
  int get startSlotIndex {
    switch (this) {
      case DayPart.ochtend:
        return 4;  // 10:00
      case DayPart.middag:
        return 10; // 13:00
      case DayPart.avond:
        return 22; // 19:00
    }
  }

  /// Eind slot index (exclusive)
  int get endSlotIndex {
    switch (this) {
      case DayPart.ochtend:
        return 10; // tot 13:00
      case DayPart.middag:
        return 16; // tot 16:00
      case DayPart.avond:
        return 28; // tot 22:00
    }
  }

  /// Aantal slots in dit dagdeel
  int get slotCount => endSlotIndex - startSlotIndex;

  /// Bepaal dagdeel van een slot index (null als buiten dagdelen)
  static DayPart? fromSlotIndex(int slotIndex) {
    if (slotIndex >= 4 && slotIndex < 10) return DayPart.ochtend;
    if (slotIndex >= 10 && slotIndex < 16) return DayPart.middag;
    if (slotIndex >= 22 && slotIndex < 28) return DayPart.avond;
    return null; // Buiten dagdelen (08:00-10:00, 16:00-19:00)
  }
}

class User {
  final int id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String passwordHash;
  final UserRole role;
  final DateTime createdAt;

  // NAW gegevens
  final String? address;
  final String? postalCode;
  final String? city;

  // Commentaar (zichtbaar voor superuser)
  final String? comment;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.passwordHash,
    this.role = UserRole.gebruikerEenvoud,
    DateTime? createdAt,
    this.address,
    this.postalCode,
    this.city,
    this.comment,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isSuperuser => role == UserRole.superuser;
  bool get isCoordinator => role == UserRole.coordinator || role == UserRole.superuser;
  bool get canBookHalfHour => role.canBookHalfHour;

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? passwordHash,
    UserRole? role,
    DateTime? createdAt,
    String? address,
    String? postalCode,
    String? city,
    String? comment,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      comment: comment ?? this.comment,
    );
  }
}
