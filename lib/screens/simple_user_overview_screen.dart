import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/reservation_provider.dart';
import '../models/user.dart';
import '../models/reservation.dart';
import '../widgets/app_header.dart';

class SimpleUserOverviewScreen extends StatefulWidget {
  const SimpleUserOverviewScreen({super.key});

  @override
  State<SimpleUserOverviewScreen> createState() => _SimpleUserOverviewScreenState();
}

class _SimpleUserOverviewScreenState extends State<SimpleUserOverviewScreen> {
  // Bijhouden welke gebruikers bekeken zijn dit kwartaal
  Set<int> _viewedUserIds = {};
  int _trackedQuarter = 0;
  int _trackedYear = 0;

  User? _selectedUser;
  List<Reservation>? _userReservations;
  bool _isLoadingReservations = false;
  bool _isInitialized = false;

  static const String _prefsKeyPrefix = 'simple_user_viewed_';

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    final now = DateTime.now();
    _trackedQuarter = ((now.month - 1) ~/ 3) + 1;
    _trackedYear = now.year;

    await _loadViewedUsers();
    setState(() => _isInitialized = true);
  }

  String get _currentPrefsKey => '$_prefsKeyPrefix${_trackedYear}_Q$_trackedQuarter';

  Future<void> _loadViewedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedList = prefs.getStringList(_currentPrefsKey) ?? [];
    _viewedUserIds = viewedList.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toSet();
  }

  Future<void> _saveViewedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _currentPrefsKey,
      _viewedUserIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _checkQuarterChange() async {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final currentYear = now.year;

    if (currentQuarter != _trackedQuarter || currentYear != _trackedYear) {
      _trackedQuarter = currentQuarter;
      _trackedYear = currentYear;
      await _loadViewedUsers();
      setState(() {});
    }
  }

  Future<void> _selectUser(User user) async {
    // Lees provider voordat we async gaan
    final reservationProvider = context.read<ReservationProvider>();

    await _checkQuarterChange();

    setState(() {
      _selectedUser = user;
      _isLoadingReservations = true;
      _userReservations = null;
    });

    // Markeer als bekeken en sla op
    _viewedUserIds.add(user.id);
    await _saveViewedUsers();

    // Laad reservaties van server
    try {
      final reservations = await reservationProvider.getReservationsByUser(user.name);

      if (mounted) {
        setState(() {
          _userReservations = reservations;
          _isLoadingReservations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userReservations = [];
          _isLoadingReservations = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij laden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _goBack() {
    setState(() {
      _selectedUser = null;
      _userReservations = null;
    });
  }

  String _getQuarterName(int quarter) {
    switch (quarter) {
      case 1:
        return 'Q1 (jan-mrt)';
      case 2:
        return 'Q2 (apr-jun)';
      case 3:
        return 'Q3 (jul-sep)';
      case 4:
        return 'Q4 (okt-dec)';
      default:
        return 'Q$quarter';
    }
  }

  DateTime _getQuarterStart(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    return DateTime(year, startMonth, 1);
  }

  DateTime _getQuarterEnd(int year, int quarter) {
    final startMonth = (quarter - 1) * 3 + 1;
    return DateTime(year, startMonth + 3, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eenvoudige gebruikers')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedUser == null
            ? 'Eenvoudige gebruikers'
            : _selectedUser!.name),
        leading: _selectedUser != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: const [
          AppHeaderActions(showDate: true),
        ],
      ),
      body: _selectedUser == null
          ? _buildUserList()
          : _buildUserQuarterOverview(_selectedUser!),
    );
  }

  Widget _buildUserList() {
    final authProvider = context.watch<AuthProvider>();

    // Filter alleen eenvoudige gebruikers
    final simpleUsers = authProvider.allUsers
        .where((u) => u.role == UserRole.gebruikerEenvoud)
        .toList();

    // Sorteer: niet-bekeken eerst (alfabetisch), dan bekeken (alfabetisch)
    simpleUsers.sort((a, b) {
      final aViewed = _viewedUserIds.contains(a.id);
      final bViewed = _viewedUserIds.contains(b.id);
      if (!aViewed && bViewed) return -1;
      if (aViewed && !bViewed) return 1;
      return a.name.compareTo(b.name);
    });

    final viewedCount = simpleUsers.where((u) => _viewedUserIds.contains(u.id)).length;
    final totalCount = simpleUsers.length;

    if (simpleUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Geen eenvoudige gebruikers',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header met voortgang
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_getQuarterName(_trackedQuarter)} $_trackedYear',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: viewedCount == totalCount ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$viewedCount / $totalCount bekeken',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Voortgangsbalk
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? viewedCount / totalCount : 0,
                  backgroundColor: Colors.blue[100],
                  valueColor: AlwaysStoppedAnimation(
                    viewedCount == totalCount ? Colors.green : Colors.blue,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tik op een gebruiker om het kwartaaloverzicht te bekijken.',
                style: TextStyle(color: Colors.blue[600], fontSize: 12),
              ),
            ],
          ),
        ),

        // Gebruikerslijst
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: simpleUsers.length,
            itemBuilder: (context, index) {
              final user = simpleUsers[index];
              final isViewed = _viewedUserIds.contains(user.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isViewed ? Colors.green[50] : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isViewed ? Colors.green[700] : Colors.teal[100],
                    child: isViewed
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Colors.teal[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  title: Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isViewed ? Colors.green[800] : null,
                    ),
                  ),
                  subtitle: user.comment != null && user.comment!.isNotEmpty
                      ? Text(
                          user.comment!,
                          style: TextStyle(
                            color: isViewed ? Colors.green[600] : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isViewed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Bekeken',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _selectUser(user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserQuarterOverview(User user) {
    if (_isLoadingReservations) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Reserveringen laden...'),
          ],
        ),
      );
    }

    final quarterStart = _getQuarterStart(_trackedYear, _trackedQuarter);
    final quarterEnd = _getQuarterEnd(_trackedYear, _trackedQuarter);

    // Filter reservaties op huidig kwartaal
    final quarterReservations = (_userReservations ?? []).where((r) {
      return r.date.isAfter(quarterStart.subtract(const Duration(days: 1))) &&
             r.date.isBefore(quarterEnd.add(const Duration(days: 1)));
    }).toList();

    // Bereken uren per tijdsblok
    int slotsCol1 = 0; // 8:00-13:00 (slots 0-9)
    int slotsCol2 = 0; // 13:00-17:00 (slots 10-17)
    int slotsCol3 = 0; // 19:00-22:00 (slots 22-27)

    for (final res in quarterReservations) {
      final slotIndex = res.slotIndex;
      if (slotIndex >= 0 && slotIndex <= 9) {
        slotsCol1++;
      } else if (slotIndex >= 10 && slotIndex <= 17) {
        slotsCol2++;
      } else if (slotIndex >= 22 && slotIndex <= 27) {
        slotsCol3++;
      }
    }

    final hoursCol1 = slotsCol1 * 0.5;
    final hoursCol2 = slotsCol2 * 0.5;
    final hoursCol3 = slotsCol3 * 0.5;
    final totalHours = hoursCol1 + hoursCol2 + hoursCol3;

    // Bereken unieke dagen
    final uniqueDays = quarterReservations.map((r) =>
      DateTime(r.date.year, r.date.month, r.date.day)
    ).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gebruiker info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.teal[100],
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.teal[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (user.comment != null && user.comment!.isNotEmpty)
                          Text(
                            user.comment!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                user.phoneNumber!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Kwartaal info
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_getQuarterName(_trackedQuarter)} $_trackedYear',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('d MMMM', 'nl').format(quarterStart)} - ${DateFormat('d MMMM yyyy', 'nl').format(quarterEnd)}',
                    style: TextStyle(color: Colors.blue[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatChip(Icons.event, '$uniqueDays dagen', Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatChip(Icons.schedule, '${quarterReservations.length} boekingen', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Uren overzicht titel
          Text(
            'Uren per tijdsblok',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // 3 kolommen met uren
          Row(
            children: [
              _buildHoursColumn('Ochtend', '8:00-13:00', hoursCol1, Colors.orange),
              const SizedBox(width: 8),
              _buildHoursColumn('Middag', '13:00-17:00', hoursCol2, Colors.blue),
              const SizedBox(width: 8),
              _buildHoursColumn('Avond', '19:00-22:00', hoursCol3, Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // Totaal
          Card(
            color: Colors.teal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Totaal dit kwartaal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Alle tijdsblokken',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${totalHours.toStringAsFixed(1)} uur',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (totalHours == 0) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Geen boekingen dit kwartaal',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],

          // Recente boekingen
          if (quarterReservations.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Boekingen dit kwartaal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildReservationsList(quarterReservations),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.15).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursColumn(String title, String timeRange, double hours, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                timeRange,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hours.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'uur',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationsList(List<Reservation> reservations) {
    // Groepeer per datum, sorteer nieuwste eerst
    final grouped = <DateTime, List<Reservation>>{};
    for (final res in reservations) {
      final dateKey = DateTime(res.date.year, res.date.month, res.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(res);
    }

    final sortedDates = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Toon max 10 dagen
    final displayDates = sortedDates.take(10).toList();

    return Column(
      children: [
        for (final date in displayDates)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.teal[800],
                          ),
                        ),
                        Text(
                          DateFormat('MMM', 'nl').format(date),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.teal[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE', 'nl').format(date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${grouped[date]!.length} slot${grouped[date]!.length == 1 ? '' : 's'} '
                          '(${(grouped[date]!.length * 0.5).toStringAsFixed(1)} uur)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (sortedDates.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'En ${sortedDates.length - 10} andere dagen...',
              style: TextStyle(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
