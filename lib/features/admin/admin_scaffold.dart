import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/local/admin_search_preferences_service.dart';
import '../../state/state.dart';

class AdminScaffold extends StatefulWidget {
  const AdminScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  AdminSecurityState? _adminSecurityState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextState = context.read<AdminSecurityState>();
    if (_adminSecurityState == nextState) {
      return;
    }

    _adminSecurityState?.removeListener(_handleAdminSecurityChange);
    _adminSecurityState = nextState;
    _adminSecurityState?.addListener(_handleAdminSecurityChange);
    _adminSecurityState?.markActivity();
  }

  @override
  void dispose() {
    _adminSecurityState?.removeListener(_handleAdminSecurityChange);
    super.dispose();
  }

  void _handleAdminSecurityChange() {
    if (!mounted || _adminSecurityState == null) {
      return;
    }

    if (_adminSecurityState!.isSessionLocked ||
        !_adminSecurityState!.isAdminSessionActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final location = GoRouterState.of(context).matchedLocation;
        if (location.startsWith('/admin') && location != '/admin/login') {
          context.go('/admin/login');
        }
      });
    }
  }

  Future<void> _handleAdminLogout() async {
    context.read<AdminSecurityState>().clearAdminSession(
      message: 'Admin session ended.',
    );
    await context.read<UserState>().logout();
    if (mounted) {
      context.go('/');
    }
  }

  void _goToBranch(int index, {bool isMobile = false}) {
    context.read<AdminSecurityState>().markActivity();

    if (widget.navigationShell.currentIndex != index) {
      AdminSearchPreferencesService.instance.requestClearCurrentSearch();
    }

    widget.navigationShell.goBranch(index);
    if (isMobile) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final content = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => context.read<AdminSecurityState>().markActivity(),
      child: isDesktop
          ? Scaffold(
              backgroundColor: const Color(0xFF1E1E2C),
              body: SafeArea(
                child: Row(
                  children: [
                    _buildSidebar(context),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                        ),
                        child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: widget.navigationShell,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Admin Console',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: const Color(0xFF1E1E2C),
                iconTheme: const IconThemeData(color: Colors.white),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      hoverColor: Colors.white.withValues(alpha: 0.1),
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
              drawer: Drawer(
                backgroundColor: const Color(0xFF1E1E2C),
                child: _buildSidebar(context, isMobile: true),
              ),
              body: widget.navigationShell,
            ),
    );

    return content;
  }

  Widget _buildSidebar(BuildContext context, {bool isMobile = false}) {
    return Container(
      width: isMobile ? null : 250,
      color: const Color(0xFF1E1E2C),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 32),
              SizedBox(width: 8),
              Text(
                'CampusAdmin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isSelected: widget.navigationShell.currentIndex == 0,
            onTap: () => _goToBranch(0, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.shield_moon_rounded,
            label: 'Fraud',
            isSelected: widget.navigationShell.currentIndex == 1,
            onTap: () => _goToBranch(1, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.people_alt_rounded,
            label: 'Users',
            isSelected: widget.navigationShell.currentIndex == 2,
            onTap: () => _goToBranch(2, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.category_rounded,
            label: 'Categories',
            isSelected: widget.navigationShell.currentIndex == 3,
            onTap: () => _goToBranch(3, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.list_alt_rounded,
            label: 'Listings',
            isSelected: widget.navigationShell.currentIndex == 4,
            onTap: () => _goToBranch(4, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            isSelected: widget.navigationShell.currentIndex == 5,
            onTap: () => _goToBranch(5, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.campaign_rounded,
            label: 'Notifications',
            isSelected: widget.navigationShell.currentIndex == 6,
            onTap: () => _goToBranch(6, isMobile: isMobile),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            isSelected: widget.navigationShell.currentIndex == 7,
            onTap: () => _goToBranch(7, isMobile: isMobile),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Admin Logout',
            isSelected: false,
            onTap: _handleAdminLogout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blueAccent : Colors.white54,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blueAccent.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }
}
