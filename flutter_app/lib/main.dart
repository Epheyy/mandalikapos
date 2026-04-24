import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mandalika_pos/features/auth/screens/login_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/backoffice_shell.dart';
import 'package:mandalika_pos/features/backoffice/screens/customers_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/dashboard_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/orders_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/outlets_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/products_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/promotions_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/reports_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/settings_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/stock_count_screen.dart';
import 'package:mandalika_pos/features/backoffice/screens/users_screen.dart';
import 'package:mandalika_pos/features/cashier/screens/cashier_screen.dart';
import 'package:mandalika_pos/shared/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MandalikaApp()));
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLogin = state.matchedLocation == '/login';
      if (user == null) return isLogin ? null : '/login';
      if (isLogin) return '/';
      return null;
    },
    refreshListenable: _FirebaseAuthListenable(),
    routes: [
      GoRoute(
        path: '/login',
        builder: (ctx, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (ctx, _) => const CashierScreen(),
      ),
      ShellRoute(
        builder: (ctx, state, child) => BackOfficeShell(child: child),
        routes: [
          GoRoute(
            path: '/backoffice/dashboard',
            builder: (ctx, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/backoffice/orders',
            builder: (ctx, _) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/backoffice/products',
            builder: (ctx, _) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/backoffice/customers',
            builder: (ctx, _) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/backoffice/promotions',
            builder: (ctx, _) => const PromotionsScreen(),
          ),
          GoRoute(
            path: '/backoffice/reports',
            builder: (ctx, _) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/backoffice/settings',
            builder: (ctx, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/backoffice/stock-count',
            builder: (ctx, _) => const StockCountScreen(),
          ),
          GoRoute(
            path: '/backoffice/users',
            builder: (ctx, _) => const UsersScreen(),
          ),
          GoRoute(
            path: '/backoffice/outlets',
            builder: (ctx, _) => const OutletsScreen(),
          ),
        ],
      ),
    ],
  );
}

class _FirebaseAuthListenable extends ChangeNotifier {
  _FirebaseAuthListenable() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

class MandalikaApp extends ConsumerStatefulWidget {
  const MandalikaApp({super.key});

  @override
  ConsumerState<MandalikaApp> createState() => _MandalikaAppState();
}

class _MandalikaAppState extends ConsumerState<MandalikaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mandalika POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
