import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';

class UserProfileService {
  static UserProfileService? _instance;
  static UserProfileService get instance => _instance ??= UserProfileService._();
  
  UserProfileService._();

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  Future<void> initializeCurrentUser() async {
    try {
      final profile = await loadUserProfile();
      if (profile != null) {
        _currentUser = profile;
        debugPrint(' User profile loaded: ${profile.nickname}');
      } else {
        // Create default profile
        _currentUser = UserProfile(
          id: 'default_user',
          username: 'user',
          nickname: 'User',
          email: 'user@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await saveUserProfile(_currentUser!);
        debugPrint(' Default user profile created');
      }
    } catch (e) {
      debugPrint(' Error initializing user profile: $e');
      _currentUser = UserProfile(
        id: 'default_user',
        username: 'user',
        nickname: 'User',
        email: 'user@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Future<File> _getUserProfileFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/user_profile.json');
  }

  Future<UserProfile?> loadUserProfile() async {
    try {
      final file = await _getUserProfileFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        return UserProfile.fromMap(data);
      }
    } catch (e) {
      debugPrint(' Error loading user profile: $e');
    }
    return null;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final file = await _getUserProfileFile();
      await file.writeAsString(jsonEncode(profile.toMap()));
      _currentUser = profile;
      debugPrint(' User profile saved: ${profile.nickname}');
    } catch (e) {
      debugPrint(' Error saving user profile: $e');
    }
  }

  Future<void> updateUserNickname(String nickname) async {
    if (_currentUser != null) {
      final updatedProfile = _currentUser!.copyWith(
        nickname: nickname,
        updatedAt: DateTime.now(),
      );
      await saveUserProfile(updatedProfile);
      debugPrint(' User nickname updated to: $nickname');
    }
  }

  Future<void> updateUserEmail(String email) async {
    if (_currentUser != null) {
      final updatedProfile = _currentUser!.copyWith(
        email: email,
        updatedAt: DateTime.now(),
      );
      await saveUserProfile(updatedProfile);
      debugPrint(' User email updated to: $email');
    }
  }

  Future<void> updateUserUsername(String username) async {
    if (_currentUser != null) {
      final updatedProfile = _currentUser!.copyWith(
        username: username,
        updatedAt: DateTime.now(),
      );
      await saveUserProfile(updatedProfile);
      debugPrint(' User username updated to: $username');
    }
  }

  String get currentUserNickname => _currentUser?.nickname ?? 'User';
  String get currentUserUsername => _currentUser?.username ?? 'user';
  String get currentUserEmail => _currentUser?.email ?? 'user@example.com';
}
