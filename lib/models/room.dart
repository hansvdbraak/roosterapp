class Room {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl; // URL naar ruimte afbeelding
  final DateTime createdAt;
  final bool isObsolete; // Overbodig - niet meer te boeken maar wel zichtbaar

  Room({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    DateTime? createdAt,
    this.isObsolete = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Kan deze ruimte geboekt worden?
  bool get isBookable => !isObsolete;

  Room copyWith({
    int? id,
    String? name,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    bool? isObsolete,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      isObsolete: isObsolete ?? this.isObsolete,
    );
  }
}
