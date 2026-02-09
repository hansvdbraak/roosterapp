import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/reservation_provider.dart';
import '../models/room.dart';
import '../models/user.dart';
import '../models/time_slot.dart';
import 'welcome_screen.dart';
import 'room_detail_screen.dart';
import 'add_room_screen.dart';
import 'user_management_screen.dart';
import 'coordinator_dashboard_screen.dart';
import 'simple_user_overview_screen.dart';
import 'profile_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superuser:
        return Colors.purple;
      case UserRole.coordinator:
        return Colors.orange;
      case UserRole.gebruiker:
        return Colors.blue;
      case UserRole.gebruikerEenvoud:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final roomProvider = context.watch<RoomProvider>();
    final reservationProvider = context.watch<ReservationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruimtes'),
        actions: [
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              DateFormat('d MMM', 'nl').format(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _logout();
                  break;
                case 'profile':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                  break;
                case 'users':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                  );
                  break;
                case 'dashboard':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoordinatorDashboardScreen()),
                  );
                  break;
                case 'user_overview':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SimpleUserOverviewScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              // Gebruikersnaam en rol
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(authProvider.userRole).withAlpha((255 * 0.1).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getRoleColor(authProvider.userRole).withAlpha((255 * 0.3).round()),
                        ),
                      ),
                      child: Text(
                        authProvider.userRole.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getRoleColor(authProvider.userRole),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),

              // Mijn profiel (voor alle gebruikers)
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Mijn profiel'),
                  ],
                ),
              ),

              // Coördinator dashboard (voor coördinatoren en superuser)
              if (authProvider.isCoordinator)
                const PopupMenuItem(
                  value: 'dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('Bezettingsoverzicht'),
                    ],
                  ),
                ),

              // Eenvoudige gebruikers overzicht (voor coördinatoren en superuser)
              if (authProvider.isCoordinator)
                const PopupMenuItem(
                  value: 'user_overview',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline),
                      SizedBox(width: 8),
                      Text('Eenvoudige gebruikers'),
                    ],
                  ),
                ),

              // Gebruikersbeheer (alleen voor superuser)
              if (authProvider.isSuperuser)
                const PopupMenuItem(
                  value: 'users',
                  child: Row(
                    children: [
                      Icon(Icons.people),
                      SizedBox(width: 8),
                      Text('Gebruikersbeheer'),
                    ],
                  ),
                ),

              if (authProvider.isCoordinator)
                const PopupMenuDivider(),

              // Uitloggen
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Uitloggen'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Filter alleen actieve ruimtes (niet overbodig)
          final activeRooms = roomProvider.rooms.where((r) => r.isBookable).toList();

          if (activeRooms.isEmpty) {
            return const Center(
              child: Text('Geen ruimtes beschikbaar'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: activeRooms.map((room) {
                return _RoomCard(
                  room: room,
                  selectedDate: _selectedDate,
                  reservationProvider: reservationProvider,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomDetailScreen(
                          room: room,
                          initialDate: _selectedDate,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: authProvider.isSuperuser
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddRoomScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Ruimte'),
            )
          : null,
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final DateTime selectedDate;
  final ReservationProvider reservationProvider;
  final VoidCallback onTap;

  const _RoomCard({
    required this.room,
    required this.selectedDate,
    required this.reservationProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reservations = reservationProvider.getReservationsForRoom(room.id, selectedDate);
    final totalSlots = 28;
    final bookedSlots = reservations.length;
    final availableSlots = totalSlots - bookedSlots;

    // Bepaal status kleur
    Color statusColor;
    String statusText;
    if (bookedSlots == 0) {
      statusColor = Colors.green;
      statusText = 'Beschikbaar';
    } else if (bookedSlots == totalSlots) {
      statusColor = Colors.red;
      statusText = 'Volledig bezet';
    } else {
      statusColor = Colors.orange;
      statusText = '$availableSlots/$totalSlots vrij';
    }

    // Huidige/volgende reservering
    String? currentBooker;
    if (reservations.isNotEmpty) {
      final now = DateTime.now();
      final currentSlotIndex = ((now.hour - 8) * 2) + (now.minute >= 30 ? 1 : 0);

      // Check of er nu iemand boekt
      final currentRes = reservations.where((r) => r.slotIndex == currentSlotIndex).firstOrNull;
      if (currentRes != null) {
        final slot = TimeSlot(date: selectedDate, slotIndex: currentRes.slotIndex);
        currentBooker = 'Nu: ${currentRes.bookerName} (${slot.getDisplayTime()})';
      } else {
        // Volgende reservering
        final nextRes = reservations
            .where((r) => r.slotIndex > currentSlotIndex)
            .toList()
          ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
        if (nextRes.isNotEmpty) {
          final slot = TimeSlot(date: selectedDate, slotIndex: nextRes.first.slotIndex);
          currentBooker = 'Volg: ${nextRes.first.bookerName} (${slot.getDisplayTime()})';
        }
      }
    }

    // Bereken breedte op basis van schermgrootte (minimaal 280, maximaal 400)
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 600
        ? (screenWidth - 56) / 2  // 2 kolommen bij breed scherm
        : screenWidth - 32;        // 1 kolom bij smal scherm
    final constrainedWidth = cardWidth.clamp(200.0, 400.0);

    return SizedBox(
      width: constrainedWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Achtergrond afbeelding
              if (room.imageUrl != null && room.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Image.network(
                    room.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(color: Colors.grey[100]);
                    },
                  ),
                ),
              // Semi-transparante overlay voor leesbaarheid
              if (room.imageUrl != null && room.imageUrl!.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                  ),
                ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        room.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: room.imageUrl != null && room.imageUrl!.isNotEmpty ? Colors.white : null,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: room.imageUrl != null && room.imageUrl!.isNotEmpty ? Colors.white : null),
                  ],
                ),
                if (room.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    room.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: room.imageUrl != null && room.imageUrl!.isNotEmpty ? Colors.white70 : Colors.grey[600],
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: room.imageUrl != null && room.imageUrl!.isNotEmpty
                          ? (statusText == 'Beschikbaar' ? const Color(0xFF7FFF00) : Colors.white)
                          : statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: room.imageUrl != null && room.imageUrl!.isNotEmpty
                            ? (statusText == 'Beschikbaar' ? const Color(0xFF7FFF00) : Colors.white)
                            : statusColor,
                        fontWeight: statusText == 'Beschikbaar' ? FontWeight.bold : FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (currentBooker != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    currentBooker,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: room.imageUrl != null && room.imageUrl!.isNotEmpty ? Colors.white70 : Colors.grey[600],
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
