// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/serverpod_client.dart';
import '../models/reservation.dart';

String _slotToTime(int i) {
  final h = 8 + (i ~/ 2);
  final m = (i % 2) * 30;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Berekent jaar en kwartaal voor huidig en vorig kwartaal.
/// Geeft een lijst terug van [(label, year, quarter)].
List<(String, int, int)> getQuarterOptions() {
  final now = DateTime.now();
  final currentQuarter = ((now.month - 1) ~/ 3) + 1;
  final currentYear = now.year;

  final prevQuarter = currentQuarter == 1 ? 4 : currentQuarter - 1;
  final prevYear = currentQuarter == 1 ? currentYear - 1 : currentYear;

  return [
    ('Huidig kwartaal (Q$currentQuarter $currentYear)', currentYear, currentQuarter),
    ('Vorig kwartaal (Q$prevQuarter $prevYear)', prevYear, prevQuarter),
  ];
}

Future<void> exportReservationsCSV({required int year, required int quarter}) async {
  final serverReservations = await serverpodClient.reservation
      .getReservationsForQuarter(year: year, quarter: quarter);

  final serverRooms = await serverpodClient.room.getRooms();
  final roomMap = {for (final r in serverRooms) r.id: r.name};

  // Convert and sort by bookerName, date, slotIndex
  final reservations = serverReservations
      .map((r) => Reservation(
            id: r.id ?? 0,
            roomId: r.roomId,
            bookerName: r.bookerName,
            date: r.date,
            slotIndex: r.slotIndex,
            createdAt: r.createdAt,
          ))
      .toList()
    ..sort((a, b) {
      final nameCmp = a.bookerName.compareTo(b.bookerName);
      if (nameCmp != 0) return nameCmp;
      final dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      return a.slotIndex.compareTo(b.slotIndex);
    });

  final buffer = StringBuffer();
  buffer.writeln('Gebruiker;Ruimte;Datum;Begintijd;Eindtijd;Geboekt op');

  // Groepeer per gebruiker om totaalregel toe te voegen
  String? currentUser;
  int slotCount = 0;

  for (int i = 0; i < reservations.length; i++) {
    final r = reservations[i];

    // Nieuwe gebruiker: schrijf totaalregel voor vorige gebruiker
    if (currentUser != null && r.bookerName != currentUser) {
      _writeTotaal(buffer, currentUser, slotCount);
      slotCount = 0;
    }

    currentUser = r.bookerName;
    slotCount++;

    final roomName = roomMap[r.roomId] ?? 'Onbekend';
    final datum =
        '${r.date.day.toString().padLeft(2, '0')}-${r.date.month.toString().padLeft(2, '0')}-${r.date.year}';
    final begintijd = _slotToTime(r.slotIndex);
    final eindtijd = _slotToTime(r.slotIndex + 1);
    final geboektOp =
        '${r.createdAt.day.toString().padLeft(2, '0')}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.year}';

    buffer.writeln(
        '${_escape(r.bookerName)};${_escape(roomName)};$datum;$begintijd;$eindtijd;$geboektOp');
  }

  // Totaalregel voor de laatste gebruiker
  if (currentUser != null) {
    _writeTotaal(buffer, currentUser, slotCount);
  }

  final csvContent = buffer.toString();
  final bytes = html.Blob([csvContent], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..setAttribute('download', 'reserveringen_Q${quarter}_$year.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
}

void _writeTotaal(StringBuffer buffer, String bookerName, int slotCount) {
  final totalMinutes = slotCount * 30;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final totaalLabel =
      minutes == 0 ? '$hours uur' : '$hours uur $minutes min';
  buffer.writeln('${_escape(bookerName)};TOTAAL;;;$totaalLabel;;');
}

String _escape(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
