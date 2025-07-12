import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'es'; // Spanish as default

  String _currentLanguage = _defaultLanguage;
  bool _isLoading = false;

  // Supported languages with their codes, names, and flags
  static const Map<String, Map<String, String>> supportedLanguages = {
    'es': {
      'name': 'Spanish',
      'flag': '🇪🇸',
      'code': 'es',
    },
    'fr': {
      'name': 'French',
      'flag': '🇫🇷',
      'code': 'fr',
    },
    'de': {
      'name': 'German',
      'flag': '🇩🇪',
      'code': 'de',
    },
    'it': {
      'name': 'Italian',
      'flag': '🇮🇹',
      'code': 'it',
    },
    'pt': {
      'name': 'Portuguese',
      'flag': '🇵🇹',
      'code': 'pt',
    },
  };

  // Getters
  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;
  String get currentLanguageName => supportedLanguages[_currentLanguage]?['name'] ?? 'Unknown';
  String get currentLanguageFlag => supportedLanguages[_currentLanguage]?['flag'] ?? '🏳️';

  // Initialize provider
  Future<void> initialize() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      if (savedLanguage != null && supportedLanguages.containsKey(savedLanguage)) {
        _currentLanguage = savedLanguage;
      }
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Set language
  Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      debugPrint('Unsupported language code: $languageCode');
      return;
    }

    if (_currentLanguage == languageCode) return;

    _currentLanguage = languageCode;
    notifyListeners();

    // Save to preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  // Get language name by code
  static String getLanguageName(String languageCode) {
    return supportedLanguages[languageCode]?['name'] ?? 'Unknown';
  }

  // Get language flag by code
  static String getLanguageFlag(String languageCode) {
    return supportedLanguages[languageCode]?['flag'] ?? '🏳️';
  }

  // Get all supported languages
  static List<MapEntry<String, Map<String, String>>> getSupportedLanguages() {
    return supportedLanguages.entries.toList();
  }

  // State setters
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 