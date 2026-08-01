import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final ApiService _apiService = ApiService();

  User? _user;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Completes once the initial Firebase auth state (and matching backend
  /// profile, if signed in) has been resolved. Splash screen awaits this
  /// instead of assuming auth state is known synchronously at construction.
  Future<void> get ready => _readyCompleter.future;

  User? get user => _user;
  bool get isAuthenticated => _firebaseAuth.currentUser != null && _user != null;
  bool get isAdmin => _user?.role == 'admin';
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  AuthService() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(fb.User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
    } else {
      await _loadUser();
    }
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await _loadUser();
    notifyListeners();
  }

  /// Re-reads the Firebase user's `emailVerified` flag from the server
  /// (client-side `currentUser.emailVerified` is only refreshed on demand).
  Future<void> reloadFirebaseUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
    } catch (e) {
      log('Reload user error: $e');
    }
    notifyListeners();
  }

  Future<void> _loadUser() async {
    try {
      final response = await _apiService.get('/users/profile/');
      _user = User.fromJson(response);
    } catch (e) {
      log('Error loading user: $e');
      _user = null;
    }
  }

  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(username);
      await credential.user?.sendEmailVerification();
      return {'success': true};
    } on fb.FirebaseAuthException catch (e) {
      log('Registration error: ${e.code}');
      return {'success': false, 'error': _friendlyAuthError(e)};
    } catch (e) {
      log('Registration error: $e');
      return {'success': false, 'error': 'Registration failed. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!(credential.user?.emailVerified ?? false)) {
        return {'success': false, 'email_not_verified': true};
      }

      await _loadUser();
      notifyListeners();
      return {'success': true};
    } on fb.FirebaseAuthException catch (e) {
      log('Login error: ${e.code}');
      return {'success': false, 'error': _friendlyAuthError(e)};
    } catch (e) {
      log('Login error: $e');
      return {'success': false, 'error': 'Login failed. Please try again.'};
    }
  }

  /// Resends the verification email to the currently signed-in (but
  /// unverified) Firebase user — there is no separate "resend by email"
  /// API without an authenticated session, matching Firebase's own model.
  Future<bool> resendVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
      return true;
    } catch (e) {
      log('Resend verification error: $e');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      log('Password reset error: ${e.code}');
      // Don't reveal account existence: only a malformed email is a real
      // client-side failure worth surfacing.
      return e.code != 'invalid-email';
    }
  }

  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      return {'success': false, 'error': 'You are not signed in.'};
    }

    try {
      final credential = fb.EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(newPassword);
      return {'success': true};
    } on fb.FirebaseAuthException catch (e) {
      log('Change password error: ${e.code}');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return {'success': false, 'error': 'Current password is incorrect.'};
      }
      return {'success': false, 'error': _friendlyAuthError(e)};
    }
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      return {'success': false, 'error': 'You are not signed in.'};
    }

    try {
      final credential = fb.EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: password,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      log('Reauthentication error: ${e.code}');
      return {'success': false, 'error': 'Incorrect password.'};
    }

    try {
      // Deletes the Django user record and the Firebase account (via the
      // Admin SDK) server-side.
      await _apiService.delete('/users/delete-account/');
    } catch (e) {
      log('Delete account error: $e');
      return {'success': false, 'error': 'Failed to delete account. Please try again.'};
    }

    await _firebaseAuth.signOut();
    _user = null;
    notifyListeners();
    return {'success': true};
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  String _friendlyAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger one.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
