//lib/services/phrase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PhraseModel {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;

  PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
  });

  factory PhraseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PhraseModel(
      id: doc.id,
      english: data['english'] ?? '',
      spanish: data['spanish'] ?? '',
      category: data['category'] ?? '',
      difficulty: data['difficulty'] ?? 'beginner',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'english': english,
      'spanish': spanish,
      'category': category,
      'difficulty': difficulty,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'phrases';

  // Get phrases by category
  Stream<List<PhraseModel>> getPhrasesForCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhraseModel.fromFirestore(doc))
            .toList()
            ..sort((a, b) => a.english.compareTo(b.english))); // Sort in app
  }

  // Get all phrases for search
  Stream<List<PhraseModel>> getAllPhrases() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhraseModel.fromFirestore(doc))
            .toList()
            ..sort((a, b) => a.category.compareTo(b.category))); // Sort by category first
  }

  // Search phrases
  Stream<List<PhraseModel>> searchPhrases(String query) {
    if (query.isEmpty) return Stream.value([]);
    
    return getAllPhrases().map((phrases) => phrases
        .where((phrase) =>
            phrase.english.toLowerCase().contains(query.toLowerCase()) ||
            phrase.spanish.toLowerCase().contains(query.toLowerCase()))
        .toList()
        ..sort((a, b) => a.english.compareTo(b.english))); // Sort results alphabetically
  }

  // Add a new phrase (for admin use)
  Future<void> addPhrase(PhraseModel phrase) async {
    await _firestore.collection(_collection).add(phrase.toFirestore());
  }

  // Initialize with sample data (run once)
  Future<void> initializeSampleData() async {
    final samplePhrases = [
      // Food & Dining
      PhraseModel(id: '', english: 'I would like to order', spanish: 'Me gustaría pedir', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'The menu, please', spanish: 'La carta, por favor', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'What do you recommend?', spanish: '¿Qué me recomienda?', category: 'Food & Dining', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I am vegetarian', spanish: 'Soy vegetariano/a', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'The bill, please', spanish: 'La cuenta, por favor', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Is this spicy?', spanish: '¿Está picante?', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I am allergic to...', spanish: 'Soy alérgico/a a...', category: 'Food & Dining', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'More water, please', spanish: 'Más agua, por favor', category: 'Food & Dining', difficulty: 'beginner', createdAt: DateTime.now()),

      // Transport
      PhraseModel(id: '', english: 'Where is the bus station?', spanish: '¿Dónde está la estación de autobús?', category: 'Transport', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'How much is a ticket?', spanish: '¿Cuánto cuesta un boleto?', category: 'Transport', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I need to go to...', spanish: 'Necesito ir a...', category: 'Transport', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Is this the right bus?', spanish: '¿Es este el autobús correcto?', category: 'Transport', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Please stop here', spanish: 'Pare aquí, por favor', category: 'Transport', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Call a taxi, please', spanish: 'Llame un taxi, por favor', category: 'Transport', difficulty: 'beginner', createdAt: DateTime.now()),

      // Emergencies
      PhraseModel(id: '', english: 'Help!', spanish: '¡Ayuda!', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Call the police', spanish: 'Llame a la policía', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I need a doctor', spanish: 'Necesito un médico', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Where is the hospital?', spanish: '¿Dónde está el hospital?', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I am lost', spanish: 'Estoy perdido/a', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Call an ambulance', spanish: 'Llame una ambulancia', category: 'Emergencies', difficulty: 'intermediate', createdAt: DateTime.now()),

      // Greetings
      PhraseModel(id: '', english: 'Hello', spanish: 'Hola', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Good morning', spanish: 'Buenos días', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Good afternoon', spanish: 'Buenas tardes', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Good night', spanish: 'Buenas noches', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Please', spanish: 'Por favor', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Thank you', spanish: 'Gracias', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Excuse me', spanish: 'Disculpe', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'See you later', spanish: 'Hasta luego', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),

      // Shopping
      PhraseModel(id: '', english: 'How much does this cost?', spanish: '¿Cuánto cuesta esto?', category: 'Shopping', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Do you accept credit cards?', spanish: '¿Aceptan tarjetas de crédito?', category: 'Shopping', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Can I try this on?', spanish: '¿Me lo puedo probar?', category: 'Shopping', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Do you have this in another size?', spanish: '¿Tienen esto en otra talla?', category: 'Shopping', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'I am just looking', spanish: 'Solo estoy mirando', category: 'Shopping', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Where is the cashier?', spanish: '¿Dónde está la caja?', category: 'Shopping', difficulty: 'beginner', createdAt: DateTime.now()),

      // Accommodation
      PhraseModel(id: '', english: 'I have a reservation', spanish: 'Tengo una reservación', category: 'Accommodation', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Do you have available rooms?', spanish: '¿Tienen habitaciones disponibles?', category: 'Accommodation', difficulty: 'intermediate', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'What time is check-out?', spanish: '¿A qué hora es el check-out?', category: 'Accommodation', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Can I have extra towels?', spanish: '¿Puedo tener toallas extra?', category: 'Accommodation', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'The Wi-Fi password, please', spanish: 'La contraseña del Wi-Fi, por favor', category: 'Accommodation', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Where is the elevator?', spanish: '¿Dónde está el ascensor?', category: 'Accommodation', difficulty: 'beginner', createdAt: DateTime.now()),
    ];

    // Check if data already exists
    final snapshot = await _firestore.collection(_collection).limit(1).get();
    if (snapshot.docs.isEmpty) {
      // Add sample data
      for (var phrase in samplePhrases) {
        await addPhrase(phrase);
      }
      print('Sample phrases added to Firestore');
    } else {
      print('Phrases already exist in Firestore');
    }
  }
}