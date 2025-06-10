//lib/screens/auth/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _debugInfo;

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle();
      
      if (result != null && mounted) {
        // Success - AuthStateWrapper will automatically navigate to MainAppPage
        print('Sign-up successful! AuthStateWrapper will handle navigation.');
        
        // FIXED: Clear entire navigation stack so AuthStateWrapper can properly show MainAppPage
        // This handles both guest mode navigation and regular navigation properly
        Navigator.of(context).popUntil((route) => route.isFirst);
        
      } else {
        // User cancelled sign-up - just stay on this screen
        print('Google Sign-Up was cancelled by user');
        if (mounted) {
          setState(() {
            _debugInfo = 'Sign-up was cancelled by user';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign-up was cancelled'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in SignUpScreen: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _debugInfo = 'Firebase Auth Error: ${e.code} - ${e.message}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Auth Error: ${e.message ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('General error in SignUpScreen: $e');
      if (mounted) {
        setState(() {
          _debugInfo = 'General error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There was an error logging into the app'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0E7A71);
    
    return Scaffold(
      backgroundColor: primaryTeal,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: 2),
                
                // App Logo
                Image.asset(
                  'assets/images/Logo.png', 
                  height: MediaQuery.of(context).size.height * 0.15,
                ),
                const SizedBox(height: 24.0),
                
                // Welcome Text
                const Text(
                  'Join LingoLamp',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'Create your account to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 60.0),
                
                // Google Sign Up Button
                Container(
                  height: 56.0,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryTeal),
                            ),
                          )
                        : Image.asset(
                            'assets/images/google_logo.png',
                            height: 24,
                            width: 24,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.person_add, color: primaryTeal),
                          ),
                    label: Text(
                      _isLoading ? 'Creating account...' : 'Continue with Google',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryTeal,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.0),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20.0),
                
                // Sign In Button
                Container(
                  height: 56.0,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SignInScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.0),
                      ),
                    ),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Debug info (only show in debug mode)
                if (kDebugMode && _debugInfo != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug: $_debugInfo',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}