import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/state.dart';

class AdminScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E2C), // Dark dashboard theme
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
                    child: navigationShell,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Admin Console',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E1E2C),
          iconTheme: const IconThemeData(color: Colors.white),
          // Removing the circle background (IconButton style) from the menu icon
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
        body: navigationShell,
      );
    }
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
              Icon(
                Icons.shield_rounded,
                color: Colors.blueAccent,
                size: 32,
              ),
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
            isSelected: navigationShell.currentIndex == 0,
            onTap: () {
              navigationShell.goBranch(0);
              if (isMobile) Navigator.pop(context);
            },
          ),
          _NavItem(
            icon: Icons.people_alt_rounded,
            label: 'Users',
            isSelected: navigationShell.currentIndex == 1,
            onTap: () {
              navigationShell.goBranch(1);
              if (isMobile) Navigator.pop(context);
            },
          ),
          _NavItem(
            icon: Icons.category_rounded,
            label: 'Categories',
            isSelected: navigationShell.currentIndex == 2,
            onTap: () {
              navigationShell.goBranch(2);
              if (isMobile) Navigator.pop(context);
            },
          ),
          _NavItem(
            icon: Icons.list_alt_rounded,
            label: 'Listings',
            isSelected: navigationShell.currentIndex == 3,
            onTap: () {
              navigationShell.goBranch(3);
              if (isMobile) Navigator.pop(context);
            },
          ),
          _NavItem(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            isSelected: navigationShell.currentIndex == 4,
            onTap: () {
              navigationShell.goBranch(4);
              if (isMobile) Navigator.pop(context);
            },
          ),
          _NavItem(
            icon: Icons.campaign_rounded,
            label: 'Notifications',
            isSelected: navigationShell.currentIndex == 5,
            onTap: () {
              navigationShell.goBranch(5);
              if (isMobile) Navigator.pop(context);
            },
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.logout_rounded,
            label: 'Admin Logout',
            isSelected: false,
            onTap: () async {
              await context.read<UserState>().logout();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

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
