import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

        // If not verified, keep user signed in so AuthWrapper can show VerifyEmailScreen
        if (!cred.user!.emailVerified) {
          _errorMessage = 'Please verify your email first.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No account found for this email. Please register.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Incorrect password. Please try again.';
        } else {
          _errorMessage = e.message ?? 'Authentication failed.';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

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

  // Sign out
  Future<void> signOut() async {
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
