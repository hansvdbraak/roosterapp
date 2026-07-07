class Reservation {
  final int id;
  final int roomId;
  final String bookerName;
  final DateTime date;
  final int slotIndex; // 0-27 (8:00-22:00, blokken van 30 min)
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.roomId,
    required this.bookerName,
    required this.date,
    required this.slotIndex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Reservation copyWith({
    int? id,
    int? roomId,
    String? bookerName,
    DateTime? date,
    int? slotIndex,
    DateTime? createdAt,
  }) {
    return Reservation(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      bookerName: bookerName ?? this.bookerName,
      date: date ?? this.date,
      slotIndex: slotIndex ?? this.slotIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
