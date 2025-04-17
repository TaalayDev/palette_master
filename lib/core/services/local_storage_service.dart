import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the LocalStorageService
final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Service to handle local storage operations
class LocalStorageService {
  SharedPreferences? _prefs;

  /// Initialize shared preferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save a setting
  Future<bool> setSetting(String key, String value) async {
    try {
      await _initPrefs();
      return await _prefs!.setString(key, value);
    } catch (e) {
      debugPrint('Error saving setting: $e');
      return false;
    }
  }

  /// Get a setting
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    try {
      await _initPrefs();
      return _prefs!.getString(key) ?? defaultValue;
    } catch (e) {
      debugPrint('Error getting setting: $e');
      return defaultValue;
    }
  }

  /// Save game progress
  Future<bool> saveGameProgress(String puzzleId, int level) async {
    try {
      await _initPrefs();
      final key = 'progress_${puzzleId}';
      return await _prefs!.setInt(key, level);
    } catch (e) {
      debugPrint('Error saving game progress: $e');
      return false;
    }
  }

  /// Get game progress
  Future<int> getGameProgress(String puzzleId, {int defaultLevel = 1}) async {
    try {
      await _initPrefs();
      final key = 'progress_${puzzleId}';
      return _prefs!.getInt(key) ?? defaultLevel;
    } catch (e) {
      debugPrint('Error getting game progress: $e');
      return defaultLevel;
    }
  }

  /// Save achievement status
  Future<bool> saveAchievement(String achievementId, bool isCompleted) async {
    try {
      await _initPrefs();
      final key = 'achievement_${achievementId}';
      return await _prefs!.setBool(key, isCompleted);
    } catch (e) {
      debugPrint('Error saving achievement: $e');
      return false;
    }
  }

  /// Get achievement status
  Future<bool> getAchievement(String achievementId) async {
    try {
      await _initPrefs();
      final key = 'achievement_${achievementId}';
      return _prefs!.getBool(key) ?? false;
    } catch (e) {
      debugPrint('Error getting achievement: $e');
      return false;
    }
  }

  /// Save user score
  Future<bool> saveScore(int score) async {
    try {
      await _initPrefs();
      return await _prefs!.setInt('user_score', score);
    } catch (e) {
      debugPrint('Error saving score: $e');
      return false;
    }
  }

  /// Get user score
  Future<int> getScore() async {
    try {
      await _initPrefs();
      return _prefs!.getInt('user_score') ?? 0;
    } catch (e) {
      debugPrint('Error getting score: $e');
      return 0;
    }
  }

  /// Save high score
  Future<bool> saveHighScore(String gameType, int score) async {
    try {
      await _initPrefs();
      final key = 'highscore_${gameType}';
      final currentHighScore = await getHighScore(gameType);

      // Only save if the new score is higher
      if (score > currentHighScore) {
        return await _prefs!.setInt(key, score);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving high score: $e');
      return false;
    }
  }

  /// Get high score
  Future<int> getHighScore(String gameType) async {
    try {
      await _initPrefs();
      final key = 'highscore_${gameType}';
      return _prefs!.getInt(key) ?? 0;
    } catch (e) {
      debugPrint('Error getting high score: $e');
      return 0;
    }
  }

  /// Save last played level
  Future<bool> saveLastPlayedLevel(String gameType, int level) async {
    try {
      await _initPrefs();
      final key = 'lastlevel_${gameType}';
      return await _prefs!.setInt(key, level);
    } catch (e) {
      debugPrint('Error saving last played level: $e');
      return false;
    }
  }

  /// Get last played level
  Future<int> getLastPlayedLevel(String gameType) async {
    try {
      await _initPrefs();
      final key = 'lastlevel_${gameType}';
      return _prefs!.getInt(key) ?? 1;
    } catch (e) {
      debugPrint('Error getting last played level: $e');
      return 1;
    }
  }

  /// Save tutorial status
  Future<bool> setTutorialComplete(String tutorialId, bool isComplete) async {
    try {
      await _initPrefs();
      final key = 'tutorial_${tutorialId}';
      return await _prefs!.setBool(key, isComplete);
    } catch (e) {
      debugPrint('Error saving tutorial status: $e');
      return false;
    }
  }

  /// Get tutorial status
  Future<bool> isTutorialComplete(String tutorialId) async {
    try {
      await _initPrefs();
      final key = 'tutorial_${tutorialId}';
      return _prefs!.getBool(key) ?? false;
    } catch (e) {
      debugPrint('Error getting tutorial status: $e');
      return false;
    }
  }

  /// Clear all saved data
  Future<bool> clearAll() async {
    try {
      await _initPrefs();
      return await _prefs!.clear();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
      return false;
    }
  }

  /// Save color accuracy record (for analytics)
  Future<bool> saveColorAccuracy(String colorId, double accuracy) async {
    try {
      await _initPrefs();
      final key = 'accuracy_${colorId}';
      return await _prefs!.setDouble(key, accuracy);
    } catch (e) {
      debugPrint('Error saving color accuracy: $e');
      return false;
    }
  }

  /// Get color accuracy record
  Future<double> getColorAccuracy(String colorId) async {
    try {
      await _initPrefs();
      final key = 'accuracy_${colorId}';
      return _prefs!.getDouble(key) ?? 0.0;
    } catch (e) {
      debugPrint('Error getting color accuracy: $e');
      return 0.0;
    }
  }
}
