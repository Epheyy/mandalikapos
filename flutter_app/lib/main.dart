import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/cashier/screens/cashier_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file before anything else
  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // ProviderScope is required by Riverpod — wrap the entire app
    const ProviderScope(
      child: MandalikaApp(),
    ),
  );
}

class MandalikaApp extends ConsumerWidget {
  const MandalikaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state — rebuilds when user logs in or out
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Mandalika POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: authState.when(
        // Still checking auth state — show splash
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold),
          ),
        ),
        // Auth check failed
        error: (_, __) => const LoginScreen(),
        data: (user) {
          // Not logged in → show login screen
          if (user == null) return const LoginScreen();
          // Logged in → show cashier screen
          return const CashierScreen();
        },
      ),
    );
  }
}