import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import '../models/phrase_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './xp_event_tracker.dart';
import './user_data_service.dart';
import './daily_task_service.dart';
import '../models/daily_task_model.dart' as daily_task;
import '../core/providers/language_provider.dart';

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  List<PhraseModel> _csvPhrases = [];
  List<PhraseModel> _aiPhrases = [];
  Set<String> _favoriteIds = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool get _isAuthenticated => _auth.currentUser != null;

  final _phrasesSubject = BehaviorSubject<List<PhraseModel>>.seeded([]);
  final _favoritesSubject = BehaviorSubject<List<PhraseModel>>.seeded([]);
  
  Stream<List<PhraseModel>> get allPhrasesStream => _phrasesSubject.stream;
  Stream<List<PhraseModel>> get favoritePhrasesStream => _favoritesSubject.stream;

  String _currentLanguage = 'es';

  Future<void> init({String? languageCode}) async {
    _currentLanguage = languageCode ?? _currentLanguage;
    await _loadCsvPhrases(_currentLanguage);
    await _loadFavorites(_currentLanguage);
    await _loadAiPhrases(_currentLanguage);
    _updateStreams();
  }

  // NEW: Method to reinitialize with a new language
  Future<void> reinitializeWithLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      await _loadCsvPhrases(_currentLanguage);
      await _loadFavorites(_currentLanguage);
      await _loadAiPhrases(_currentLanguage);
      _updateStreams();
    }
  }

  void dispose() {
    _phrasesSubject.close();
    _favoritesSubject.close();
  }

  void _updateStreams() {
    final allPhrases = [..._csvPhrases, ..._aiPhrases];
    final phrasesWithFavorites = allPhrases.map((p) => p.copyWith(isFavorite: _favoriteIds.contains(p.id))).toList();
    _phrasesSubject.add(phrasesWithFavorites);
    _favoritesSubject.add(phrasesWithFavorites.where((p) => p.isFavorite).toList());
  }

  Future<void> _loadCsvPhrases(String languageCode) async {
    try {
      final csvPath = 'assets/data/phrases_$languageCode.csv';
      debugPrint("🔄 [PHRASE] Loading CSV from: $csvPath");
      
      final csvString = await rootBundle.loadString(csvPath);
      debugPrint("✅ [PHRASE] Successfully loaded CSV for $languageCode");
      
      final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
      debugPrint("📊 [PHRASE] Found ${lines.length} lines in CSV");
      
      if (lines.length < 2) {
        debugPrint("⚠️ [PHRASE] CSV file has insufficient data for $languageCode");
        _csvPhrases = [];
        return;
      }
      
      _csvPhrases = lines.skip(1).map((line) {
        final parts = line.split(',');
        if (parts.length < 4) {
          debugPrint("⚠️ [PHRASE] Invalid line format: $line");
          return null;
        }
        
        final english = parts[0].trim();
        final translation = parts[1].trim();
        final category = parts[2].trim();
        final difficulty = parts[3].trim();
        
        return PhraseModel(
          id: 'csv_${english.hashCode}_${category.hashCode}_$languageCode',
          english: english,
          translation: translation,
          category: category,
          difficulty: difficulty,
          createdAt: DateTime.now(),
          languageCode: languageCode,
        );
      }).where((p) => p != null).cast<PhraseModel>().toList();
      
      debugPrint("✅ [PHRASE] Loaded ${_csvPhrases.length} phrases for $languageCode");
      
    } catch (e) {
      debugPrint("❌ [PHRASE] Error loading CSV for $languageCode: $e");
      debugPrint("💡 [PHRASE] Make sure the file 'assets/data/phrases_$languageCode.csv' exists");
      _csvPhrases = [];
    }
  }
  
  Future<void> _loadFavorites(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_favorite_phrases_$languageCode' : 'guest_favorite_phrases_$languageCode';
    _favoriteIds = (prefs.getStringList(key) ?? []).toSet();
  }

  Future<void> _saveFavorites(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_favorite_phrases_$languageCode' : 'guest_favorite_phrases_$languageCode';
    await prefs.setStringList(key, _favoriteIds.toList());
    if (_isAuthenticated) {
      await prefs.setBool('favorites_need_sync', true);
    }
  }

  Future<void> _loadAiPhrases(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_ai_phrases_$languageCode' : 'guest_ai_phrases_$languageCode';
    final jsonList = prefs.getStringList(key) ?? [];
    _aiPhrases = jsonList.map((json) => PhraseModel.fromJson(jsonDecode(json))).toList();
  }

  Future<void> _saveAiPhrases(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_ai_phrases_$languageCode' : 'guest_ai_phrases_$languageCode';
    final jsonList = _aiPhrases.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(key, jsonList);
    if (_isAuthenticated) {
      await prefs.setBool('ai_phrases_need_sync', true);
    }
  }

  Future<void> toggleFavorite(String phraseId, String languageCode) async {
    if (_favoriteIds.contains(phraseId)) {
      _favoriteIds.remove(phraseId);
    } else {
      _favoriteIds.add(phraseId);
      // Award XP only when adding to favourites
      final xpTracker = XPEventTracker();
      xpTracker.addXP(XPEventTracker.favoriteAdded, 'Phrase added to favourites');
      // Update daily task progress for learning phrases
      final dailyTaskService = DailyTaskService();
      await dailyTaskService.updateTaskProgress(daily_task.TaskType.learnPhrases, 1, languageCode: languageCode);
    }
    await _saveFavorites(languageCode);
    _updateStreams();
  }

  Future<void> addAiPhrase(PhraseModel phrase) async {
    _aiPhrases.removeWhere((p) => p.id == phrase.id);
    _aiPhrases.add(phrase);
    await _saveAiPhrases(phrase.languageCode);
    _updateStreams();
  }
  
  Future<void> updateAiPhrasesFromSync(List<String> aiPhrasesJson) async {
    _aiPhrases = aiPhrasesJson.map((json) => PhraseModel.fromJson(jsonDecode(json))).toList();
    _updateStreams();
  }

  Future<void> forceRefreshFromDisk() async {
      await _loadFavorites(_currentLanguage);
    await _loadAiPhrases(_currentLanguage);
    _updateStreams();
  }

  List<PhraseModel> getFavoritePhrases() {
    return _phrasesSubject.value.where((p) => p.isFavorite).toList();
  }
}