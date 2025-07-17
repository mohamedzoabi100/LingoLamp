import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/xp_service.dart';
import '../../services/daily_task_service.dart';
import '../providers/language_provider.dart';

class InitializationService {
  static Future<void> initialize() async {
    try {
      print('🔄 Initializing app services...');
      
      // Initialize Hive for local storage
      await _initializeHive();
      
      // Initialize SharedPreferences
      await SharedPreferences.getInstance();
      
      // Initialize other services (don't fail if they don't work)
      await _initializeOtherServices();
      
      print('✅ All services initialized successfully');
    } catch (e) {
      print('❌ Service initialization failed: $e');
      // Continue app startup even if some services fail
    }
  }
  
  static Future<void> _initializeHive() async {
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);
      print('✅ Hive initialized successfully');
    } catch (e) {
      print('❌ Hive initialization failed: $e');
      // Continue without Hive if it fails
    }
  }
  
  static Future<void> _initializeOtherServices() async {
    // Initialize XP service and load data from Firestore for authenticated users
    try {
      await XPService().loadFromFirestore();
      print('✅ XP service initialized successfully');
    } catch (e) {
      print('❌ XP service initialization failed: $e');
      // Continue without XP service if it fails
    }
    
    // Initialize Daily Task service and load data from Firestore for authenticated users
    try {
      await DailyTaskService().loadFromFirestore();
      print('✅ Daily Task service initialized successfully');
    } catch (e) {
      print('❌ Daily Task service initialization failed: $e');
      // Continue without Daily Task service if it fails
    }
    
    // Initialize Language Provider
    try {
      final languageProvider = LanguageProvider();
      await languageProvider.initialize();
      print('✅ Language provider initialized successfully');
    } catch (e) {
      print('❌ Language provider initialization failed: $e');
      // Continue without Language provider if it fails
    }
    
    // Add a small delay to ensure everything is properly initialized
    await Future.delayed(const Duration(milliseconds: 200));
  }
} 