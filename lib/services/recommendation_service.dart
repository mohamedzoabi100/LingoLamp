import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import '../core/providers/language_provider.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> addRecommendation({
    required String term,
    required String context,
    String source = 'chat',
    required String languageCode,
  }) async {
    // If this is a new translation event, remove from dismissed
    await _db.removeDismissedRecommendation(term);
    final now = DateTime.now();
    final rec = RecommendedFlashcard(
      term: term,
      context: context,
      source: source,
      weight: 1.0,
      createdAt: now,
      updatedAt: now,
      languageCode: languageCode,
    );
    await _db.addRecommendation(rec);
  }

  Future<void> removeRecommendation(int id) async {
    await _db.removeRecommendation(id);
  }

  Future<void> dismissRecommendation(int id, {required String languageCode}) async {
    // Get the term for this recommendation
    final recs = await getRecommendations(languageCode: languageCode);
    RecommendedFlashcard? rec;
    for (final r in recs) {
      if (r.id == id) {
        rec = r;
        break;
      }
    }
    if (rec != null) {
      await _db.addDismissedRecommendation(rec.term);
    }
    await _db.dismissRecommendation(id);
  }

  Future<List<RecommendedFlashcard>> getRecommendations({required String languageCode}) async {
    return await _db.getRecommendationsByLanguage(languageCode);
  }
} 