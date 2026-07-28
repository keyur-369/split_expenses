import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // disabled
import 'services/group_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'storage/storage_service.dart';
import 'screens/group_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp();

    debugPrint('⚠️ App Check is DISABLED - Users can login now');
    debugPrint('⚠️ Re-enable App Check after configuring Firebase Console');

    firebaseReady = true;
  } catch (e) {
    firebaseError = e.toString();
    // Firebase not configured yet - app will still work locally (without login)
    debugPrint('Firebase initialization error: $e');
    debugPrint('Please set up Firebase to use authentication');
  }

  // Initialize push notifications in a SEPARATE task.
  // This ensures a MissingPluginException or network delay/hang
  // never prevents the app from starting up.
  if (firebaseReady) {
    NotificationService.initialize().catchError((e) {
      debugPrint('⚠️ Push notification init failed: $e');
    });
  }

  // Initialize storage
  final storageService = StorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        if (firebaseReady) ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => GroupService()),
      ],
      child: MyApp(firebaseReady: firebaseReady, firebaseError: firebaseError),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const MyApp({super.key, required this.firebaseReady, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Split Expenses',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      home: SplashScreen(
        firebaseReady: firebaseReady,
        firebaseError: firebaseError,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final bool firebaseReady;
  final String? firebaseError;

  const AuthWrapper({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      // Firebase not initialized: show a friendly message
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Firebase not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  firebaseError ??
                      'Please add Firebase config files and retry.',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // If user is authenticated but email not verified, show verify screen
        if (user != null && !user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // If user is authenticated and verified, show app
        if (user != null) {
          return const GroupListScreen();
        }

        // Otherwise, show login screen
        return const LoginScreen();
      },
    );
  }
}
