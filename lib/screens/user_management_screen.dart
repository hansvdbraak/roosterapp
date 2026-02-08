import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/app_header.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final users = authProvider.allUsers;
    final currentSession = authProvider.currentSession;
    final isSuperuser = currentSession?.isSuperuser ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gebruikersbeheer'),
        actions: const [
          AppHeaderActions(showDate: true),
        ],
      ),
      body: users.isEmpty
          ? const Center(child: Text('Geen gebruikers gevonden'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(
                  user: user,
                  isSuperuser: isSuperuser,
                  isCurrentUser: authProvider.currentUser?.id == user.id,
                );
              },
            ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final bool isSuperuser;
  final bool isCurrentUser;

  const _UserCard({
    required this.user,
    required this.isSuperuser,
    required this.isCurrentUser,
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superuser:
        return Icons.security;
      case UserRole.coordinator:
        return Icons.analytics;
      case UserRole.gebruiker:
        return Icons.person;
      case UserRole.gebruikerEenvoud:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(user.role);
    final canEdit = isSuperuser && !isCurrentUser && user.role != UserRole.superuser;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isSuperuser ? () => _showUserDetails(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withAlpha((255 * 0.2).round()),
                    child: Icon(_getRoleIcon(user.role), color: roleColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha((255 * 0.2).round()),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Jij',
                                  style: TextStyle(fontSize: 12, color: Colors.green),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  canEdit
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) => _handleAction(context, value),
                          itemBuilder: (context) => _buildMenuItems(),
                        )
                      : (isSuperuser
                          ? Icon(Icons.chevron_right, color: Colors.grey[400])
                          : const SizedBox()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: roleColor.withAlpha((255 * 0.3).round())),
                    ),
                    child: Text(
                      user.role.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: roleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (user.comment != null && user.comment!.isNotEmpty && isSuperuser) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.comment, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.comment!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _UserDetailsSheet(user: user, isCurrentUser: isCurrentUser),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[];

    // Rol wijzigen opties - superuser kan niet worden toegekend
    if (user.role != UserRole.gebruikerEenvoud) {
      items.add(const PopupMenuItem(
        value: 'make_eenvoud',
        child: Row(
          children: [
            Icon(Icons.person_outline, size: 20),
            SizedBox(width: 8),
            Text('Maak eenvoudige gebruiker'),
          ],
        ),
      ));
    }

    if (user.role != UserRole.gebruiker) {
      items.add(const PopupMenuItem(
        value: 'make_gebruiker',
        child: Row(
          children: [
            Icon(Icons.person, size: 20),
            SizedBox(width: 8),
            Text('Maak gebruiker'),
          ],
        ),
      ));
    }

    if (user.role != UserRole.coordinator) {
      items.add(const PopupMenuItem(
        value: 'make_coordinator',
        child: Row(
          children: [
            Icon(Icons.analytics, size: 20),
            SizedBox(width: 8),
            Text('Maak coordinator'),
          ],
        ),
      ));
    }

    if (items.isNotEmpty) {
      items.add(const PopupMenuDivider());
    }

    // Commentaar bewerken
    items.add(const PopupMenuItem(
      value: 'edit_comment',
      child: Row(
        children: [
          Icon(Icons.comment, size: 20),
          SizedBox(width: 8),
          Text('Commentaar bewerken'),
        ],
      ),
    ));

    items.add(const PopupMenuDivider());

    items.add(const PopupMenuItem(
      value: 'delete',
      child: Row(
        children: [
          Icon(Icons.delete, size: 20, color: Colors.red),
          SizedBox(width: 8),
          Text('Verwijderen', style: TextStyle(color: Colors.red)),
        ],
      ),
    ));

    return items;
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final authProvider = context.read<AuthProvider>();

    try {
      switch (action) {
        case 'make_eenvoud':
          await _confirmRoleChange(context, authProvider, UserRole.gebruikerEenvoud);
          break;
        case 'make_gebruiker':
          await _confirmRoleChange(context, authProvider, UserRole.gebruiker);
          break;
        case 'make_coordinator':
          await _confirmRoleChange(context, authProvider, UserRole.coordinator);
          break;
        case 'edit_comment':
          await _editComment(context, authProvider);
          break;
        case 'delete':
          await _confirmDelete(context, authProvider);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmRoleChange(
    BuildContext context,
    AuthProvider authProvider,
    UserRole newRole,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rol wijzigen'),
        content: Text(
          'Weet je zeker dat je ${user.name} de rol "${newRole.displayName}" wilt geven?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wijzigen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authProvider.updateUserRole(userId: user.id, newRole: newRole);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} is nu ${newRole.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _editComment(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final controller = TextEditingController(text: user.comment ?? '');

    final newComment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commentaar voor ${user.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Bijv. afdeling, functie, bijzonderheden...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    if (newComment != null) {
      await authProvider.updateUserComment(userId: user.id, comment: newComment);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commentaar opgeslagen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gebruiker verwijderen'),
        content: Text(
          'Weet je zeker dat je ${user.name} wilt verwijderen? Dit kan niet ongedaan worden gemaakt.',
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

    if (confirm == true) {
      await authProvider.deleteUser(user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} is verwijderd'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

class _UserDetailsSheet extends StatelessWidget {
  final User user;
  final bool isCurrentUser;

  const _UserDetailsSheet({
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          user.role.displayName,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentUser)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Jij',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Contact info
              _buildSection(context, 'Contact', [
                _buildInfoRow(Icons.email, 'E-mail', user.email),
                if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                  _buildInfoRow(Icons.phone, 'Telefoon', user.phoneNumber!),
              ]),

              // Adres
              if (user.address != null || user.city != null) ...[
                const SizedBox(height: 16),
                _buildSection(context, 'Adres', [
                  if (user.address != null && user.address!.isNotEmpty)
                    _buildInfoRow(Icons.home, 'Adres', user.address!),
                  if (user.postalCode != null && user.postalCode!.isNotEmpty)
                    _buildInfoRow(Icons.markunread_mailbox, 'Postcode', user.postalCode!),
                  if (user.city != null && user.city!.isNotEmpty)
                    _buildInfoRow(Icons.location_city, 'Plaats', user.city!),
                ]),
              ],

              // Commentaar
              if (user.comment != null && user.comment!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(context, 'Commentaar', [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user.comment!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]),
              ],

              // Rol info
              const SizedBox(height: 16),
              _buildSection(context, 'Rol informatie', [
                _buildInfoRow(Icons.security, 'Rol', user.role.displayName),
                _buildInfoRow(Icons.description, 'Beschrijving', user.role.description),
              ]),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
