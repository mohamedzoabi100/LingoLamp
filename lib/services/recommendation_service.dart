import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> addRecommendation({
    required String term,
    required String context,
    String source = 'chat',
  }) async {
    final now = DateTime.now();
    final rec = RecommendedFlashcard(
      term: term,
      context: context,
      source: source,
      weight: 1.0,
      createdAt: now,
      updatedAt: now,
    );
    await _db.addRecommendation(rec);
  }

  Future<void> removeRecommendation(int id) async {
    await _db.removeRecommendation(id);
  }

  Future<void> dismissRecommendation(int id) async {
    await _db.dismissRecommendation(id);
  }

  Future<List<RecommendedFlashcard>> getRecommendations() async {
    return await _db.getRecommendations();
  }
} 