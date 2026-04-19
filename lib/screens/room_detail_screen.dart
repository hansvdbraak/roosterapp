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
import '../widgets/app_header.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  final DateTime initialDate;
  final bool forceDayPartView;

  const RoomDetailScreen({
    super.key,
    required this.room,
    required this.initialDate,
    this.forceDayPartView = false,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late DateTime _selectedDate;
  late DateTime _dayPartWeekStart;

  @override
  void initState() {
    super.initState();
    final initDate = widget.initialDate;
    _selectedDate = DateTime.utc(initDate.year, initDate.month, initDate.day);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    // Snap naar maandag van de huidige week (weekday: 1=ma, 7=zo)
    _dayPartWeekStart = today.subtract(Duration(days: today.weekday - 1));
    // Preload reserveringen voor alle zichtbare dagdeel-datums
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadDayPartDates());
  }

  /// Laad reserveringen proactief voor de 14 zichtbare dagen (2 weken) in dagdeel-modus.
  void _preloadDayPartDates() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final canBookHalfHour = authProvider.currentSession?.canBookHalfHour ?? false;
    final isDayPart = !canBookHalfHour || (authProvider.isCoordinator && widget.forceDayPartView);
    if (!isDayPart || widget.room.isObsolete) return;
    final reservationProvider = context.read<ReservationProvider>();
    for (int i = 0; i < 14; i++) {
      reservationProvider.loadReservations(
        widget.room.id,
        _dayPartWeekStart.add(Duration(days: i)),
      );
    }
  }

  void _previousDay() {
    final newDate = _selectedDate.subtract(const Duration(days: 1));
    final today = DateTime.now();
    final todayDate = DateTime.utc(today.year, today.month, today.day);

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

    // Coordinator: keuze tussen zelf boeken of toewijzen aan gebruiker
    if (authProvider.isCoordinator) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Slot beheren'),
          content: Text('${widget.room.name} op ${slot.getDisplayTime()}'),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'self'),
                    child: const Text('Boek voor mezelf'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'assign'),
                    child: const Text('Wijs toe aan gebruiker'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Annuleren'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == 'assign') {
        await _assignUserToSlot(slot);
        return;
      }
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Boeking'),
        content: Text(
          'Wil je ${widget.room.name} boeken op ${slot.getDisplayTime()}?',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'once'),
                  child: const Text('Boeken'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'weekly'),
                  child: const Text('Wekelijks herhalen'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Annuleren'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    final dates = choice == 'weekly'
        ? List.generate(4, (i) => DateTime.utc(_selectedDate.year, _selectedDate.month, _selectedDate.day + 7 * i))
        : [_selectedDate];

    int success = 0;
    final errors = <String>[];
    for (final date in dates) {
      try {
        await reservationProvider.createReservation(
          roomId: widget.room.id,
          bookerName: authProvider.userName,
          date: date,
          slotIndex: slot.slotIndex,
        );
        success++;
      } catch (e) {
        errors.add(e.toString().replaceAll('Exception: ', ''));
      }
    }

    if (!mounted) return;
    if (success > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == 1
              ? 'Reservering aangemaakt!'
              : '$success reserveringen aangemaakt!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.first),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    // Coordinator die iemand anders zijn slot wist: extra opties
    String? action;
    if (authProvider.isCoordinator && reservation.bookerName != authProvider.userName) {
      action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reservering van ${reservation.bookerName}'),
          content: Text(widget.room.name),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Wissen'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'reassign'),
                    child: const Text('Andere gebruiker toewijzen'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
    } else {
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
      if (confirm != true || !mounted) return;
      action = 'cancel';
    }

    try {
      await reservationProvider.cancelReservation(
        reservationId: reservation.id,
        userName: authProvider.userName,
        isSuperuser: authProvider.isCoordinator,
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
      return;
    }

    // Na annulering: toewijzen aan andere gebruiker
    if (action == 'reassign' && mounted) {
      final slot = TimeSlot(date: _selectedDate, slotIndex: reservation.slotIndex);
      await _assignUserToSlot(slot);
    }
  }

  /// Coordinator: wijs een slot toe aan een ambassadeur
  Future<void> _assignUserToSlot(TimeSlot slot) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final simpleUsers = authProvider.allUsers
        .where((u) => u.role == UserRole.gebruikerEenvoud)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (simpleUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen ambassadeurs gevonden')),
        );
      }
      return;
    }

    final selectedUser = await showDialog<User>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wijs toe aan gebruiker'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: simpleUsers.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(simpleUsers[i].name),
              onTap: () => Navigator.pop(ctx, simpleUsers[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
        ],
      ),
    );

    if (selectedUser == null || !mounted) return;

    try {
      await reservationProvider.createReservation(
        roomId: widget.room.id,
        bookerName: selectedUser.name,
        date: _selectedDate,
        slotIndex: slot.slotIndex,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot toegewezen aan ${selectedUser.name}'),
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

  Future<void> _bookDayPart(DayPart dayPart, DateTime date) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();
    final dateLabel = DateFormat('EEEE d MMMM', 'nl').format(date);

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bevestig Boeking'),
        content: Text(
          'Wil je ${widget.room.name} boeken voor de ${dayPart.displayName.toLowerCase()} (${dayPart.timeRange}) op $dateLabel?',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'once'),
                  child: const Text('Boeken'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'weekly'),
                  child: const Text('Wekelijks herhalen'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Annuleren'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    final dates = choice == 'weekly'
        ? List.generate(4, (i) => DateTime.utc(date.year, date.month, date.day + 7 * i))
        : [date];

    int success = 0;
    final errors = <String>[];
    for (final d in dates) {
      try {
        await reservationProvider.createDayPartReservation(
          roomId: widget.room.id,
          bookerName: authProvider.userName,
          date: d,
          dayPart: dayPart,
        );
        success++;
      } catch (e) {
        errors.add(e.toString().replaceAll('Exception: ', ''));
      }
    }

    if (!mounted) return;
    if (success > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success == 1
              ? '${dayPart.displayName} geboekt!'
              : '$success × ${dayPart.displayName.toLowerCase()} geboekt!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.first),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelDayPart(DayPart dayPart, DateTime date) async {
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
          date: date,
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

  /// Coordinator: vrij dagdeel boeken voor zichzelf of toewijzen aan ambassadeur
  Future<void> _bookDayPartAsCoordinator(DayPart dayPart, DateTime date) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dagdeel beheren'),
        content: Text('${dayPart.displayName} (${dayPart.timeRange})'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'self'),
                  child: const Text('Boek voor mezelf'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'assign'),
                  child: const Text('Wijs toe aan ambassadeur'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Annuleren'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'assign') {
      await _assignUserToDayPart(dayPart, date);
      return;
    }
    // Boek voor mezelf
    await _bookDayPart(dayPart, date);
  }

  /// Coordinator: bezet dagdeel wissen of wissen + opnieuw toewijzen
  Future<void> _cancelDayPartAsCoordinator(DayPart dayPart, DateTime date, String bookerName) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reservering van $bookerName'),
        content: Text('${dayPart.displayName} (${dayPart.timeRange})'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Wissen'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'reassign'),
                  child: const Text('Andere gebruiker toewijzen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    try {
      await reservationProvider.cancelDayPartReservation(
        roomId: widget.room.id,
        date: date,
        dayPart: dayPart,
        userName: bookerName,
        isSuperuser: authProvider.isCoordinator,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dayPart.displayName} van $bookerName geannuleerd'),
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
      return;
    }

    if (action == 'reassign' && mounted) {
      await _assignUserToDayPart(dayPart, date);
    }
  }

  /// Coordinator: wijs een dagdeel toe aan een ambassadeur
  Future<void> _assignUserToDayPart(DayPart dayPart, DateTime date) async {
    final authProvider = context.read<AuthProvider>();
    final reservationProvider = context.read<ReservationProvider>();

    final ambassadeurs = authProvider.allUsers
        .where((u) => u.role == UserRole.gebruikerEenvoud)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (ambassadeurs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen ambassadeurs gevonden')),
        );
      }
      return;
    }

    final selectedUser = await showDialog<User>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wijs toe aan ambassadeur'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ambassadeurs.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(ambassadeurs[i].name),
              onTap: () => Navigator.pop(ctx, ambassadeurs[i]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
        ],
      ),
    );

    if (selectedUser == null || !mounted) return;

    try {
      await reservationProvider.createDayPartReservation(
        roomId: widget.room.id,
        bookerName: selectedUser.name,
        date: date,
        dayPart: dayPart,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dayPart.displayName} toegewezen aan ${selectedUser.name}'),
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

  bool get _allowsEveningBooking {
    final name = widget.room.name.toLowerCase();
    return name.contains('trefpunt aquarium') || name.contains('de kuil in het gemeentehuis');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.yellow[100],
            foregroundColor: Colors.deepOrange,
            shape: const CircleBorder(),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          AppHeaderActions(
            selectedDate: _selectedDate,
            showDate: true,
          ),
        ],
      ),
      body: Column(
        children: [
          // Room info & date navigation (alleen voor slot-modus en overbodig)
          if ((canBookHalfHour && !(authProvider.isCoordinator && widget.forceDayPartView)) || widget.room.isObsolete) _buildHeader(context),

          // Ruimteomschrijving voor dagdeel-modus (geen datumnavigatie nodig)
          if ((!canBookHalfHour || (authProvider.isCoordinator && widget.forceDayPartView)) && !widget.room.isObsolete && widget.room.description != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Text(
                widget.room.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

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
                : (canBookHalfHour && !(authProvider.isCoordinator && widget.forceDayPartView))
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
            mainAxisAlignment: MainAxisAlignment.center,
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
                    setState(() => _selectedDate = DateTime.utc(picked.year, picked.month, picked.day));
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

  /// Dagdeel weergave voor ambassadeurs - 2 weken naast elkaar, gelijke rijhoogtes
  Widget _buildDayPartView(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    // Coordinators mogen ook weken terugkijken
    final canGoBack = authProvider.isCoordinator || _dayPartWeekStart.isAfter(today);
    final week2Start = _dayPartWeekStart.add(const Duration(days: 7));

    // ISO 8601 weeknummer berekening
    int isoWeekNumber(DateTime date) {
      final d = DateTime.utc(date.year, date.month, date.day);
      final thu = d.add(Duration(days: 4 - d.weekday));
      final yearStart = DateTime.utc(thu.year, 1, 1);
      return (thu.difference(yearStart).inDays ~/ 7) + 1;
    }

    final headerBg = Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(180);
    final weekBg = Theme.of(context).colorScheme.primaryContainer.withAlpha(160);
    final weekFg = Theme.of(context).colorScheme.onPrimaryContainer;
    final activeDayParts = DayPart.values.where((dp) => dp != DayPart.avond || _allowsEveningBooking).toList();

    // Gedeelde koptekst voor dagdeelkolommen
    Widget dayPartHeader() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          color: headerBg,
          child: Row(
            children: [
              const SizedBox(width: 52),
              ...activeDayParts.map((dp) => Expanded(
                    child: Text(
                      dp.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  )),
            ],
          ),
        );

    return Column(
      children: [
        // Weeknavigatie
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: canGoBack
                    ? () => setState(() => _dayPartWeekStart = DateTime.utc(
                        _dayPartWeekStart.year, _dayPartWeekStart.month, _dayPartWeekStart.day - 7))
                    : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Vorige week', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.yellow[100],
                  foregroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Week ${isoWeekNumber(_dayPartWeekStart)} – ${isoWeekNumber(week2Start)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _dayPartWeekStart = DateTime.utc(
                    _dayPartWeekStart.year, _dayPartWeekStart.month, _dayPartWeekStart.day + 7)),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Volgende week', style: TextStyle(fontSize: 13)),
                iconAlignment: IconAlignment.end,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.yellow[100],
                  foregroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Colors.deepOrange, width: 2),
                ),
              ),
            ],
          ),
        ),
        // Weeknummer headers naast elkaar
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: weekBg,
                  child: Text('Week ${isoWeekNumber(_dayPartWeekStart)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: weekFg)),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: weekBg,
                  child: Text('Week ${isoWeekNumber(week2Start)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: weekFg)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Dagdeel-kopteksten naast elkaar
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: dayPartHeader()),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: dayPartHeader()),
            ],
          ),
        ),
        const Divider(height: 1),
        // Dagrijen: per dag één Row zodat beide kanten even hoog zijn
        Expanded(
          child: ListView.separated(
            itemCount: 7,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final date1 = _dayPartWeekStart.add(Duration(days: i));
              final date2 = week2Start.add(Duration(days: i));
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildDayPartRow(
                          context, date1, now, authProvider, reservationProvider),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: _buildDayPartRow(
                          context, date2, now, authProvider, reservationProvider),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayPartRow(
    BuildContext context,
    DateTime date,
    DateTime now,
    AuthProvider authProvider,
    ReservationProvider reservationProvider,
  ) {
    final dayLabel = DateFormat('EEE', 'nl').format(date);
    final dateLabel = DateFormat('d MMM', 'nl').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dag/datum kolom
          SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Dagdeel cellen met ruimte ertussen
          ...DayPart.values.where((dp) => dp != DayPart.avond || _allowsEveningBooking).map((dayPart) {
            final status = reservationProvider.getDayPartStatus(
              widget.room.id,
              date,
              dayPart,
              authProvider.userName,
            );
            final dayPartStart = DateTime(
              date.year,
              date.month,
              date.day,
              8 + (dayPart.startSlotIndex ~/ 2),
              (dayPart.startSlotIndex % 2) * 30,
            );
            final isPast = dayPartStart.isBefore(now);
            final canBook = !isPast && (status.isFullyAvailable || authProvider.isCoordinator);
            final canCancel = !isPast &&
                (status.bookedByUser > 0 ||
                    (authProvider.isCoordinator && status.hasAnyBookings));

            // Naam van boeker voor cel-label (andere boeker of eigen naam)
            final otherBookerName = status.firstOtherBookerName;

            // Coordinator bezetting: bereken onTap direct — geen conditielogica in de cel
            // isCoordinatorManage: enkel voor bezetting-bekijken (visuele weergave verleden)
            final bool isCoordinatorManage =
                authProvider.isCoordinator && widget.forceDayPartView;
            // coordinatorTap: gebruik de build-time status direct — de cel
            // toont al de juiste bezetting, dus de tap moet daarmee in sync zijn.
            VoidCallback? coordinatorTap;
            if (authProvider.isCoordinator && !isPast) {
              final capturedStatus = status;
              final capturedOtherName = otherBookerName;
              coordinatorTap = () {
                if (capturedStatus.isFullyAvailable) {
                  _bookDayPartAsCoordinator(dayPart, date);
                } else if (capturedStatus.hasAnyBookings) {
                  final bookerName = capturedOtherName ?? authProvider.userName;
                  _cancelDayPartAsCoordinator(dayPart, date, bookerName);
                }
              };
            }

            return Expanded(
              child: _DayPartCell(
                status: status,
                isPast: isPast,
                canBook: canBook,
                canCancel: canCancel,
                isCoordinatorManage: isCoordinatorManage,
                coordinatorTap: coordinatorTap,
                ownName: authProvider.userName,
                otherBookerName: otherBookerName,
                onBook: () => _bookDayPart(dayPart, date),
                onCancel: () => _cancelDayPart(dayPart, date),
              ),
            );
          }),
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
              final canCancel = isOwnReservation || authProvider.isCoordinator;
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
              if (_allowsEveningBooking) ...[
                const SizedBox(width: 8),
                buildSlotColumn(col3Slots, '19:00-22:00', Colors.purple),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Grote gekleurde cel voor de dagdeel-tabel — volledig gevuld, witte tekst
class _DayPartCell extends StatelessWidget {
  final DayPartStatus status;
  final bool isPast;
  final bool canBook;
  final bool canCancel;
  final bool isCoordinatorManage;
  final VoidCallback? coordinatorTap;
  final String? ownName;
  final String? otherBookerName;
  final VoidCallback onBook;
  final VoidCallback onCancel;

  const _DayPartCell({
    required this.status,
    required this.isPast,
    required this.canBook,
    required this.canCancel,
    required this.onBook,
    required this.onCancel,
    this.isCoordinatorManage = false,
    this.coordinatorTap,
    this.ownName,
    this.otherBookerName,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String label;

    // Coordinator bezetting terugkijken: verleden cellen tonen naam/Vrij in zwart op grijs
    final showPastInfo = isCoordinatorManage && isPast;

    if (isPast && !showPastInfo) {
      bgColor = const Color(0xFFDDDDDD);
      label = '';
    } else if (status.isFullyAvailable) {
      bgColor = showPastInfo ? const Color(0xFFDDDDDD) : const Color(0xFFFF2800);
      label = 'Vrij';
    } else if (status.bookedByOthers > 0) {
      bgColor = showPastInfo ? const Color(0xFFDDDDDD) : const Color(0xFF4CBB17);
      label = otherBookerName ?? 'Bezet';
    } else if (status.bookedByUser > 0) {
      bgColor = showPastInfo ? const Color(0xFFDDDDDD) : const Color(0xFF1565C0);
      label = ownName ?? 'Jij';
    } else {
      bgColor = const Color(0xFFDDDDDD);
      label = '';
    }

    // Verleden cellen zijn nooit aanklikbaar (ook niet voor coordinators)
    final tappable = !isPast && (isCoordinatorManage
        ? (status.hasAnyBookings || status.isFullyAvailable)
        : (canBook || canCancel));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: coordinatorTap ??
              (!tappable
                  ? null
                  : status.isFullyAvailable
                      ? onBook
                      : canCancel
                          ? onCancel
                          : null),
          borderRadius: BorderRadius.circular(8),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Center(
              child: label.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        color: showPastInfo ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
            ),
          ),
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
