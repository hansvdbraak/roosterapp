import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/room_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../widgets/app_header.dart';

enum DashboardView { choice, weekList, quarterList, weekDetail, quarterDetail, weekSchedule }

class CoordinatorDashboardScreen extends StatefulWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  State<CoordinatorDashboardScreen> createState() => _CoordinatorDashboardScreenState();
}

class _CoordinatorDashboardScreenState extends State<CoordinatorDashboardScreen> {
  DashboardView _currentView = DashboardView.choice;
  int _selectedYear = DateTime.now().year;
  DateTime? _selectedWeekStart;
  int? _selectedQuarter;
  late DateTime _scheduleWeekStart;

  Set<String> _verwerktWeeks = {};
  Set<String> _verwerktQuarters = {};
  Set<String> _verwerktUsers = {};
  static const String _verwerktWeeksKey = 'coordinator_verwerkt_weeks';
  static const String _verwerktQuartersKey = 'coordinator_verwerkt_quarters';
  static const String _verwerktUsersKey = 'coordinator_verwerkt_users';

  @override
  void initState() {
    super.initState();
    // In Q1 (jan-mrt): toon vorig jaar zodat Q4 van vorig jaar zichtbaar is
    if (DateTime.now().month <= 3) {
      _selectedYear = DateTime.now().year - 1;
    }
    // Start week schedule at Monday of current week
    final nowInit = DateTime.now();
    final todayInit = DateTime.utc(nowInit.year, nowInit.month, nowInit.day);
    _scheduleWeekStart = todayInit.subtract(Duration(days: todayInit.weekday - 1));
    _loadVerwerktState();
  }

  Future<void> _loadVerwerktState() async {
    final prefs = await SharedPreferences.getInstance();
    final weeks = prefs.getStringList(_verwerktWeeksKey) ?? [];
    final quarters = prefs.getStringList(_verwerktQuartersKey) ?? [];
    final userKeys = prefs.getStringList(_verwerktUsersKey) ?? [];
    if (mounted) {
      setState(() {
        _verwerktWeeks = weeks.toSet();
        _verwerktQuarters = quarters.toSet();
        _verwerktUsers = userKeys.toSet();
      });
    }
  }

  String _weekKey(DateTime weekStart) =>
      '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

  String _quarterKey(int year, int quarter) => '$year-Q$quarter';

  Future<void> _toggleVerwerktWeek(DateTime weekStart) async {
    final key = _weekKey(weekStart);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_verwerktWeeks.contains(key)) {
        _verwerktWeeks.remove(key);
      } else {
        _verwerktWeeks.add(key);
      }
    });
    await prefs.setStringList(_verwerktWeeksKey, _verwerktWeeks.toList());
  }

  Future<void> _toggleVerwerktQuarter(int year, int quarter) async {
    final key = _quarterKey(year, quarter);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_verwerktQuarters.contains(key)) {
        _verwerktQuarters.remove(key);
      } else {
        _verwerktQuarters.add(key);
      }
    });
    await prefs.setStringList(_verwerktQuartersKey, _verwerktQuarters.toList());
  }

  Future<void> _toggleVerwerktUser(String periodKey, String userName) async {
    final key = '${periodKey}_$userName';
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_verwerktUsers.contains(key)) {
        _verwerktUsers.remove(key);
      } else {
        _verwerktUsers.add(key);
      }
    });
    await prefs.setStringList(_verwerktUsersKey, _verwerktUsers.toList());
  }

  void _selectWeekly() {
    setState(() {
      _currentView = DashboardView.weekList;
    });
  }

  void _selectQuarterly() {
    setState(() {
      _currentView = DashboardView.quarterList;
    });
  }

  void _selectWeek(DateTime weekStart) {
    setState(() {
      _selectedWeekStart = weekStart;
      _currentView = DashboardView.weekDetail;
    });
  }

  void _selectQuarter(int quarter) {
    setState(() {
      _selectedQuarter = quarter;
      _currentView = DashboardView.quarterDetail;
    });
  }

  void _goBack() {
    setState(() {
      if (_currentView == DashboardView.quarterDetail) {
        _currentView = DashboardView.quarterList;
        _selectedQuarter = null;
      } else if (_currentView == DashboardView.quarterList ||
                 _currentView == DashboardView.weekSchedule) {
        _currentView = DashboardView.choice;
      }
    });
  }

  void _goToPreviousQuarter() {
    setState(() {
      if (_selectedQuarter == 1) {
        _selectedYear--;
        _selectedQuarter = 4;
      } else {
        _selectedQuarter = _selectedQuarter! - 1;
      }
    });
  }

  void _goToNextQuarter() {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final isLastAllowed = _selectedYear == now.year && _selectedQuarter == currentQuarter;
    if (isLastAllowed) return;
    setState(() {
      if (_selectedQuarter == 4) {
        _selectedYear++;
        _selectedQuarter = 1;
      } else {
        _selectedQuarter = _selectedQuarter! + 1;
      }
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

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  List<DateTime> _getAllWeeksOfYear(int year) {
    // Start met eerste maandag van het jaar
    var date = DateTime(year, 1, 1);
    while (date.weekday != DateTime.monday) {
      date = date.add(const Duration(days: 1));
    }

    final weeks = <DateTime>[];
    while (date.year == year || (date.year == year + 1 && date.month == 1 && date.day <= 7)) {
      weeks.add(date);
      date = date.add(const Duration(days: 7));
      if (weeks.length >= 53) break; // Max 53 weken
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading: (_currentView == DashboardView.quarterDetail ||
                  _currentView == DashboardView.quarterList ||
                  _currentView == DashboardView.weekSchedule)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.yellow[100],
                  foregroundColor: Colors.deepOrange,
                  shape: const CircleBorder(),
                ),
                onPressed: _goBack,
              )
            : null,
        actions: [
          if (_currentView == DashboardView.quarterList)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedYear--),
                ),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedYear < DateTime.now().year
                      ? () => setState(() => _selectedYear++)
                      : null,
                ),
              ],
            ),
          if (_currentView == DashboardView.quarterDetail)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousQuarter,
                  tooltip: 'Vorig kwartaal',
                ),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final now = DateTime.now();
                    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
                    final isLast = _selectedYear == now.year && _selectedQuarter == currentQuarter;
                    if (!isLast) _goToNextQuarter();
                  },
                  tooltip: 'Volgend kwartaal',
                ),
              ],
            ),
          const AppHeaderActions(showDate: true),
        ],
      ),
      body: _buildContent(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentView) {
      case DashboardView.choice:
        return 'Overzichten';
      case DashboardView.weekList:
        return 'Wekelijks overzicht';
      case DashboardView.quarterList:
        return 'Kwartaaloverzicht';
      case DashboardView.weekSchedule:
        return 'Weekrooster';
      case DashboardView.weekDetail:
        final weekNumber = _getWeekNumber(_selectedWeekStart!);
        return 'Week $weekNumber';
      case DashboardView.quarterDetail:
        return _getQuarterName(_selectedQuarter!);
    }
  }

  Widget _buildContent() {
    switch (_currentView) {
      case DashboardView.choice:
        return _buildChoiceView();
      case DashboardView.weekList:
        return _buildWeekListView();
      case DashboardView.quarterList:
        return _buildQuarterListView();
      case DashboardView.weekSchedule:
        return _buildWeekScheduleView();
      case DashboardView.weekDetail:
        return _buildWeekDetailView();
      case DashboardView.quarterDetail:
        return _buildQuarterDetailView();
    }
  }

  Widget _buildChoiceView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Kies een overzicht',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bekijk de uren per ambassadeur',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.view_week,
                  title: 'Weekrooster',
                  subtitle: 'Ruimtebezetting per dagdeel',
                  onTap: () => setState(() => _currentView = DashboardView.weekSchedule),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.calendar_view_month,
                  title: 'Per kwartaal',
                  subtitle: '13 weken overzicht',
                  onTap: _selectQuarterly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekListView() {
    final weeks = _getAllWeeksOfYear(_selectedYear);
    final now = DateTime.now();

    // Vind huidige en volgende week
    DateTime? currentWeekStart;
    DateTime? nextWeekStart;
    for (int i = 0; i < weeks.length; i++) {
      final weekStart = weeks[i];
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrentWeek = now.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          now.isBefore(weekEnd.add(const Duration(days: 1)));
      if (isCurrentWeek) {
        currentWeekStart = weekStart;
        if (i + 1 < weeks.length) {
          nextWeekStart = weeks[i + 1];
        }
        break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prominente weergave: Lopende en komende week
          if (currentWeekStart != null && _selectedYear == now.year) ...[
            Text(
              'Snelle toegang',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WeekCardProminent(
                    weekStart: currentWeekStart,
                    weekNumber: _getWeekNumber(currentWeekStart),
                    label: 'Lopende week',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _selectWeek(currentWeekStart!),
                  ),
                ),
                if (nextWeekStart != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WeekCardProminent(
                      weekStart: nextWeekStart,
                      weekNumber: _getWeekNumber(nextWeekStart),
                      label: 'Volgende week',
                      color: Colors.blue,
                      onTap: () => _selectWeek(nextWeekStart!),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Alle weken in kolommen (4 kolommen)
          Text(
            'Alle weken van $_selectedYear',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildWeekGrid(weeks, now, currentWeekStart),
        ],
      ),
    );
  }

  Widget _buildWeekGrid(List<DateTime> weeks, DateTime now, DateTime? currentWeekStart) {
    // Verdeel weken in 4 kolommen
    const columns = 4;
    final rowCount = (weeks.length / columns).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(columns, (colIndex) {
              final weekIndex = rowIndex * columns + colIndex;
              if (weekIndex >= weeks.length) {
                return const Expanded(child: SizedBox());
              }

              final weekStart = weeks[weekIndex];
              final weekEnd = weekStart.add(const Duration(days: 6));
              final weekNumber = _getWeekNumber(weekStart);
              final isCurrentWeek = currentWeekStart != null &&
                  weekStart.year == currentWeekStart.year &&
                  weekStart.month == currentWeekStart.month &&
                  weekStart.day == currentWeekStart.day;
              final isFuture = weekStart.isAfter(now);
              final isNextWeek = currentWeekStart != null &&
                  weekStart.difference(currentWeekStart).inDays == 7;

              final isVerwerkt = _verwerktWeeks.contains(_weekKey(weekStart));

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIndex < columns - 1 ? 4 : 0),
                  child: _WeekCardCompact(
                    weekNumber: weekNumber,
                    weekStart: weekStart,
                    weekEnd: weekEnd,
                    isCurrentWeek: isCurrentWeek,
                    isNextWeek: isNextWeek,
                    isFuture: isFuture,
                    isVerwerkt: isVerwerkt,
                    onTap: isFuture ? null : () => _selectWeek(weekStart),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildQuarterListView() {
    final now = DateTime.now();
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final isCurrentYear = _selectedYear == now.year;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (index) {
        final quarter = index + 1;
        final isFuture = isCurrentYear && quarter > currentQuarter;
        final isCurrent = isCurrentYear && quarter == currentQuarter;

        final startMonth = (quarter - 1) * 3 + 1;
        final endMonth = startMonth + 2;
        final monthNames = ['Jan', 'Feb', 'Mrt', 'Apr', 'Mei', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : isFuture
                  ? Colors.grey[100]
                  : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300],
              child: Text(
                'Q$quarter',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Row(
              children: [
                Text(
                  _getQuarterName(quarter),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFuture ? Colors.grey : null,
                  ),
                ),
                if (isCurrent)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Huidig',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${monthNames[startMonth - 1]} - ${monthNames[endMonth - 1]} $_selectedYear',
              style: TextStyle(color: isFuture ? Colors.grey : null),
            ),
            trailing: isFuture
                ? Text(
                    'Nog geen data',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_verwerktQuarters.contains(_quarterKey(_selectedYear, quarter)))
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[700],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Verwerkt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
            onTap: isFuture ? null : () => _selectQuarter(quarter),
          ),
        );
      }),
    );
  }

  Widget _buildWeekDetailView() {
    final reservationProvider = context.watch<ReservationProvider>();
    final roomProvider = context.watch<RoomProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (_selectedWeekStart == null) {
      return const Center(child: Text('Geen week geselecteerd'));
    }

    final weekStart = _selectedWeekStart!;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekNumber = _getWeekNumber(weekStart);

    // Verzamel uren per ambassadeur
    final eenvoudigUsers = _getEenvoudigUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      weekStart,
      7,
    );

    final coordinatorUsers = _getCoordinatorUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      weekStart,
      7,
    );

    final isVerwerkt = _verwerktWeeks.contains(_weekKey(weekStart));

    return _buildUserHoursList(
      title: 'Week $weekNumber',
      subtitle: '${DateFormat('d MMMM', 'nl').format(weekStart)} - ${DateFormat('d MMMM yyyy', 'nl').format(weekEnd)}',
      periodKey: _weekKey(weekStart),
      users: eenvoudigUsers,
      coordinatorUsers: coordinatorUsers,
      isVerwerkt: isVerwerkt,
      onToggleVerwerkt: () => _toggleVerwerktWeek(weekStart),
    );
  }

  Widget _buildQuarterDetailView() {
    final reservationProvider = context.watch<ReservationProvider>();
    final roomProvider = context.watch<RoomProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (_selectedQuarter == null) {
      return const Center(child: Text('Geen kwartaal geselecteerd'));
    }

    // Bereken start en eind van het kwartaal
    final startMonth = (_selectedQuarter! - 1) * 3 + 1;
    final quarterStart = DateTime(_selectedYear, startMonth, 1);
    final quarterEnd = DateTime(_selectedYear, startMonth + 3, 0);
    final daysInQuarter = quarterEnd.difference(quarterStart).inDays + 1;

    // Verzamel uren per ambassadeur
    final eenvoudigUsers = _getEenvoudigUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      quarterStart,
      daysInQuarter,
    );

    final gebruikerUsers = _getGebruikerUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      quarterStart,
      daysInQuarter,
    );

    final coordinatorUsers = _getCoordinatorUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      quarterStart,
      daysInQuarter,
    );

    final isVerwerkt = _verwerktQuarters.contains(_quarterKey(_selectedYear, _selectedQuarter!));

    return _buildUserHoursList(
      title: _getQuarterName(_selectedQuarter!),
      subtitle: '${DateFormat('d MMMM', 'nl').format(quarterStart)} - ${DateFormat('d MMMM yyyy', 'nl').format(quarterEnd)}',
      periodKey: _quarterKey(_selectedYear, _selectedQuarter!),
      users: eenvoudigUsers,
      gebruikerUsers: gebruikerUsers,
      coordinatorUsers: coordinatorUsers,
      isVerwerkt: isVerwerkt,
      onToggleVerwerkt: () => _toggleVerwerktQuarter(_selectedYear, _selectedQuarter!),
    );
  }

  List<_UserHours> _getEenvoudigUsersWithHours(
    ReservationProvider reservationProvider,
    RoomProvider roomProvider,
    AuthProvider authProvider,
    DateTime startDate,
    int days,
  ) {
    // Slots per kolom per gebruiker
    // Col1: tot 13:00 (slots 0-9)
    // Col2: 13:00-17:00 (slots 10-17)
    // Col3: 19:00-22:00 (slots 22-27)
    final Map<String, int> slotsCol1ByUser = {};
    final Map<String, int> slotsCol2ByUser = {};
    final Map<String, int> slotsCol3ByUser = {};
    final rooms = roomProvider.rooms.where((r) => r.isBookable).toList();

    // Verzamel alle reserveringen
    for (int day = 0; day < days; day++) {
      final date = startDate.add(Duration(days: day));
      // Alleen werkdagen
      if (date.weekday <= 5) {
        for (final room in rooms) {
          final reservations = reservationProvider.getReservationsForRoom(room.id, date);
          for (final res in reservations) {
            final name = res.bookerName;
            final slotIndex = res.slotIndex;

            // Bepaal in welke kolom deze slot valt
            if (slotIndex >= 0 && slotIndex <= 9) {
              // Tot 13:00 (08:00 - 12:30)
              slotsCol1ByUser[name] = (slotsCol1ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 10 && slotIndex <= 17) {
              // 13:00 - 17:00 (13:00 - 16:30)
              slotsCol2ByUser[name] = (slotsCol2ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 22 && slotIndex <= 27) {
              // 19:00 - 22:00 (19:00 - 21:30)
              slotsCol3ByUser[name] = (slotsCol3ByUser[name] ?? 0) + 1;
            }
          }
        }
      }
    }

    // Verzamel alle unieke namen
    final allNames = <String>{
      ...slotsCol1ByUser.keys,
      ...slotsCol2ByUser.keys,
      ...slotsCol3ByUser.keys,
    };

    // Filter alleen ambassadeurs
    final eenvoudigUsers = <_UserHours>[];
    for (final name in allNames) {
      final user = authProvider.getUserByName(name);
      // Alleen ambassadeurs tonen
      if (user != null && user.role == UserRole.gebruikerEenvoud) {
        eenvoudigUsers.add(_UserHours(
          name: name,
          slotsCol1: slotsCol1ByUser[name] ?? 0,
          slotsCol2: slotsCol2ByUser[name] ?? 0,
          slotsCol3: slotsCol3ByUser[name] ?? 0,
          comment: user.comment,
        ));
      }
    }

    // Sorteer op totaal uren (meeste eerst)
    eenvoudigUsers.sort((a, b) => b.totalSlots.compareTo(a.totalSlots));

    return eenvoudigUsers;
  }

  List<_UserHours> _getGebruikerUsersWithHours(
    ReservationProvider reservationProvider,
    RoomProvider roomProvider,
    AuthProvider authProvider,
    DateTime startDate,
    int days,
  ) {
    final Map<String, int> slotsCol1ByUser = {};
    final Map<String, int> slotsCol2ByUser = {};
    final Map<String, int> slotsCol3ByUser = {};
    final rooms = roomProvider.rooms.where((r) => r.isBookable).toList();

    for (int day = 0; day < days; day++) {
      final date = startDate.add(Duration(days: day));
      if (date.weekday <= 5) {
        for (final room in rooms) {
          final reservations = reservationProvider.getReservationsForRoom(room.id, date);
          for (final res in reservations) {
            final name = res.bookerName;
            final slotIndex = res.slotIndex;
            if (slotIndex >= 0 && slotIndex <= 9) {
              slotsCol1ByUser[name] = (slotsCol1ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 10 && slotIndex <= 17) {
              slotsCol2ByUser[name] = (slotsCol2ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 22 && slotIndex <= 27) {
              slotsCol3ByUser[name] = (slotsCol3ByUser[name] ?? 0) + 1;
            }
          }
        }
      }
    }

    final allNames = <String>{
      ...slotsCol1ByUser.keys,
      ...slotsCol2ByUser.keys,
      ...slotsCol3ByUser.keys,
    };

    final gebruikerUsers = <_UserHours>[];
    for (final name in allNames) {
      final user = authProvider.getUserByName(name);
      if (user != null && user.role == UserRole.gebruiker) {
        gebruikerUsers.add(_UserHours(
          name: name,
          slotsCol1: slotsCol1ByUser[name] ?? 0,
          slotsCol2: slotsCol2ByUser[name] ?? 0,
          slotsCol3: slotsCol3ByUser[name] ?? 0,
          comment: user.comment,
        ));
      }
    }

    gebruikerUsers.sort((a, b) => b.totalSlots.compareTo(a.totalSlots));
    return gebruikerUsers;
  }

  List<_UserHours> _getCoordinatorUsersWithHours(
    ReservationProvider reservationProvider,
    RoomProvider roomProvider,
    AuthProvider authProvider,
    DateTime startDate,
    int days,
  ) {
    final Map<String, int> slotsCol1ByUser = {};
    final Map<String, int> slotsCol2ByUser = {};
    final Map<String, int> slotsCol3ByUser = {};
    final rooms = roomProvider.rooms.where((r) => r.isBookable).toList();

    for (int day = 0; day < days; day++) {
      final date = startDate.add(Duration(days: day));
      if (date.weekday <= 5) {
        for (final room in rooms) {
          final reservations = reservationProvider.getReservationsForRoom(room.id, date);
          for (final res in reservations) {
            final name = res.bookerName;
            final slotIndex = res.slotIndex;
            if (slotIndex >= 0 && slotIndex <= 9) {
              slotsCol1ByUser[name] = (slotsCol1ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 10 && slotIndex <= 17) {
              slotsCol2ByUser[name] = (slotsCol2ByUser[name] ?? 0) + 1;
            } else if (slotIndex >= 22 && slotIndex <= 27) {
              slotsCol3ByUser[name] = (slotsCol3ByUser[name] ?? 0) + 1;
            }
          }
        }
      }
    }

    final allNames = <String>{
      ...slotsCol1ByUser.keys,
      ...slotsCol2ByUser.keys,
      ...slotsCol3ByUser.keys,
    };

    final coordinatorUsers = <_UserHours>[];
    for (final name in allNames) {
      final user = authProvider.getUserByName(name);
      if (user != null &&
          (user.role == UserRole.coordinator || user.role == UserRole.superuser)) {
        coordinatorUsers.add(_UserHours(
          name: name,
          slotsCol1: slotsCol1ByUser[name] ?? 0,
          slotsCol2: slotsCol2ByUser[name] ?? 0,
          slotsCol3: slotsCol3ByUser[name] ?? 0,
          comment: user.comment,
        ));
      }
    }

    coordinatorUsers.sort((a, b) => b.totalSlots.compareTo(a.totalSlots));
    return coordinatorUsers;
  }

  Widget _buildUserHoursList({
    required String title,
    required String subtitle,
    required String periodKey,
    required List<_UserHours> users,
    List<_UserHours> gebruikerUsers = const [],
    List<_UserHours> coordinatorUsers = const [],
    bool isVerwerkt = false,
    VoidCallback? onToggleVerwerkt,
  }) {
    final totalCol1 = users.fold<int>(0, (sum, u) => sum + u.slotsCol1) * 0.5;
    final totalCol2 = users.fold<int>(0, (sum, u) => sum + u.slotsCol2) * 0.5;
    final totalCol3 = users.fold<int>(0, (sum, u) => sum + u.slotsCol3) * 0.5;
    final totalHours = totalCol1 + totalCol2 + totalCol3;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Alleen ambassadeurs (dagdeel-boekingen)',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Kolom headers
        if (users.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Gebruiker',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                _buildColumnHeader('Tot 13u', Colors.orange),
                _buildColumnHeader('13-17u', Colors.blue),
                _buildColumnHeader('19-22u', Colors.purple),
                _buildColumnHeader('Totaal', Colors.teal),
              ],
            ),
          ),
        const SizedBox(height: 8),

        if (users.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Geen ambassadeurs hebben geboekt',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...users.map((user) => _UserHoursCard(
                user: user,
                isVerwerkt: _verwerktUsers.contains('${periodKey}_${user.name}'),
                onToggle: () => _toggleVerwerktUser(periodKey, user.name),
              )),

        const SizedBox(height: 16),

        // Totalen
        if (users.isNotEmpty)
          Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Totaal',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        '${users.length} ambassadeurs',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      _buildTotalBadge(totalCol1, Colors.orange),
                      _buildTotalBadge(totalCol2, Colors.blue),
                      _buildTotalBadge(totalCol3, Colors.purple),
                      _buildTotalBadge(totalHours, Colors.teal, isTotal: true),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Gebruikers sectie
        if (gebruikerUsers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withAlpha((255 * 0.3).round())),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gebruikers',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${gebruikerUsers.length} gebruiker${gebruikerUsers.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.blue[600], fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Gebruiker',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                _buildColumnHeader('Tot 13u', Colors.orange),
                _buildColumnHeader('13-17u', Colors.blue),
                _buildColumnHeader('19-22u', Colors.purple),
                _buildColumnHeader('Totaal', Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...gebruikerUsers.map((user) => _UserHoursCard(
                user: user,
                isVerwerkt: _verwerktUsers.contains('${periodKey}_${user.name}'),
                onToggle: () => _toggleVerwerktUser(periodKey, user.name),
              )),
          const SizedBox(height: 8),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtotaal gebruikers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      _buildTotalBadge(
                        gebruikerUsers.fold<int>(0, (s, u) => s + u.slotsCol1) * 0.5,
                        Colors.orange,
                      ),
                      _buildTotalBadge(
                        gebruikerUsers.fold<int>(0, (s, u) => s + u.slotsCol2) * 0.5,
                        Colors.blue,
                      ),
                      _buildTotalBadge(
                        gebruikerUsers.fold<int>(0, (s, u) => s + u.slotsCol3) * 0.5,
                        Colors.purple,
                      ),
                      _buildTotalBadge(
                        gebruikerUsers.fold<int>(0, (s, u) => s + u.totalSlots) * 0.5,
                        Colors.teal,
                        isTotal: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        // Coördinatoren sectie
        if (coordinatorUsers.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withAlpha((255 * 0.3).round())),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coördinatoren (alle ruimten)',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${coordinatorUsers.length} coördinator${coordinatorUsers.length == 1 ? '' : 'en'}',
                  style: TextStyle(color: Colors.orange[600], fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Coördinator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                _buildColumnHeader('Tot 13u', Colors.orange),
                _buildColumnHeader('13-17u', Colors.blue),
                _buildColumnHeader('19-22u', Colors.purple),
                _buildColumnHeader('Totaal', Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...coordinatorUsers.map((user) => _UserHoursCard(
                user: user,
                isVerwerkt: _verwerktUsers.contains('${periodKey}_${user.name}'),
                onToggle: () => _toggleVerwerktUser(periodKey, user.name),
              )),
          const SizedBox(height: 8),
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Subtotaal coördinatoren',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(flex: 3, child: SizedBox()),
                      _buildTotalBadge(
                        coordinatorUsers.fold<int>(0, (s, u) => s + u.slotsCol1) * 0.5,
                        Colors.orange,
                      ),
                      _buildTotalBadge(
                        coordinatorUsers.fold<int>(0, (s, u) => s + u.slotsCol2) * 0.5,
                        Colors.blue,
                      ),
                      _buildTotalBadge(
                        coordinatorUsers.fold<int>(0, (s, u) => s + u.slotsCol3) * 0.5,
                        Colors.purple,
                      ),
                      _buildTotalBadge(
                        coordinatorUsers.fold<int>(0, (s, u) => s + u.totalSlots) * 0.5,
                        Colors.teal,
                        isTotal: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

      ],
    );
  }

  // ── Week schedule helpers ──────────────────────────────────────────────

  bool _roomAllowsEvening(Room room) {
    final name = room.name.toLowerCase();
    return name.contains('trefpunt aquarium') || name.contains('de kuil in het gemeentehuis');
  }

  int _isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thu = d.add(Duration(days: 4 - d.weekday));
    final yearStart = DateTime.utc(thu.year, 1, 1);
    return (thu.difference(yearStart).inDays ~/ 7) + 1;
  }

  Widget _buildWeekScheduleView() {
    final roomProvider = context.watch<RoomProvider>();
    final reservationProvider = context.watch<ReservationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final now = DateTime.now();

    final bookableRooms = roomProvider.rooms.where((r) => r.isBookable).toList();
    final endDate = _scheduleWeekStart.add(const Duration(days: 13));
    final rangeLabel =
        '${DateFormat('d MMM', 'nl').format(_scheduleWeekStart)} – ${DateFormat('d MMM', 'nl').format(endDate)}';

    return Column(
      children: [
        // Week navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _scheduleWeekStart =
                    DateTime.utc(_scheduleWeekStart.year, _scheduleWeekStart.month, _scheduleWeekStart.day - 7)),
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
                  rangeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _scheduleWeekStart = DateTime.utc(
                    _scheduleWeekStart.year, _scheduleWeekStart.month, _scheduleWeekStart.day + 7)),
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

        if (bookableRooms.isEmpty)
          const Expanded(child: Center(child: Text('Geen ruimten beschikbaar')))
        else
          Expanded(
            child: ListView(
              children: [
                for (final room in bookableRooms)
                  _buildRoomScheduleSection(room, reservationProvider, authProvider, now),
                const SizedBox(height: 16),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoomScheduleSection(
      Room room, ReservationProvider reservationProvider, AuthProvider authProvider, DateTime now) {
    final allowsEvening = _roomAllowsEvening(room);
    final dayParts = DayPart.values.where((dp) => dp != DayPart.avond || allowsEvening).toList();

    final week1Start = _scheduleWeekStart;
    final week2Start = _scheduleWeekStart.add(const Duration(days: 7));
    final week1Num = _isoWeekNumber(week1Start);
    final week2Num = _isoWeekNumber(week2Start);

    // Compacte dagdeel-headers voor één weekhelft
    Widget dayPartHeaders() => Row(
      children: [
        const SizedBox(width: 52),
        ...dayParts.map((dp) => Expanded(
          child: Text(
            dp.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        )),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ruimte header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.primary,
          child: Text(
            room.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        // Week-nummer headers naast elkaar
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(160),
                child: Text(
                  'Week $week1Num  ·  ${DateFormat('d MMM', 'nl').format(week1Start)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            Container(width: 1, color: Colors.white),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(160),
                child: Text(
                  'Week $week2Num  ·  ${DateFormat('d MMM', 'nl').format(week2Start)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Dagdeel-kolom headers naast elkaar
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(180),
                child: dayPartHeaders(),
              ),
            ),
            Container(width: 1, color: Colors.grey[300]),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(180),
                child: dayPartHeaders(),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        // 7 rijen: dag i van week 1 links, dag i van week 2 rechts
        ...List.generate(7, (i) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildCoordDayRowCompact(
                      room, week1Start.add(Duration(days: i)), dayParts,
                      reservationProvider, authProvider, now,
                    ),
                  ),
                  Container(width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: _buildCoordDayRowCompact(
                      room, week2Start.add(Duration(days: i)), dayParts,
                      reservationProvider, authProvider, now,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCoordDayRowCompact(
    Room room,
    DateTime date,
    List<DayPart> dayParts,
    ReservationProvider reservationProvider,
    AuthProvider authProvider,
    DateTime now,
  ) {
    final dayLabel = DateFormat('EEE', 'nl').format(date);
    final dateLabel = DateFormat('d/M', 'nl').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(dateLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          ...dayParts.map((dayPart) {
            final status = reservationProvider.getDayPartStatus(
              room.id, date, dayPart, authProvider.userName,
            );
            final dpStartHour = 8 + (dayPart.startSlotIndex ~/ 2);
            final dpStartMinute = (dayPart.startSlotIndex % 2) * 30;
            final dayPartStart = DateTime(date.year, date.month, date.day, dpStartHour, dpStartMinute);
            final isPast = dayPartStart.isBefore(now);

            return Expanded(
              child: _CoordDayPartCell(
                status: status,
                isPast: isPast,
                onTap: isPast
                    ? null
                    : () => _coordShowSlotDialog(room, date, dayPart, status, authProvider),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCoordDayRow(
    Room room,
    DateTime date,
    List<DayPart> dayParts,
    ReservationProvider reservationProvider,
    AuthProvider authProvider,
    DateTime now,
  ) {
    final dayLabel = DateFormat('EEE', 'nl').format(date);
    final dateLabel = DateFormat('d MMM', 'nl').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(dateLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ...dayParts.map((dayPart) {
            final status = reservationProvider.getDayPartStatus(
              room.id, date, dayPart, authProvider.userName,
            );
            final dpStartHour = 8 + (dayPart.startSlotIndex ~/ 2);
            final dpStartMinute = (dayPart.startSlotIndex % 2) * 30;
            final dayPartStart = DateTime(date.year, date.month, date.day, dpStartHour, dpStartMinute);
            final isPast = dayPartStart.isBefore(now);

            return Expanded(
              child: _CoordDayPartCell(
                status: status,
                isPast: isPast,
                onTap: isPast
                    ? null
                    : () => _coordShowSlotDialog(room, date, dayPart, status, authProvider),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _coordShowSlotDialog(
    Room room,
    DateTime date,
    DayPart dayPart,
    DayPartStatus status,
    AuthProvider authProvider,
  ) async {
    final reservationProvider = context.read<ReservationProvider>();
    final dateLabel = DateFormat('EEEE d MMMM', 'nl').format(date);
    final bookerName = status.hasAnyBookings
        ? (status.firstOtherBookerName ?? authProvider.userName)
        : null;

    if (bookerName != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${dayPart.displayName} – $dateLabel'),
          content: Text('$bookerName heeft dit dagdeel geboekt in ${room.name}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'reassign'),
              child: const Text('Toewijzen aan...'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Wissen'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (action == 'cancel') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bevestig wissen'),
            content: Text(
                'Wil je de boeking van $bookerName voor ${dayPart.displayName.toLowerCase()} op $dateLabel wissen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Wissen'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          try {
            await reservationProvider.cancelDayPartReservation(
              roomId: room.id,
              date: date,
              dayPart: dayPart,
              userName: bookerName, // de daadwerkelijke boeker, niet de coördinator
              isSuperuser: true,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${dayPart.displayName} gewist'), backgroundColor: Colors.orange),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.red),
              );
            }
          }
        }
      } else if (action == 'reassign') {
        try {
          await reservationProvider.cancelDayPartReservation(
            roomId: room.id,
            date: date,
            dayPart: dayPart,
            userName: bookerName, // de daadwerkelijke boeker, niet de coördinator
            isSuperuser: true,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Wissen mislukt: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red),
            );
          }
          return;
        }
        if (mounted) await _coordAssignDayPart(room, date, dayPart, authProvider);
      }
    } else {
      await _coordAssignDayPart(room, date, dayPart, authProvider);
    }
  }

  Future<void> _coordAssignDayPart(
      Room room, DateTime date, DayPart dayPart, AuthProvider authProvider) async {
    final reservationProvider = context.read<ReservationProvider>();
    final eenvoudigUsers = authProvider.allUsers
        .where((u) => u.role == UserRole.gebruikerEenvoud)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (eenvoudigUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Geen standaard gebruikers beschikbaar'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final selectedUser = await showDialog<User>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Toewijzen – ${dayPart.displayName}'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: eenvoudigUsers.length,
            itemBuilder: (ctx, i) {
              final user = eenvoudigUsers[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Text(user.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.teal[800], fontWeight: FontWeight.bold)),
                ),
                title: Text(user.name),
                subtitle: user.comment != null && user.comment!.isNotEmpty
                    ? Text(user.comment!, style: const TextStyle(fontSize: 12))
                    : null,
                onTap: () => Navigator.pop(ctx, user),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
        ],
      ),
    );

    if (selectedUser == null || !mounted) return;

    try {
      await reservationProvider.createDayPartReservation(
        roomId: room.id,
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
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildColumnHeader(String label, Color color) {
    return Expanded(
      flex: 2,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBadge(double hours, Color color, {bool isTotal = false}) {
    return Expanded(
      flex: 2,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isTotal ? color : color.withAlpha((255 * 0.15).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${hours.toStringAsFixed(1)}u',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserHours {
  final String name;
  final int slotsCol1; // tot 13:00
  final int slotsCol2; // 13:00-17:00
  final int slotsCol3; // 19:00-22:00
  final String? comment;

  _UserHours({
    required this.name,
    required this.slotsCol1,
    required this.slotsCol2,
    required this.slotsCol3,
    this.comment,
  });

  int get totalSlots => slotsCol1 + slotsCol2 + slotsCol3;
  double get hoursCol1 => slotsCol1 * 0.5;
  double get hoursCol2 => slotsCol2 * 0.5;
  double get hoursCol3 => slotsCol3 * 0.5;
  double get totalHours => totalSlots * 0.5;
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserHoursCard extends StatelessWidget {
  final _UserHours user;
  final bool isVerwerkt;
  final VoidCallback? onToggle;

  const _UserHoursCard({
    required this.user,
    this.isVerwerkt = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: isVerwerkt ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar en naam (flex: 3)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isVerwerkt ? Colors.green[200] : Colors.teal[100],
                    child: isVerwerkt
                        ? Icon(Icons.check, size: 16, color: Colors.green[800])
                        : Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Colors.teal[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.comment != null && user.comment!.isNotEmpty)
                          Text(
                            user.comment!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Kolom 1: Tot 13u
            _buildHoursBadge(user.hoursCol1, Colors.orange),
            // Kolom 2: 13-17u
            _buildHoursBadge(user.hoursCol2, Colors.blue),
            // Kolom 3: 19-22u
            _buildHoursBadge(user.hoursCol3, Colors.purple),
            // Totaal + verwerkt knop
            _buildHoursBadge(user.totalHours, Colors.teal, isTotal: true),
            if (onToggle != null)
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    isVerwerkt ? Icons.check_circle : Icons.check_circle_outline,
                    color: isVerwerkt ? Colors.green : Colors.grey[400],
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursBadge(double hours, Color color, {bool isTotal = false}) {
    final hasHours = hours > 0;
    return Expanded(
      flex: 2,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: hasHours
                ? (isTotal ? color : color.withAlpha((255 * 0.15).round()))
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            hasHours ? '${hours.toStringAsFixed(1)}u' : '-',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: hasHours ? (isTotal ? Colors.white : color) : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

/// Prominente week kaart voor lopende/volgende week
class _WeekCardProminent extends StatelessWidget {
  final DateTime weekStart;
  final int weekNumber;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WeekCardProminent({
    required this.weekStart,
    required this.weekNumber,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Card(
      color: color.withAlpha((255 * 0.1).round()),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Week $weekNumber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: color,
                ),
              ),
              Text(
                '${DateFormat('d MMM').format(weekStart)} - ${DateFormat('d MMM').format(weekEnd)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.arrow_forward, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dagdeel cel voor coordinator weekrooster
class _CoordDayPartCell extends StatelessWidget {
  final DayPartStatus status;
  final bool isPast;
  final VoidCallback? onTap;

  const _CoordDayPartCell({
    required this.status,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String label;

    if (isPast) {
      bgColor = const Color(0xFFCCCCCC); // grijs = verlopen
      label = status.hasAnyBookings
          ? (status.firstOtherBookerName ?? 'Bezet')
          : 'Vrij';
    } else if (!status.hasAnyBookings) {
      bgColor = const Color(0xFFFF2800); // rood = vrij
      label = 'Vrij';
    } else {
      bgColor = const Color(0xFF4CBB17); // groen = bezet
      label = status.firstOtherBookerName ?? 'Bezet';
    }

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
          onTap: onTap,
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
                        fontSize: 13,
                        color: isPast ? Colors.grey[700] : Colors.white,
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

/// Compacte week kaart voor grid weergave
class _WeekCardCompact extends StatelessWidget {
  final int weekNumber;
  final DateTime weekStart;
  final DateTime weekEnd;
  final bool isCurrentWeek;
  final bool isNextWeek;
  final bool isFuture;
  final bool isVerwerkt;
  final VoidCallback? onTap;

  const _WeekCardCompact({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrentWeek,
    required this.isNextWeek,
    required this.isFuture,
    this.isVerwerkt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isCurrentWeek) {
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Colors.white;
      borderColor = Theme.of(context).colorScheme.primary;
    } else if (isNextWeek) {
      bgColor = Colors.blue.withAlpha((255 * 0.15).round());
      textColor = Colors.blue[800]!;
      borderColor = Colors.blue;
    } else if (isFuture) {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey;
      borderColor = Colors.grey[300]!;
    } else if (isVerwerkt) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
      borderColor = Colors.green[400]!;
    } else {
      bgColor = Colors.white;
      textColor = Colors.black87;
      borderColor = Colors.grey[300]!;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            if (isVerwerkt)
              Icon(Icons.check_circle, size: 10, color: Colors.green[700]),
            Text(
              '$weekNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
            Text(
              DateFormat('d/M').format(weekStart),
              style: TextStyle(
                fontSize: 9,
                color: textColor.withAlpha((255 * 0.7).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
