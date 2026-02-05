import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/room_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

enum DashboardView { choice, weekList, quarterList, weekDetail, quarterDetail }

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

  @override
  void initState() {
    super.initState();
    // In januari: toon vorig jaar
    if (DateTime.now().month == 1) {
      _selectedYear = DateTime.now().year - 1;
    }
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
      if (_currentView == DashboardView.weekDetail) {
        _currentView = DashboardView.weekList;
        _selectedWeekStart = null;
      } else if (_currentView == DashboardView.quarterDetail) {
        _currentView = DashboardView.quarterList;
        _selectedQuarter = null;
      } else if (_currentView == DashboardView.weekList || _currentView == DashboardView.quarterList) {
        _currentView = DashboardView.choice;
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
        leading: _currentView != DashboardView.choice
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        actions: [
          if (_currentView == DashboardView.weekList || _currentView == DashboardView.quarterList)
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
            'Bekijk de uren per eenvoudige gebruiker',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.view_week,
                  title: 'Wekelijks',
                  subtitle: 'Per week bekijken',
                  onTap: _selectWeekly,
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
                : const Icon(Icons.chevron_right),
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

    // Verzamel uren per eenvoudige gebruiker
    final eenvoudigUsers = _getEenvoudigUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      weekStart,
      7,
    );

    return _buildUserHoursList(
      title: 'Week $weekNumber',
      subtitle: '${DateFormat('d MMMM', 'nl').format(weekStart)} - ${DateFormat('d MMMM yyyy', 'nl').format(weekEnd)}',
      users: eenvoudigUsers,
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

    // Verzamel uren per eenvoudige gebruiker
    final eenvoudigUsers = _getEenvoudigUsersWithHours(
      reservationProvider,
      roomProvider,
      authProvider,
      quarterStart,
      daysInQuarter,
    );

    return _buildUserHoursList(
      title: _getQuarterName(_selectedQuarter!),
      subtitle: '${DateFormat('d MMMM', 'nl').format(quarterStart)} - ${DateFormat('d MMMM yyyy', 'nl').format(quarterEnd)}',
      users: eenvoudigUsers,
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

    // Filter alleen eenvoudige gebruikers
    final eenvoudigUsers = <_UserHours>[];
    for (final name in allNames) {
      final user = authProvider.getUserByName(name);
      // Alleen eenvoudige gebruikers tonen
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

  Widget _buildUserHoursList({
    required String title,
    required String subtitle,
    required List<_UserHours> users,
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
                          'Alleen eenvoudige gebruikers (dagdeel-boekingen)',
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
                      'Geen eenvoudige gebruikers hebben geboekt',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...users.map((user) => _UserHoursCard(user: user)),

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
                        '${users.length} eenvoudige gebruikers',
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
      ],
    );
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

  const _UserHoursCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
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
                    backgroundColor: Colors.teal[100],
                    child: Text(
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
            // Totaal
            _buildHoursBadge(user.totalHours, Colors.teal, isTotal: true),
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

/// Compacte week kaart voor grid weergave
class _WeekCardCompact extends StatelessWidget {
  final int weekNumber;
  final DateTime weekStart;
  final DateTime weekEnd;
  final bool isCurrentWeek;
  final bool isNextWeek;
  final bool isFuture;
  final VoidCallback? onTap;

  const _WeekCardCompact({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrentWeek,
    required this.isNextWeek,
    required this.isFuture,
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
