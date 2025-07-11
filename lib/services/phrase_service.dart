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

  Future<void> init() async {
    await _loadCsvPhrases();
      await _loadFavorites();
      await _loadAiPhrases();
    _updateStreams();
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

  Future<void> _loadCsvPhrases() async {
    try {
      final csvString = await rootBundle.loadString('assets/data/phrases.csv');
      final lines = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
      _csvPhrases = lines.skip(1).map((line) {
        final parts = line.split(',');
        final english = parts[0].trim();
        final category = parts[2].trim();
        return PhraseModel(
          id: 'csv_${english.hashCode}_${category.hashCode}',
          english: english,
          spanish: parts[1].trim(),
          category: category,
          difficulty: parts[3].trim(),
          createdAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint("Error loading CSV: $e");
    }
  }
  
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_favorite_phrases' : 'guest_favorite_phrases';
    _favoriteIds = (prefs.getStringList(key) ?? []).toSet();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_favorite_phrases' : 'guest_favorite_phrases';
    await prefs.setStringList(key, _favoriteIds.toList());
    if (_isAuthenticated) {
      await prefs.setBool('favorites_need_sync', true);
    }
  }

  Future<void> _loadAiPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_ai_phrases' : 'guest_ai_phrases';
    final jsonList = prefs.getStringList(key) ?? [];
    _aiPhrases = jsonList.map((json) => PhraseModel.fromJson(jsonDecode(json))).toList();
  }

  Future<void> _saveAiPhrases() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _isAuthenticated ? 'signed_in_ai_phrases' : 'guest_ai_phrases';
    final jsonList = _aiPhrases.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(key, jsonList);
    if (_isAuthenticated) {
      await prefs.setBool('ai_phrases_need_sync', true);
    }
  }

  Future<void> toggleFavorite(String phraseId) async {
    if (_favoriteIds.contains(phraseId)) {
      _favoriteIds.remove(phraseId);
      final aiPhrasesJson = _aiPhrases.map((p) => jsonEncode(p.toJson())).toList();
      await UserDataService().saveAiPhrasesLocally(aiPhrasesJson);
      UserDataService().scheduleAiPhrasesSync();
      debugPrint('[SYNC] AI phrases sync scheduled after remove');
    } else {
      _favoriteIds.add(phraseId);
      final aiPhrasesJson = _aiPhrases.map((p) => jsonEncode(p.toJson())).toList();
      await UserDataService().saveAiPhrasesLocally(aiPhrasesJson);
      UserDataService().scheduleAiPhrasesSync();
      debugPrint('[SYNC] AI phrases sync scheduled after add');
      // Award XP only when adding to favourites
      final xpTracker = XPEventTracker();
      xpTracker.addXP(XPEventTracker.favoriteAdded, 'Phrase added to favourites');
      
      // Update daily task progress for learning phrases
      final dailyTaskService = DailyTaskService();
      await dailyTaskService.updateTaskProgress(daily_task.TaskType.learnPhrases, 1);
    }
    await _saveFavorites();
    _updateStreams();
  }

  Future<void> addAiPhrase(PhraseModel phrase) async {
    _aiPhrases.removeWhere((p) => p.id == phrase.id);
    _aiPhrases.add(phrase);
    await _saveAiPhrases();
    final aiPhrasesJson = _aiPhrases.map((p) => jsonEncode(p.toJson())).toList();
    await UserDataService().saveAiPhrasesLocally(aiPhrasesJson);
    UserDataService().scheduleAiPhrasesSync();
    debugPrint('[SYNC] AI phrases sync scheduled after add');
    
    // Update daily task progress for learning phrases
    final dailyTaskService = DailyTaskService();
    await dailyTaskService.updateTaskProgress(daily_task.TaskType.learnPhrases, 1);
    
    _updateStreams();
  }
  
  Future<void> updateAiPhrasesFromSync(List<String> aiPhrasesJson) async {
    _aiPhrases = aiPhrasesJson.map((json) => PhraseModel.fromJson(jsonDecode(json))).toList();
    _updateStreams();
  }

  Future<void> forceRefreshFromDisk() async {
      await _loadFavorites();
    await _loadAiPhrases();
    _updateStreams();
  }

  List<PhraseModel> getFavoritePhrases() {
    return _phrasesSubject.value.where((p) => p.isFavorite).toList();
  }
}