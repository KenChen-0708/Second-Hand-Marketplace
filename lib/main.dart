import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'state/state.dart';
import 'models/models.dart';

import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/home/home_page.dart';
import 'features/home/product_detail_page.dart';
import 'features/sell/sell_page.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/my_account_page.dart';
import 'features/profile/notifications_page.dart';
import 'features/profile/settings_page.dart';
import 'features/cart/cart_page.dart';
import 'features/checkout/checkout_page.dart';
import 'features/profile/order_detail_page.dart';
import 'features/profile/order_history_page.dart';
import 'features/profile/wishlist_page.dart';
import 'features/chat/chat_inbox_page.dart';
import 'features/chat/chat_room_page.dart';
import 'features/profile/seller_review_page.dart';
import 'features/profile/seller_profile_page.dart';
import 'features/sell/my_listings_page.dart';
import 'features/sell/edit_product_page.dart';
import 'features/sell/seller_dashboard_page.dart';

import 'shared/widgets/scaffold_with_nav_bar.dart';

import 'features/admin/admin_login_page.dart';
import 'features/admin/admin_scaffold.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_user_management_page.dart';
import 'features/admin/admin_listing_moderation_page.dart';
import 'features/admin/admin_order_management_page.dart';
import 'features/admin/admin_notification_center_page.dart';

const String supabaseUrl = 'https://yqvgeownycvbzelukmfp.supabase.co';
const String supabaseKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlxdmdlb3dueWN2YnplbHVrbWZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMzc2MjcsImV4cCI6MjA4NzgxMzYyN30.1OOTEJnPr7qXWLGdSUNmydvK6_UFSB38mkJbQnv1Qp0';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

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
  initialLocation: '/',
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
      path: '/messages',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ChatInboxPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.easeInOutCubic));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: '/chat/:id',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ChatRoomPage(conversationId: id),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: Curves.easeInOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/seller/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return SellerProfilePage(sellerId: id);
      },
    ),
    GoRoute(
      path: '/product/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProductDetailPage(productId: id);
      },
    ),
    GoRoute(
      path: '/edit-product',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final product = state.extra as ProductModel;
        return EditProductPage(product: product);
      },
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
              routes: const [],
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
                  path: 'wishlist',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const WishlistPage(),
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
                  builder: (context, state) =>
                      OrderStatusPage(order: state.extra),
                ),
                GoRoute(
                  path: 'orders',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const OrderHistoryPage(),
                ),
                GoRoute(
                  path: 'seller-review',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) =>
                      SellerReviewPage(product: state.extra as ProductModel?),
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
    const primaryColor = Color(0xFF10B981);
    const scaffoldBgColor = Color(0xFFF9FAFB);
    const surfaceColor = Colors.white;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserState()),
        ChangeNotifierProvider(create: (_) => CategoryState()),
        ChangeNotifierProvider(create: (_) => ProductState()),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider(create: (_) => OrderState()),
        ChangeNotifierProvider(create: (_) => PaymentState()),
        ChangeNotifierProvider(create: (_) => ChatConversationState()),
        ChangeNotifierProvider(create: (_) => ChatMessageState()),
        ChangeNotifierProvider(create: (_) => AppNotificationState()),
        ChangeNotifierProvider(create: (_) => ReviewState()),
        ChangeNotifierProvider(create: (_) => SellerProfileState()),
        ChangeNotifierProvider(create: (_) => FavoriteState()),
        ChangeNotifierProvider(create: (_) => DisputeState()),
        ChangeNotifierProvider(create: (_) => AdminLogState()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Campus Marketplace',
        routerConfig: _router,
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
                onSurface: const Color(0xFF1F2937),
                surfaceContainerHighest: const Color(0xFFF3F4F6),
                outlineVariant: const Color(0xFFD1D5DB),
              ),
          scaffoldBackgroundColor: scaffoldBgColor,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            headlineSmall: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            titleLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            bodyLarge: TextStyle(color: Color(0xFF374151)),
            bodyMedium: TextStyle(color: Color(0xFF4B5563)),
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
            fillColor: const Color(0xFFF3F4F6),
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
      ),
    );
  }
}
