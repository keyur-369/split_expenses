import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // REGISTER: create auth user + Firestore user + send verification
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final normalizedEmail = email.trim().toLowerCase();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      // Create Firestore user doc
      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': normalizedEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await cred.user!.sendEmailVerification();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Registration failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // LOGIN: email & password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      try {
        final normalizedEmail = email.trim().toLowerCase();
        final cred = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );

        // emailVerified is cached on the client; after the user taps the link in
        // their inbox, we must reload from the server before checking.
        await cred.user?.reload();
        final userAfterReload = _auth.currentUser;
        if (userAfterReload == null) {
          _errorMessage = 'Login failed. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // If not verified, keep user signed in so AuthWrapper can show VerifyEmailScreen
        if (!userAfterReload.emailVerified) {
          _errorMessage = 'Please verify your email first.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } on FirebaseAuthException catch (e) {
        // Firebase may return newer unified credential errors
        // (for example: invalid-credential / invalid-login-credentials).
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'invalid-login-credentials') {
          _errorMessage = 'Invalid email or password.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'The email address is badly formatted.';
        } else if (e.code == 'user-disabled') {
          _errorMessage = 'This account has been disabled.';
        } else {
          _errorMessage = e.message ?? 'Authentication failed.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Save FCM token to Firestore for this device
      await NotificationService.saveTokenToFirestore();

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Login failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // LOGIN / REGISTER WITH GOOGLE
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in dialog
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Ensure user document exists in Firestore
        final userDocRef = _db.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'name': user.displayName ?? googleUser.displayName ?? 'Google User',
            'email': user.email?.toLowerCase() ?? googleUser.email.toLowerCase(),
            'photoUrl': user.photoURL ?? googleUser.photoUrl,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          await userDocRef.set({
            'name': user.displayName ?? googleUser.displayName ?? 'Google User',
            'email': user.email?.toLowerCase() ?? googleUser.email.toLowerCase(),
            if (user.photoURL != null || googleUser.photoUrl != null)
              'photoUrl': user.photoURL ?? googleUser.photoUrl,
          }, SetOptions(merge: true));
        }

        await NotificationService.saveTokenToFirestore();

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Google sign in failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      _errorMessage = e.message ?? 'Google Sign-In failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('Google Sign-In Error: $e\n$stack');
      _errorMessage = 'Google Sign-In failed. Check SHA-1 key in Firebase Console.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Remove FCM token so this device stops receiving notifications after logout
    await NotificationService.removeTokenFromFirestore();
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
