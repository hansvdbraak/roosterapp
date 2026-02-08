import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../screens/welcome_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/coordinator_dashboard_screen.dart';
import '../screens/simple_user_overview_screen.dart';

/// Reusable app bar actions met datum en profiel menu
class AppHeaderActions extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback? onDateTap;
  final bool showDate;

  const AppHeaderActions({
    super.key,
    this.selectedDate,
    this.onDateTap,
    this.showDate = true,
  });

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

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final date = selectedDate ?? DateTime.now();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Datum weergave
        if (showDate)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: onDateTap != null
                ? TextButton.icon(
                    onPressed: onDateTap,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      DateFormat('d MMM', 'nl').format(date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                : Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM', 'nl').format(date),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),

        // Profiel menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          onSelected: (value) {
            switch (value) {
              case 'logout':
                _logout(context);
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
    );
  }
}
