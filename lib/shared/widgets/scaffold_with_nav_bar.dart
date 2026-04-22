import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/order/order_service.dart';
import '../../state/state.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  final OrderService _orderService = OrderService();
  String? _loadedUserId;
  int _profileActionCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<UserState>().currentUser?.id;
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      _profileActionCount = 0;
      if (userId != null) {
        _loadProfileActionCount(userId);
      }
    }
  }

  Future<void> _loadProfileActionCount(String userId) async {
    try {
      final results = await Future.wait([
        _orderService.getBuyerOrders(userId),
        _orderService.getSellerOrders(userId),
      ]);
      if (!mounted || _loadedUserId != userId) {
        return;
      }
      final buyerActions = results[0].where(_orderNeedsAction).length;
      final sellerActions = results[1].where(_orderNeedsAction).length;
      setState(() => _profileActionCount = buyerActions + sellerActions);
    } catch (_) {
      if (mounted && _loadedUserId == userId) {
        setState(() => _profileActionCount = 0);
      }
    }
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final selectedColor = Theme.of(context).colorScheme.primary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    // Watch for unread counts
    final unreadNotifications = context
        .watch<AppNotificationState>()
        .unreadCount;
    final unreadChats = context.watch<ChatConversationState>().unreadCount;
    final totalUnread = unreadNotifications + unreadChats + _profileActionCount;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        padding: EdgeInsets.zero,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Home
            _buildNavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: currentIndex == 0,
              onTap: () => _goBranch(0),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
            ),
            // Sell (center circle FAB)
            GestureDetector(
              onTap: () => _goBranch(1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48, // Reduced from 50 to prevent overflow
                      height: 48, // Reduced from 50 to prevent overflow
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add,
                        color: onPrimaryColor,
                        size: 28,
                      ), // Slightly smaller icon
                    ),
                    const SizedBox(height: 1), // Reduced from 2
                    Text(
                      'Sell',
                      style: TextStyle(
                        color: currentIndex == 1
                            ? selectedColor
                            : unselectedColor,
                        fontWeight: currentIndex == 1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                        height: 1.1, // Added height to control text spacing
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Profile
            _buildNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isSelected: currentIndex == 2,
              onTap: () => _goBranch(2),
              selectedColor: selectedColor,
              unselectedColor: unselectedColor,
              badgeCount: totalUnread,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    required Color unselectedColor,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 2.0,
        ), // Reduced vertical padding
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? selectedColor : unselectedColor,
                    size: 26, // Reduced from 28
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -1,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1), // Reduced from 2
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? selectedColor : unselectedColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _orderNeedsAction(OrderModel order) {
    final status = order.status.toLowerCase();
    return status == 'paid' || status == 'pending_handover';
  }
}
