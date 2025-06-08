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
        // Pop the sign-up screen so AuthStateWrapper can properly show MainAppPage
        Navigator.of(context).pop();
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
            content: Text('Firebase Auth Error: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Unexpected error in SignUpScreen: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _debugInfo = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Welcome text
              const Text(
                'Create Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign up to get started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),

              // Google Sign Up button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signUpWithGoogle,
                icon: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      )
                    : const Icon(Icons.g_mobiledata, color: Colors.red),
                label: Text(_isLoading ? 'Signing up...' : 'Sign up with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Debug information section
              if (kDebugMode) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Info:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Platform: ${defaultTargetPlatform.name}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Running in Debug Mode',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (_debugInfo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last Error: $_debugInfo',
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Troubleshooting:\n• If using Android x86 emulator, try a real device\n• Make sure Google Play Services is installed\n• Check internet connection',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Sign in navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 