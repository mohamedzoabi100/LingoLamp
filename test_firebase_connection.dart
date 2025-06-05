import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _status = 'Testing Firebase connection...';

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
  }

  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        _status = 'Testing Firebase connection...';
      });

      // Test 1: Check if Firebase is initialized
      final app = Firebase.app();
      print('Firebase app: ${app.name}');
      
      setState(() {
        _status = 'Firebase initialized ✓\nTesting Auth service...';
      });

      // Test 2: Try to access Firebase Auth
      final auth = FirebaseAuth.instance;
      print('Firebase Auth instance: $auth');
      
      setState(() {
        _status = 'Firebase initialized ✓\nAuth service accessible ✓\nTesting network...';
      });

      // Test 3: Try a simple operation that requires network
      await auth.fetchSignInMethodsForEmail('test@example.com');
      
      setState(() {
        _status = 'Firebase initialized ✓\nAuth service accessible ✓\nNetwork connection ✓\nReady to test registration!';
      });

    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      print('Firebase connection test failed: $e');
    }
  }

  Future<void> _testRegistration() async {
    try {
      setState(() {
        _status = 'Testing user registration...';
      });

      final auth = FirebaseAuth.instance;
      final credential = await auth.createUserWithEmailAndPassword(
        email: 'test${DateTime.now().millisecondsSinceEpoch}@test.com',
        password: 'testpassword123',
      );

      setState(() {
        _status = 'Registration successful! ✓\nUser: ${credential.user?.email}';
      });

      // Clean up - delete the test user
      await credential.user?.delete();

    } catch (e) {
      setState(() {
        _status = 'Registration failed: $e';
      });
      print('Registration test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Connection Test'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testFirebaseConnection,
              child: Text('Test Connection'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _testRegistration,
              child: Text('Test Registration'),
            ),
          ],
        ),
      ),
    );
  }
} 