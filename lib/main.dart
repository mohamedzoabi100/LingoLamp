import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

// Core
import 'core/app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize app services
  await InitializationService.initialize();
  
  runApp(const LingoLampApp());
}