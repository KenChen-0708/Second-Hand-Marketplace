import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/home/home_page.dart';
import 'features/home/product_detail_page.dart';
import 'features/sell/sell_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/my_account_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/settings_page.dart';
import 'features/profile/my_listings_page.dart';
import 'features/profile/seller_dashboard_page.dart';
import 'features/cart/cart_page.dart';
import 'features/checkout/checkout_page.dart';
import 'features/profile/order_status_page.dart';
import 'features/profile/order_history_page.dart';

import 'shared/widgets/scaffold_with_nav_bar.dart';

import 'features/admin/admin_login_page.dart';
import 'features/admin/admin_scaffold.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_user_management_page.dart';
import 'features/admin/admin_listing_moderation_page.dart';
import 'features/admin/admin_order_management_page.dart';
import 'features/admin/admin_notification_center_page.dart';

void main() {
  runApp(const MyApp());
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final _shellNavigatorSellKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellSell',
);
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

final _shellNavigatorAdminDashboardKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminDashboard',
);
final _shellNavigatorAdminUsersKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminUsers',
);
final _shellNavigatorAdminListingsKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminListings',
);
final _shellNavigatorAdminOrdersKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminOrders',
);
final _shellNavigatorAdminNotificationsKey = GlobalKey<NavigatorState>(
  debugLabel: 'adminNotifications',
);

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/', // Start at Login
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/cart',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CartPage(),
    ),
    GoRoute(
      path: '/checkout',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CheckoutPage(),
    ),
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AdminScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAdminDashboardKey,
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) => const AdminDashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAdminUsersKey,
          routes: [
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const AdminUserManagementPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAdminListingsKey,
          routes: [
            GoRoute(
              path: '/admin/listings',
              builder: (context, state) => const AdminListingModerationPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAdminOrdersKey,
          routes: [
            GoRoute(
              path: '/admin/orders',
              builder: (context, state) => const AdminOrderManagementPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAdminNotificationsKey,
          routes: [
            GoRoute(
              path: '/admin/notifications',
              builder: (context, state) => const AdminNotificationCenterPage(),
            ),
          ],
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'product/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ProductDetailPage(productId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorSellKey,
          routes: [
            GoRoute(
              path: '/sell',
              builder: (context, state) => const SellPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
              routes: [
                GoRoute(
                  path: 'account',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const MyAccountPage(),
                ),
                GoRoute(
                  path: 'notifications',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const NotificationsPage(),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SettingsPage(),
                ),
                GoRoute(
                  path: 'listings',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const MyListingsPage(),
                ),
                GoRoute(
                  path: 'dashboard',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SellerDashboardPage(),
                ),
                GoRoute(
                  path: 'order-status',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const OrderStatusPage(),
                ),
                GoRoute(
                  path: 'orders',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const OrderHistoryPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // "Clean-tech" aesthetic (Emerald Green and crisp whites)
    const primaryColor = Color(0xFF10B981); // Emerald Green
    const scaffoldBgColor = Color(0xFFF9FAFB); // Crisp off-white
    const surfaceColor = Colors.white; // Pure white for cards

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Campus Marketplace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              surface: surfaceColor,
              brightness: Brightness.light,
              primaryContainer: primaryColor.withValues(alpha: 0.1),
              onPrimaryContainer: primaryColor,
            ).copyWith(
              surface: surfaceColor,
              onSurface: const Color(0xFF1F2937), // Dark text (Gray 800)
              surfaceContainerHighest: const Color(
                0xFFF3F4F6,
              ), // Gray 100 for subtle fills
              outlineVariant: const Color(0xFFD1D5DB), // Gray 300 for borders
            ),
        scaffoldBackgroundColor: scaffoldBgColor,
        fontFamily: 'Roboto', // Modern sans-serif default or any injected
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ), // Gray 900
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
          bodyLarge: TextStyle(color: Color(0xFF374151)), // Gray 700
          bodyMedium: TextStyle(color: Color(0xFF4B5563)), // Gray 600
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F4F6), // Gray 100
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
