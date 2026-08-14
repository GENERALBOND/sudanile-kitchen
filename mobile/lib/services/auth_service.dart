import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  // The Firebase session is the source of truth for authentication. The
  // backend profile (_user) is supplementary: if it fails to load we must NOT
  // demote a signed-in user to guest mode.
  bool get isAuthenticated => _firebaseAuth.currentUser != null;
  bool get isAdmin =>
      _user != null &&
      (_user!.role == 'admin' || _user!.isStaff || _user!.isSuperuser);
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;

  AuthService() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(fb.User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
    } else {
      // A different Firebase account may have signed in — drop any profile
      // cached for the previous account before (re)loading the new one.
      if (_user != null && _user!.email != firebaseUser.email) {
        _user = null;
      }
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
      // Keep the last known profile: the Firebase session is still valid, so
      // a transient backend error must not silently turn the user into a guest.
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

  /// Signs in with Google and links the resulting Firebase account to the
  /// backend Django user (created on first sign-in by the backend's
  /// `FirebaseAuthentication` class). Google accounts are verified by Google,
  /// so no email-verification gate applies.
  ///
  /// The OAuth client ID is set at build/run time via
  /// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (or `--dart-define-from-file=.env`).
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, Firebase Auth's popup flow provides the ID token directly,
        // so google_sign_in isn't used here.
        final provider = fb.GoogleAuthProvider();
        final result = await _firebaseAuth.signInWithPopup(provider);
        if (result.user == null) {
          return {'success': false, 'cancelled': true};
        }
      } else {
        const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
        final googleSignIn = GoogleSignIn(serverClientId: webClientId);

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          return {'success': false, 'cancelled': true};
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null) {
          return {
            'success': false,
            'error':
                'Google sign-in is missing the OAuth web client ID. Configure '
                    'GOOGLE_WEB_CLIENT_ID and try again.',
          };
        }

        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      }

      await _loadUser();
      notifyListeners();
      return {'success': true};
    } on fb.FirebaseAuthException catch (e) {
      log('Google sign-in error: ${e.code}');
      if (e.code == 'account-exists-with-different-credential') {
        return {
          'success': false,
          'error':
              'An account already exists with this email. Sign in with your '
                  'email and password instead.',
        };
      }
      return {'success': false, 'error': _friendlyAuthError(e)};
    } catch (e) {
      log('Google sign-in error: $e');
      return {
        'success': false,
        'error': 'Google sign-in failed: $e',
      };
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
    // On web the sign-in used Firebase Auth's popup, so there's no
    // google_sign_in session to clear; calling it there would re-init the
    // plugin without a clientId and throw, blocking the Firebase sign-out.
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        log('GoogleSignIn signOut error: $e');
      }
    }
    await _firebaseAuth.signOut();
    _user = null;
    notifyListeners();
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
