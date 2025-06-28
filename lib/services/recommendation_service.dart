import 'dart:async';
import 'dart:math';
import 'package:rxdart/rxdart.dart';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import 'phrase_service.dart';
import '../models/chat_message_model.dart';
import 'dart:convert';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final PhraseService _phraseService = PhraseService();

  StreamSubscription? _subscription;

  // Simple English stop-word list; extend per language as needed
  static const Set<String> _stopWords = {
    'the','a','an','and','or','of','to','for','in','on','at','with','is','are','was','were','be','been','am',
    'i','you','he','she','it','we','they','this','that','these','those','my','your','his','her','their','our',
    // noise from AI payload or template
    'tool','args','front','back','create_flashcard','flashcard','json','payload','spanish','english','translation'
  };

  Future<void> init() async {
    // Combine favorites stream + chat stream and run algorithm after small debounce
    _subscription = Rx.combineLatest2<List<dynamic>, List<dynamic>, int>(
      _phraseService.favoritePhrasesStream,
      _db.chatStream,
      (fav, chat) => DateTime.now().millisecondsSinceEpoch, // dummy value
    ).debounceTime(const Duration(seconds: 2)).listen((_) async {
      await _recalculateRecommendations();
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> _recalculateRecommendations() async {
    final favorites = _phraseService.getFavoritePhrases();
    final messages = await _db.chatStream.first;
    final flashcards = await _db.getAllFlashcards();
    final existingTerms = flashcards.map((c) => c.originalText.toLowerCase()).toSet();

    // Collect candidate tokens with frequency
    final Map<String, _TokenStats> stats = {};

    bool _looksEnglish(String s) => RegExp(r'^[A-Za-z]+$').hasMatch(s);

    void _addToken(String token, String context, String source) {
      final lower = token.toLowerCase();
      if (lower.length < 2 || !_looksEnglish(lower) || _stopWords.contains(lower) || existingTerms.contains(lower)) return;
      final entry = stats.putIfAbsent(lower, () => _TokenStats(token: lower));
      entry.count += 1;
      entry.context = context; // keep latest context snippet
      entry.source = source;
      entry.recentMillis = DateTime.now().millisecondsSinceEpoch; // simplified recency
    }

    // From favourites (use english side only for now)
    for (final p in favorites) {
      final tokens = p.english.split(RegExp(r'[^A-Za-zÀ-ÿ]+'));
      for (final t in tokens) {
        if (t.isNotEmpty) _addToken(t, p.english, 'favorite');
      }
    }

    // --- From chat messages (only JSON payload pairs) ---
    for (final ChatMessage m in messages) {
      final payloadMatches = RegExp(r'\u{200B}(.*?)\u{200C}', dotAll: true, unicode: true).allMatches(m.text);
      for (final pm in payloadMatches) {
        final jsonStr = pm.group(1);
        if (jsonStr == null) continue;
        try {
          final data = json.decode(jsonStr);
          if (data is Map && data['tool'] == 'create_flashcard') {
            final args = data['args'];
            final front = args?['front'];
            final back = args?['back'];
            if (front is String && back is String) {
              _addToken(front, back, 'chat');
            }
          }
        } catch (_) {
          // ignore JSON parsing issues
        }
      }
    }

    // Convert to RecommendedFlashcard and persist
    final now = DateTime.now();
    for (final s in stats.values) {
      final weight = s.count * _recencyFactor(s.recentMillis);
      final rec = RecommendedFlashcard(
        term: s.token,
        context: s.context,
        source: s.source,
        weight: weight,
        createdAt: now,
        updatedAt: now,
      );
      await _db.upsertRecommendedFlashcard(rec);
    }

    // Delete obsolete recommendations (Spanish leftovers)
    final existingRecs = await _db.getAllRecommendedFlashcards();
    for (final r in existingRecs) {
      if (!stats.containsKey(r.term.toLowerCase())) {
        await _db.deleteRecommended(r.id!);
      }
    }
  }

  double _recencyFactor(int millis) {
    final hours = max(1, (DateTime.now().millisecondsSinceEpoch - millis) / (1000 * 60 * 60));
    return 1 / hours; // recent items get higher score
  }
}

class _TokenStats {
  final String token;
  int count = 0;
  late String context;
  late String source;
  int recentMillis = 0;
  _TokenStats({required this.token});
} 