import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/room_provider.dart';
import '../models/room.dart';
import '../models/time_slot.dart';
import '../models/reservation.dart';
import '../models/user.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  final DateTime initialDate;

  const RoomDetailScreen({
    super.key,
    required this.room,
    required this.initialDate,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _previousDay() {
    final newDate = _selectedDate.subtract(const Duration(days: 1));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (!newDate.isBefore(todayDate)) {
      setState(() => _selectedDate = newDate);
    }
  }

  void _nextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
  }

  Future<void> _bookSlot(TimeSlot slot) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Boeking'),
        content: Text(
          'Wil je ${widget.room.name} boeken op ${slot.getDisplayTime()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Boeken'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await reservationProvider.createReservation(
          roomId: widget.room.id,
          bookerName: authProvider.userName,
          date: _selectedDate,
          slotIndex: slot.slotIndex,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservering aangemaakt!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Annulering'),
        content: Text(
          'Wil je de reservering van ${reservation.bookerName} annuleren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Terug'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuleren'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await reservationProvider.cancelReservation(
          reservationId: reservation.id,
          userName: authProvider.userName,
          isSuperuser: authProvider.isSuperuser,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reservering geannuleerd'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _bookDayPart(DayPart dayPart) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Boeking'),
        content: Text(
          'Wil je ${widget.room.name} boeken voor de ${dayPart.displayName.toLowerCase()} (${dayPart.timeRange})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Boeken'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await reservationProvider.createDayPartReservation(
          roomId: widget.room.id,
          bookerName: authProvider.userName,
          date: _selectedDate,
          dayPart: dayPart,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${dayPart.displayName} geboekt!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelDayPart(DayPart dayPart) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Annulering'),
        content: Text(
          'Wil je alle reserveringen in de ${dayPart.displayName.toLowerCase()} annuleren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Terug'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuleren'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await reservationProvider.cancelDayPartReservation(
          roomId: widget.room.id,
          date: _selectedDate,
          dayPart: dayPart,
          userName: authProvider.userName,
          isSuperuser: authProvider.isSuperuser,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${dayPart.displayName} geannuleerd'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteRoom() async {
    final roomProvider = context.read<RoomProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ruimte Verwijderen'),
        content: Text(
          'Weet je zeker dat je "${widget.room.name}" permanent wilt verwijderen?\n\nDit kan niet ongedaan worden gemaakt en alle reserveringen voor deze ruimte worden ook verwijderd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await roomProvider.deleteRoom(widget.room.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ruimte verwijderd'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop(); // Ga terug naar room list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canBookHalfHour = authProvider.currentSession?.canBookHalfHour ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          if (authProvider.isSuperuser)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteRoom();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Verwijderen', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Room info & date navigation
          _buildHeader(context),

          // Warning als ruimte overbodig is
          if (widget.room.isObsolete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deze ruimte is niet meer beschikbaar voor nieuwe boekingen',
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

          // Booking interface
          Expanded(
            child: widget.room.isObsolete
                ? _buildObsoleteRoomView(context)
                : canBookHalfHour
                    ? _buildSlotView(context)
                    : _buildDayPartView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.room.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.room.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousDay,
                icon: const Icon(Icons.chevron_left),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE d MMMM', 'nl').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _nextDay,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObsoleteRoomView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Ruimte niet beschikbaar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Deze ruimte is gemarkeerd als overbodig en kan niet meer geboekt worden.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dagdeel weergave voor eenvoudige gebruikers - in kolommen
  Widget _buildDayPartView(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Boek per dagdeel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          // Dagdelen naast elkaar in een Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: DayPart.values.map((dayPart) {
              final status = reservationProvider.getDayPartStatus(
                widget.room.id,
                _selectedDate,
                dayPart,
                authProvider.userName,
              );

              // Check of dagdeel in het verleden is
              final dayPartStart = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                8 + (dayPart.startSlotIndex ~/ 2),
                (dayPart.startSlotIndex % 2) * 30,
              );
              final isPast = dayPartStart.isBefore(now);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: dayPart != DayPart.avond ? 8 : 0,
                  ),
                  child: _DayPartCardCompact(
                    dayPart: dayPart,
                    status: status,
                    isPast: isPast,
                    isSuperuser: authProvider.isSuperuser,
                    currentUser: authProvider.userName,
                    onBook: () => _bookDayPart(dayPart),
                    onCancel: () => _cancelDayPart(dayPart),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Slot weergave voor normale gebruikers (per 30 min) - in kolommen
  Widget _buildSlotView(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final slots = TimeSlot.generateSlotsForDate(_selectedDate);
    final now = DateTime.now();

    // Verdeel slots in 3 kolommen gebaseerd op tijd
    // Kolom 1: Tot 13:00 (slots 0-9)
    // Kolom 2: 13:00-17:00 (slots 10-17)
    // Kolom 3: 19:00-22:00 (slots 22-27)
    final col1Slots = slots.where((s) => s.slotIndex >= 0 && s.slotIndex <= 9).toList();
    final col2Slots = slots.where((s) => s.slotIndex >= 10 && s.slotIndex <= 17).toList();
    final col3Slots = slots.where((s) => s.slotIndex >= 22 && s.slotIndex <= 27).toList();

    Widget buildSlotColumn(List<TimeSlot> columnSlots, String title, Color headerColor) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kolom header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: headerColor.withAlpha((255 * 0.15).round()),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: headerColor,
                ),
              ),
            ),
            // Slots
            ...columnSlots.map((slot) {
              final reservation = reservationProvider.getReservationForSlot(
                widget.room.id,
                _selectedDate,
                slot.slotIndex,
              );

              final isAvailable = reservation == null;
              final isOwnReservation = reservation?.bookerName == authProvider.userName;
              final canCancel = isOwnReservation || authProvider.isSuperuser;
              final isPast = slot.startTime.isBefore(now);

              return _SlotTile(
                slot: slot,
                reservation: reservation,
                isAvailable: isAvailable,
                isOwnReservation: isOwnReservation,
                canCancel: canCancel,
                isPast: isPast,
                onBook: () => _bookSlot(slot),
                onCancel: reservation != null ? () => _cancelReservation(reservation) : null,
              );
            }),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Boek per half uur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSlotColumn(col1Slots, 'Tot 13:00', Colors.orange),
              const SizedBox(width: 8),
              buildSlotColumn(col2Slots, '13:00-17:00', Colors.blue),
              const SizedBox(width: 8),
              buildSlotColumn(col3Slots, '19:00-22:00', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayPartCard extends StatelessWidget {
  final DayPart dayPart;
  final DayPartStatus status;
  final bool isPast;
  final bool isSuperuser;
  final String currentUser;
  final VoidCallback onBook;
  final VoidCallback onCancel;

  const _DayPartCard({
    required this.dayPart,
    required this.status,
    required this.isPast,
    required this.isSuperuser,
    required this.currentUser,
    required this.onBook,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canBook = !isPast && status.isFullyAvailable;
    final canCancel = !isPast && (status.bookedByUser > 0 || (isSuperuser && status.hasAnyBookings));

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPast) {
      statusColor = Colors.grey;
      statusText = 'Verstreken';
      statusIcon = Icons.history;
    } else if (status.isFullyAvailable) {
      statusColor = Colors.green;
      statusText = 'Beschikbaar';
      statusIcon = Icons.check_circle;
    } else if (status.isFullyBookedByUser) {
      statusColor = Colors.blue;
      statusText = 'Door jou geboekt';
      statusIcon = Icons.event_available;
    } else if (status.bookedByOthers == status.totalSlots) {
      statusColor = Colors.red;
      statusText = 'Volledig bezet';
      statusIcon = Icons.event_busy;
    } else {
      statusColor = Colors.orange;
      statusText = 'Gedeeltelijk bezet';
      statusIcon = Icons.event_note;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayPart.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isPast ? Colors.grey : null,
                            ),
                      ),
                      Text(
                        dayPart.timeRange,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isPast ? Colors.grey : Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (!isPast && status.isPartiallyBooked) ...[
              const SizedBox(height: 12),
              _buildOccupancyBar(context),
            ],
            if (!isPast && (canBook || canCancel)) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Annuleer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  if (canCancel && canBook) const SizedBox(width: 8),
                  if (canBook)
                    ElevatedButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Boek'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyBar(BuildContext context) {
    final total = status.totalSlots.toDouble();
    final userFraction = status.bookedByUser / total;
    final othersFraction = status.bookedByOthers / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bezetting: ${status.bookedByUser + status.bookedByOthers}/${status.totalSlots} slots',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (userFraction > 0)
                  Expanded(
                    flex: (userFraction * 100).round(),
                    child: Container(color: Colors.blue),
                  ),
                if (othersFraction > 0)
                  Expanded(
                    flex: (othersFraction * 100).round(),
                    child: Container(color: Colors.red),
                  ),
                if (status.available > 0)
                  Expanded(
                    flex: ((status.available / total) * 100).round(),
                    child: Container(color: Colors.grey[300]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (status.bookedByUser > 0) ...[
              Container(width: 8, height: 8, color: Colors.blue),
              const SizedBox(width: 4),
              Text('Jij (${status.bookedByUser})',
                  style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 8),
            ],
            if (status.bookedByOthers > 0) ...[
              Container(width: 8, height: 8, color: Colors.red),
              const SizedBox(width: 4),
              Text('Anderen (${status.bookedByOthers})',
                  style: const TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compacte dagdeel kaart voor kolom-layout
class _DayPartCardCompact extends StatelessWidget {
  final DayPart dayPart;
  final DayPartStatus status;
  final bool isPast;
  final bool isSuperuser;
  final String currentUser;
  final VoidCallback onBook;
  final VoidCallback onCancel;

  const _DayPartCardCompact({
    required this.dayPart,
    required this.status,
    required this.isPast,
    required this.isSuperuser,
    required this.currentUser,
    required this.onBook,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canBook = !isPast && status.isFullyAvailable;
    final canCancel = !isPast && (status.bookedByUser > 0 || (isSuperuser && status.hasAnyBookings));

    Color statusColor;
    IconData statusIcon;

    if (isPast) {
      statusColor = Colors.grey;
      statusIcon = Icons.history;
    } else if (status.isFullyAvailable) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status.isFullyBookedByUser) {
      statusColor = Colors.blue;
      statusIcon = Icons.event_available;
    } else if (status.bookedByOthers == status.totalSlots) {
      statusColor = Colors.red;
      statusIcon = Icons.event_busy;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.event_note;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Icon en titel
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha((255 * 0.15).round()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              dayPart.displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isPast ? Colors.grey : null,
              ),
            ),
            Text(
              dayPart.timeRange,
              style: TextStyle(
                fontSize: 11,
                color: isPast ? Colors.grey : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((255 * 0.15).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPast
                    ? 'Verstreken'
                    : status.isFullyAvailable
                        ? 'Vrij'
                        : status.isFullyBookedByUser
                            ? 'Jouw boeking'
                            : '${status.available}/${status.totalSlots} vrij',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Knoppen
            if (!isPast && (canBook || canCancel))
              Column(
                children: [
                  if (canBook)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onBook,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Boek', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  if (canCancel) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Annuleer', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Compacte slot tile voor kolom-layout
class _SlotTile extends StatelessWidget {
  final TimeSlot slot;
  final Reservation? reservation;
  final bool isAvailable;
  final bool isOwnReservation;
  final bool canCancel;
  final bool isPast;
  final VoidCallback onBook;
  final VoidCallback? onCancel;

  const _SlotTile({
    required this.slot,
    required this.reservation,
    required this.isAvailable,
    required this.isOwnReservation,
    required this.canCancel,
    required this.isPast,
    required this.onBook,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isPast
        ? Colors.grey
        : isAvailable
            ? Colors.green
            : isOwnReservation
                ? Colors.blue
                : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withAlpha((255 * 0.08).round()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withAlpha((255 * 0.3).round()),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isPast
            ? null
            : isAvailable
                ? onBook
                : canCancel
                    ? onCancel
                    : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              // Tijd
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.getDisplayTime().split(' - ')[0],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isPast ? Colors.grey : null,
                      ),
                    ),
                    if (!isAvailable && reservation != null)
                      Text(
                        reservation!.bookerName,
                        style: TextStyle(
                          fontSize: 9,
                          color: isOwnReservation ? Colors.blue : Colors.red,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Actie indicator
              if (!isPast)
                Icon(
                  isAvailable
                      ? Icons.add_circle_outline
                      : canCancel
                          ? Icons.cancel_outlined
                          : Icons.block,
                  size: 16,
                  color: statusColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
