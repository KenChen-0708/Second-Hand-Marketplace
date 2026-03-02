import 'package:flutter/material.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  // Mock data
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'Alice Smith',
      'email': 'alice@university.edu',
      'status': 'Active',
    },
    {'name': 'Bob Johnson', 'email': 'bob@university.edu', 'status': 'Banned'},
    {
      'name': 'Charlie Davis',
      'email': 'charlie@university.edu',
      'status': 'Warned',
    },
    {
      'name': 'Diana Prince',
      'email': 'diana@university.edu',
      'status': 'Active',
    },
  ];

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final text = '${u['name']} ${u['email']}'.toLowerCase();
      return text.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search Users',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredUsers.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(
                          user['status'] as String,
                        ).withValues(alpha: 0.2),
                        child: Text(
                          (user['name'] as String)[0].toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(user['status'] as String),
                          ),
                        ),
                      ),
                      title: Text(
                        user['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(user['email'] as String),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                user['status'] as String,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user['status'] as String,
                              style: TextStyle(
                                color: _getStatusColor(
                                  user['status'] as String,
                                ),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'Block') {
                                _confirmBlock(
                                  user['name'] as String,
                                  index,
                                  filteredUsers,
                                );
                              } else if (val == 'Warn') {
                                setState(() => user['status'] = 'Warned');
                              } else if (val == 'Unblock') {
                                setState(() => user['status'] = 'Active');
                              }
                            },
                            itemBuilder: (context) => [
                              if (user['status'] != 'Banned')
                                const PopupMenuItem(
                                  value: 'Block',
                                  child: Text(
                                    'Block/Ban User',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              if (user['status'] == 'Banned')
                                const PopupMenuItem(
                                  value: 'Unblock',
                                  child: Text('Unblock User'),
                                ),
                              if (user['status'] != 'Banned')
                                const PopupMenuItem(
                                  value: 'Warn',
                                  child: Text('Send Warning'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Active') return Colors.green;
    if (status == 'Banned') return Colors.red;
    return Colors.orange; // Warned
  }

  void _confirmBlock(String name, int index, List<dynamic> currentList) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Ban'),
        content: Text(
          'Are you sure you want to ban $name? This action will prevent the user from accessing their account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                currentList[index]['status'] = 'Banned';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User banned successfully.')),
              );
            },
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
  }
}
