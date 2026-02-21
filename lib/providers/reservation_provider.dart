import 'package:flutter/foundation.dart';
import 'package:rooster_client/rooster_client.dart' as server;
import '../models/reservation.dart';
import '../models/user.dart';
import '../services/serverpod_client.dart';

class ReservationProvider extends ChangeNotifier {
  // Cache voor reserveringen per ruimte/datum
  final Map<String, List<server.Reservation>> _reservationCache = {};

  List<Reservation> get reservations {
    final all = <Reservation>[];
    for (final list in _reservationCache.values) {
      all.addAll(list.map(_serverReservationToLocal));
    }
    return all;
  }

  ReservationProvider();

  /// Converteer server Reservation naar lokale Reservation
  Reservation _serverReservationToLocal(server.Reservation serverRes) {
    return Reservation(
      id: serverRes.id ?? 0,
      roomId: serverRes.roomId,
      bookerName: serverRes.bookerName,
      date: serverRes.date,
      slotIndex: serverRes.slotIndex,
    );
  }

  /// Cache key voor ruimte/datum combinatie
  String _cacheKey(int roomId, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return '${roomId}_${dateOnly.toIso8601String()}';
  }

  /// Laad reserveringen voor een ruimte op een datum
  Future<void> loadReservations(int roomId, DateTime date) async {
    try {
      final serverReservations = await serverpodClient.reservation
          .getReservationsForRoom(roomId: roomId, date: date);
      _reservationCache[_cacheKey(roomId, date)] = serverReservations;
      notifyListeners();
    } catch (e) {
      debugPrint('Fout bij laden reserveringen: $e');
    }
  }

  List<Reservation> getReservationsForRoom(int roomId, DateTime date) {
    final key = _cacheKey(roomId, date);
    final cached = _reservationCache[key];
    if (cached == null) {
      // Laad async, return lege lijst voor nu
      loadReservations(roomId, date);
      return [];
    }
    return cached.map(_serverReservationToLocal).toList();
  }

  Reservation? getReservationForSlot(int roomId, DateTime date, int slotIndex) {
    final reservations = getReservationsForRoom(roomId, date);
    try {
      return reservations.firstWhere((r) => r.slotIndex == slotIndex);
    } catch (e) {
      return null;
    }
  }

  bool isSlotAvailable(int roomId, DateTime date, int slotIndex) {
    return getReservationForSlot(roomId, date, slotIndex) == null;
  }

  Future<Reservation> createReservation({
    required int roomId,
    required String bookerName,
    required DateTime date,
    required int slotIndex,
  }) async {
    if (bookerName.trim().isEmpty) {
      throw Exception('Boeker naam mag niet leeg zijn');
    }

    try {
      final serverRes = await serverpodClient.reservation.createReservation(
        roomId: roomId,
        bookerName: bookerName,
        date: date,
        slotIndex: slotIndex,
      );

      // Refresh cache
      await loadReservations(roomId, date);
      return _serverReservationToLocal(serverRes);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> cancelReservation({
    required int reservationId,
    required String userName,
    required bool isSuperuser,
  }) async {
    try {
      await serverpodClient.reservation.cancelReservation(
        reservationId: reservationId,
        userName: userName,
        isAdmin: isSuperuser,
      );

      // Clear cache om te forceren dat data opnieuw geladen wordt
      _reservationCache.clear();
      notifyListeners();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Check of een volledig dagdeel beschikbaar is
  bool isDayPartAvailable(int roomId, DateTime date, DayPart dayPart) {
    for (int i = dayPart.startSlotIndex; i < dayPart.endSlotIndex; i++) {
      if (!isSlotAvailable(roomId, date, i)) {
        return false;
      }
    }
    return true;
  }

  /// Krijg bezetting status van een dagdeel (voor UI)
  DayPartStatus getDayPartStatus(
      int roomId, DateTime date, DayPart dayPart, String currentUser) {
    int bookedByUser = 0;
    int bookedByOthers = 0;
    int available = 0;
    String? firstOtherBookerName;

    for (int i = dayPart.startSlotIndex; i < dayPart.endSlotIndex; i++) {
      final reservation = getReservationForSlot(roomId, date, i);
      if (reservation == null) {
        available++;
      } else if (reservation.bookerName == currentUser) {
        bookedByUser++;
      } else {
        bookedByOthers++;
        firstOtherBookerName ??= reservation.bookerName;
      }
    }

    return DayPartStatus(
      dayPart: dayPart,
      bookedByUser: bookedByUser,
      bookedByOthers: bookedByOthers,
      available: available,
      firstOtherBookerName: firstOtherBookerName,
    );
  }

  /// Boek een volledig dagdeel (voor eenvoudige gebruikers)
  Future<List<Reservation>> createDayPartReservation({
    required int roomId,
    required String bookerName,
    required DateTime date,
    required DayPart dayPart,
  }) async {
    if (bookerName.trim().isEmpty) {
      throw Exception('Boeker naam mag niet leeg zijn');
    }

    // Check of alle slots in het dagdeel beschikbaar zijn
    for (int i = dayPart.startSlotIndex; i < dayPart.endSlotIndex; i++) {
      if (!isSlotAvailable(roomId, date, i)) {
        throw Exception('${dayPart.displayName} is niet volledig beschikbaar');
      }
    }

    try {
      // Maak lijst van slot indices
      final slotIndices = <int>[];
      for (int i = dayPart.startSlotIndex; i < dayPart.endSlotIndex; i++) {
        slotIndices.add(i);
      }

      final serverReservations =
          await serverpodClient.reservation.createMultipleReservations(
        roomId: roomId,
        bookerName: bookerName,
        date: date,
        slotIndices: slotIndices,
      );

      // Refresh cache
      await loadReservations(roomId, date);
      return serverReservations.map(_serverReservationToLocal).toList();
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Annuleer alle reserveringen in een dagdeel
  Future<void> cancelDayPartReservation({
    required int roomId,
    required DateTime date,
    required DayPart dayPart,
    required String userName,
    required bool isSuperuser,
  }) async {
    // Maak lijst van slot indices
    final slotIndices = <int>[];
    for (int i = dayPart.startSlotIndex; i < dayPart.endSlotIndex; i++) {
      slotIndices.add(i);
    }

    try {
      await serverpodClient.reservation.cancelDayPartReservations(
        roomId: roomId,
        bookerName: userName,
        date: date,
        slotIndices: slotIndices,
      );

      // Refresh cache
      await loadReservations(roomId, date);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<List<Reservation>> getReservationsByUser(String userName) async {
    try {
      final serverReservations = await serverpodClient.reservation
          .getReservationsByUser(bookerName: userName);
      return serverReservations.map(_serverReservationToLocal).toList();
    } catch (e) {
      debugPrint('Fout bij laden reserveringen voor gebruiker: $e');
      return [];
    }
  }

  // Helper: check of een ruimte reserveringen heeft voor vandaag
  bool roomHasReservationsToday(int roomId) {
    final today = DateTime.now();
    final reservations = getReservationsForRoom(roomId, today);
    return reservations.isNotEmpty;
  }

  // Helper: krijg volgende reservering voor een ruimte vandaag
  Reservation? getNextReservationToday(int roomId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentSlotIndex = ((now.hour - 8) * 2) + (now.minute >= 30 ? 1 : 0);

    final todayReservations = getReservationsForRoom(roomId, today)
        .where((r) => r.slotIndex >= currentSlotIndex)
        .toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

    return todayReservations.isEmpty ? null : todayReservations.first;
  }

  /// Clear cache en refresh data
  Future<void> refresh(int roomId, DateTime date) async {
    _reservationCache.remove(_cacheKey(roomId, date));
    await loadReservations(roomId, date);
  }

  /// Clear alle cache
  void clearCache() {
    _reservationCache.clear();
    notifyListeners();
  }
}

/// Status van een dagdeel voor de UI
class DayPartStatus {
  final DayPart dayPart;
  final int bookedByUser;
  final int bookedByOthers;
  final int available;
  final String? firstOtherBookerName;

  DayPartStatus({
    required this.dayPart,
    required this.bookedByUser,
    required this.bookedByOthers,
    required this.available,
    this.firstOtherBookerName,
  });

  int get totalSlots => bookedByUser + bookedByOthers + available;
  bool get isFullyAvailable => available == totalSlots;
  bool get isFullyBookedByUser => bookedByUser == totalSlots;
  bool get hasAnyBookings => bookedByUser > 0 || bookedByOthers > 0;
  bool get isPartiallyBooked => hasAnyBookings && available > 0;
}
