class TimeSlot {
  final DateTime date;
  final int slotIndex; // 0-27

  TimeSlot({
    required this.date,
    required this.slotIndex,
  });

  DateTime get startTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      8 + (slotIndex ~/ 2),
      (slotIndex % 2) * 30,
    );
  }

  DateTime get endTime {
    return startTime.add(const Duration(minutes: 30));
  }

  String getDisplayTime() {
    final startHour = startTime.hour.toString().padLeft(2, '0');
    final startMinute = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMinute - $endHour:$endMinute';
  }

  static List<TimeSlot> generateSlotsForDate(DateTime date) {
    return List.generate(28, (index) => TimeSlot(date: date, slotIndex: index));
  }
}
