import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../state/state.dart';
import '../../models/models.dart';
import '../../services/local/admin_search_preferences_service.dart';
import '../../shared/widgets/admin_search_history_section.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() =>
      _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<String> _searchHistory = [];
  StreamSubscription<String?>? _clearSearchSubscription;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _clearSearchSubscription = AdminSearchPreferencesService.instance
        .clearCurrentSearchStream
        .listen(_handleClearSearchRequest);
    _restoreSearchHistory();
    _refresh();
  }

  @override
  void dispose() {
    _persistSearchToHistory();
    _clearSearchSubscription?.cancel();
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUserState>().fetchAllUsers();
    });
  }

  Future<void> _restoreSearchHistory() async {
    final history = await AdminSearchPreferencesService.instance
        .readSearchHistory(AdminSearchPreferenceKeys.userManagement);
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  void _handleSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _handleSearchFocusChange() {
    if (!_searchFocusNode.hasFocus) {
      _persistSearchToHistory();
    }
  }

  void _persistSearchToHistory() {
    final value = _searchController.text.trim();
    if (value.isEmpty) {
      return;
    }

    unawaited(_saveSearchHistoryEntry(value));
  }

  Future<void> _saveSearchHistoryEntry(String value) async {
    final history = await AdminSearchPreferencesService.instance
        .addSearchHistoryEntry(AdminSearchPreferenceKeys.userManagement, value);
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  Future<void> _selectSearchHistoryEntry(String value) async {
    _searchController.text = value;
    _handleSearchChanged(value);
    await _saveSearchHistoryEntry(value);
  }

  Future<void> _removeSearchHistoryEntry(String value) async {
    final history = await AdminSearchPreferencesService.instance
        .removeSearchHistoryEntry(
          AdminSearchPreferenceKeys.userManagement,
          value,
        );
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = history);
  }

  Future<void> _clearSearchHistory() async {
    await AdminSearchPreferencesService.instance.clearSearchHistory(
      AdminSearchPreferenceKeys.userManagement,
    );
    if (!mounted) {
      return;
    }

    setState(() => _searchHistory = []);
  }

  void _handleClearSearchRequest(String? key) {
    if (key != null && key != AdminSearchPreferenceKeys.userManagement) {
      return;
    }

    _persistSearchToHistory();
    if (!mounted) {
      return;
    }

    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 8),
              const Text(
                'View and manage all registered users. Tap a user to see their profile.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search Users',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: _handleSearchChanged,
                onSubmitted: _saveSearchHistoryEntry,
              ),
              if (_searchHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                AdminSearchHistorySection(
                  history: _searchHistory,
                  onSelected: _selectSearchHistoryEntry,
                  onDeleted: _removeSearchHistoryEntry,
                  onClearAll: _clearSearchHistory,
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await context.read<AdminUserState>().fetchAllUsers();
                  },
                  child: Consumer<AdminUserState>(
                    builder: (context, adminState, child) {
                      if (adminState.isLoading && adminState.users.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filteredUsers = adminState.users.where((u) {
                        final text = '${u.name} ${u.email}'.toLowerCase();
                        return text.contains(_searchQuery.toLowerCase());
                      }).toList();

                      if (filteredUsers.isEmpty) {
                        return ListView(
                          children: const [
                             SizedBox(height: 100),
                             Center(child: Text('No users found.')),
                          ],
                        );
                      }

                      return ListView.separated(
                        itemCount: filteredUsers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final statusLabel = user.isActive ? 'Active' : 'Banned';
                          
                          return InkWell(
                            onTap: () => context.push('/seller/${user.id}'),
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(statusLabel)
                                    .withOpacity(0.2),
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: _getStatusColor(statusLabel),
                                  ),
                                ),
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  Text(
                                    'Role: ${user.role}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(statusLabel)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: _getStatusColor(statusLabel),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'ToggleStatus') {
                                        _confirmToggleStatus(user);
                                      } else if (val == 'MakeAdmin') {
                                        _updateRole(user, 'admin');
                                      } else if (val == 'MakeUser') {
                                        _updateRole(user, 'user');
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'ToggleStatus',
                                        child: Text(
                                          user.isActive ? 'Ban User' : 'Unban User',
                                          style: TextStyle(
                                            color: user.isActive ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ),
                                      if (user.role != 'admin')
                                        const PopupMenuItem(
                                          value: 'MakeAdmin',
                                          child: Text('Promote to Admin'),
                                        ),
                                      if (user.role == 'admin')
                                        const PopupMenuItem(
                                          value: 'MakeUser',
                                          child: Text('Demote to User'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
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
    return Colors.orange;
  }

  void _confirmToggleStatus(UserModel user) {
    final action = user.isActive ? 'Ban' : 'Unban';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action'),
        content: Text(
          'Are you sure you want to $action ${user.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive ? Colors.red : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context
                    .read<AdminUserState>()
                    .toggleUserStatus(user.id, user.isActive);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User ${action}ned successfully.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to $action user: $e')),
                  );
                }
              }
            },
            child: Text('$action User'),
          ),
        ],
      ),
    );
  }

  void _updateRole(UserModel user, String newRole) async {
    try {
      await context.read<AdminUserState>().updateUserRole(user.id, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User role updated to $newRole.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e')),
        );
      }
    }
  }
}
