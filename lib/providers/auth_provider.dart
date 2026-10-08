import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _nickname;
  String? _email;
  String? _photoURL;
  String? _userId;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  String? get nickname => _nickname;
  String? get email => _email;
  String? get photoURL => _photoURL;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  User? get currentUser => _auth.currentUser;

  AuthProvider() {
    _loadUser();
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      debugPrint(' Auth state changed: ${user?.email}');
      if (user != null) {
        _userId = user.uid;
        _email = user.email;
        _photoURL = user.photoURL;
        _nickname = user.displayName ?? user.email?.split('@')[0];
        _isAuthenticated = true;
        debugPrint(' User authenticated: $_email (ID: $_userId)');
      } else {
        _userId = null;
        _email = null;
        _nickname = null;
        _photoURL = null;
        _isAuthenticated = false;
        debugPrint(' User signed out');
      }
      notifyListeners();
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString('nickname');
    _email = prefs.getString('email');
    _photoURL = prefs.getString('photoURL');
    _userId = prefs.getString('userId');
    _isAuthenticated = _userId != null;
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _saveUserData(credential.user!);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign in error: ${e.message}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmail(String email, String password, String nickname) async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(nickname);

        // Create user document in Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'nickname': nickname,
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        await _saveUserData(credential.user!);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign up error: ${e.message}');

      // Handle specific error codes
      if (e.code == 'email-already-in-use') {
        debugPrint('Email already exists - user should sign in instead');
        return false;
      } else if (e.code == 'weak-password') {
        debugPrint('Password is too weak');
        return false;
      } else if (e.code == 'invalid-email') {
        debugPrint('Email format is invalid');
        return false;
      }

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('=== Starting Google Sign-In Process ===');

      // Configure Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: '48521747253-b2qkov3f9u397n4em41ji2ehdkdvo5ts.apps.googleusercontent.com',
      );

      debugPrint('Google Sign-In configured');

      // Attempt sign in
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint(' Google Sign-In cancelled by user');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugPrint('Google user signed in: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Check for tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('Google auth tokens are null');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugPrint('Got Google auth tokens');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('Creating Firebase credential...');
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        debugPrint('Firebase sign-in successful: ${userCredential.user!.email}');

        try {
          // Check if user exists in Firestore
          final userDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

          if (!userDoc.exists) {
            debugPrint('Creating new user document for Google user...');
            // Create new user document for first-time Google users
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid,
              'email': userCredential.user!.email,
              'nickname': userCredential.user!.displayName ?? userCredential.user!.email?.split('@')[0],
              'photoURL': userCredential.user!.photoURL,
              'createdAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'provider': 'google',
            });
          } else {
            debugPrint('Existing Google user found, updating login time...');
            // Update last login time for existing users
            await userDoc.reference.update({
              'lastLoginAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Firestore error (database may not be enabled): $e');
          debugPrint('User authenticated but Firestore operations failed');
          // Continue with local storage even if Firestore fails
        }

        await _saveUserData(userCredential.user!);
        debugPrint('Google user data saved successfully');
        return true;
      }
      return false;
    } on TypeError catch (e) {
      debugPrint('Type error in Google Sign-In: $e');
      debugPrint('This is a known compatibility issue - continuing with authentication...');

      // Try to get current user if authentication actually succeeded
      if (_auth.currentUser != null) {
        debugPrint('Authentication succeeded despite type error, saving user data...');
        await _saveUserData(_auth.currentUser!);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Show user-friendly error
      if (e.toString().contains('network')) {
        debugPrint('Network error - please check internet connection');
      } else if (e.toString().contains('12501')) {
        debugPrint('Google Play Services not available or outdated');
      } else if (e.toString().contains('sign_in_failed')) {
        debugPrint('Sign in failed - might need to reconfigure OAuth');
      } else if (e.toString().contains('sign_in_cancelled')) {
        debugPrint('Sign in cancelled by user');
      } else if (e.toString().contains('type')) {
        debugPrint('Type compatibility error - package version issue');
      }

      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _userId = null;
      _email = null;
      _nickname = null;
      _photoURL = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.uid);
    await prefs.setString('email', user.email ?? '');
    await prefs.setString('nickname', user.displayName ?? user.email?.split('@')[0] ?? '');
    await prefs.setString('photoURL', user.photoURL ?? '');
  }

  Future<void> updateNickname(String newNickname) async {
    try {
      await _auth.currentUser?.updateDisplayName(newNickname);

      if (_userId != null) {
        await _firestore.collection('users').doc(_userId).update({
          'nickname': newNickname,
        });
      }

      _nickname = newNickname;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', newNickname);
      notifyListeners();
    } catch (e) {
      debugPrint('Update nickname error: $e');
    }
  }

  Future<void> updatePhotoURL(String newPhotoURL) async {
    try {
      await _auth.currentUser?.updatePhotoURL(newPhotoURL);

      if (_userId != null) {
        await _firestore.collection('users').doc(_userId).update({
          'photoURL': newPhotoURL,
        });
      }

      _photoURL = newPhotoURL;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('photoURL', newPhotoURL);
      notifyListeners();
    } catch (e) {
      debugPrint('Update photo URL error: $e');
    }
  }
}