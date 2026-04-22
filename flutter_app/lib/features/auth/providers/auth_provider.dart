// Manages authentication state using Riverpod.
// The app watches authStateProvider — when the user logs in or out,
// the UI automatically rebuilds to show the right screen.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_client.dart';

// Watches Firebase auth state — rebuilds UI on login/logout
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Holds the current user's data from our PostgreSQL backend
final currentUserProvider = FutureProvider.autoDispose((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  final api = ref.read(apiClientProvider);
  try {
    final response = await api.post('/auth/me');
    return response.data as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
});

// Auth service — handles sign in and sign out actions
final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final _googleSignIn = GoogleSignIn();

  AuthService(Ref ref);

  /// Signs in with Google.
  /// Returns null on success, error message on failure.
  Future<String?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Sign-in dibatalkan'; // user dismissed the dialog
      }

      // Get the auth credentials
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign into Firebase with those credentials
      await FirebaseAuth.instance.signInWithCredential(credential);
      return null; // null = success
    } catch (e) {
      return 'Sign-in gagal: $e';
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([
      FirebaseAuth.instance.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}