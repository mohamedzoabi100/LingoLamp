//lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADD THIS IMPORT
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/guest_home_page.dart'; 
import 'screens/main_app_page.dart';
import 'screens/auth/sign_in_screen.dart'; // Add this import
import 'services/user_data_service.dart';
import 'services/recommendation_service.dart';
import 'services/phrase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ADD THIS: Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
    
    // Load local CSV and saved phrases
    await PhraseService().init();
    
    // Initialize user data service auth listener
    UserDataService().setupAuthListener();
    // Start recommendation engine
    await RecommendationService().init();
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }
  
  runApp(const MyApp());
}

// Rest of your code remains exactly the same...
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0E7A71); 

    return MaterialApp(
      title: 'LingoLamp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: primaryTeal,

        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          surface: const Color.fromARGB(255, 255, 255, 255), 
          onSurface: Colors.black87, 
          primary: primaryTeal, 
          secondary: primaryTeal, 
        ),

        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 45, 
            color: primaryTeal,
          ),
          titleLarge: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.w600, 
            color: Colors.black87,
          ),
         
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            side: const BorderSide(color: Colors.white, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      home: const AuthStateWrapper(), 
    );
  }
}

// New authentication state wrapper
class AuthStateWrapper extends StatelessWidget {
  const AuthStateWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('🔄 AuthStateWrapper: Connection state: ${snapshot.connectionState}');
        print('🔄 AuthStateWrapper: Has data: ${snapshot.hasData}');
        print('🔄 AuthStateWrapper: Has error: ${snapshot.hasError}');
        print('🔄 AuthStateWrapper: User: ${snapshot.data?.email}');
        print('🔄 AuthStateWrapper: User ID: ${snapshot.data?.uid}');
        
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ AuthStateWrapper: Showing loading screen');
          return const Scaffold(
            backgroundColor: Color(0xFF0E7A71),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        // Handle errors
        if (snapshot.hasError) {
          print('❌ AuthStateWrapper: Error: ${snapshot.error}');
          return const Scaffold(
            backgroundColor: Color(0xFF0E7A71),
            body: Center(
              child: Text(
                'Authentication Error',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }
        
        // If user is logged in, go to main app
        if (snapshot.hasData && snapshot.data != null) {
          print('✅ AuthStateWrapper: User is logged in, showing MainAppPage');
          print('✅ User details: ${snapshot.data!.email} (${snapshot.data!.uid})');
          return const MainAppPage();
        }
        
        // If user is not logged in, show initial page
        print('❌ AuthStateWrapper: No user, showing InitialPage');
        return const InitialPage();
      },
    );
  }
}

//--- InitialPage and LoginScreenPlaceholder remain exactly the same ---
class InitialPage extends StatelessWidget {
  const InitialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: 2),
                Image.asset('assets/images/Logo.png', height: screenHeight * 0.2),
                const SizedBox(height: 16.0),
                const Text('LingoLamp', textAlign: TextAlign.center, style: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 255, 255))),
                const SizedBox(height: 60.0),
                OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInScreen())),
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GuestHomePage())),
                  child: const Text('Continue as guest'),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreenPlaceholder extends StatelessWidget {
  const LoginScreenPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), backgroundColor: Theme.of(context).primaryColor, foregroundColor: const Color.fromARGB(255, 255, 255, 255)),
      body: const Center(child: Text('Login Screen - Coming Soon!', style: TextStyle(fontSize: 24, color: Color.fromARGB(255, 255, 255, 255)))),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
    );
  }
}