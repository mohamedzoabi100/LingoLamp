import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      print('Platform: Android ${defaultTargetPlatform.name}');
      
      // Check if Google Play services is available
      final bool isAvailable = await _googleSignIn.isSignedIn();
      print('Google Sign-In service check completed. Previously signed in: $isAvailable');
      
      // Clear any existing sign-in state
      await _googleSignIn.signOut();
      print('Cleared previous Google Sign-In state...');
      
      print('Attempting to sign in with Google...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In was cancelled by user or failed to complete');
        return null;
      }
      
      print('Google user signed in successfully: ${googleUser.email}');
      print('Display name: ${googleUser.displayName}');
      print('Getting authentication details...');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('Access token: ${googleAuth.accessToken != null ? "Present (${googleAuth.accessToken!.substring(0, 20)}...)" : "Missing"}');
      print('ID token: ${googleAuth.idToken != null ? "Present (${googleAuth.idToken!.substring(0, 20)}...)" : "Missing"}');
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('ERROR: Missing authentication tokens');
        throw Exception('Failed to get authentication tokens from Google. This might be due to Google Play Services issues on the emulator.');
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Authenticating with Firebase...');
      
      // Add timeout for Firebase authentication
      print('Starting Firebase authentication...');
      final UserCredential result = await _auth.signInWithCredential(credential);
      
      print('Firebase sign-in successful!');
      print('User: ${result.user?.email}');
      print('Display name: ${result.user?.displayName}');
      print('User ID: ${result.user?.uid}');
      
      return result;
      
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during Google Sign-In:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.toString()}');
      
      // Handle network-specific errors
      if (e.code == 'network-request-failed') {
        throw Exception('Network error: Please check your internet connection and try again.');
      } else if (e.code == 'invalid-credential') {
        throw Exception('Authentication failed: Invalid credentials. This might be due to emulator limitations with Google Play Services.');
      }
      
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException during Google Sign-In:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      
      // Handle specific Google Sign-In errors
      if (e.code == 'sign_in_failed') {
        throw Exception('Google Sign-In failed. On emulators, make sure you have Google Play Services installed and updated. Consider testing on a real device.');
      } else if (e.code == 'network_error') {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.code == 'sign_in_canceled') {
        throw Exception('Sign-in was cancelled.');
      } else if (e.code == 'sign_in_required') {
        throw Exception('Google Play Services sign-in required. This is common on emulators - try testing on a real device.');
      }
      
      rethrow;
    } catch (e, stackTrace) {
      print('Unexpected error during Google Sign-In: $e');
      print('Stack trace: $stackTrace');
      
      // Handle timeout errors
      if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
        throw Exception('Connection timeout. Please check your internet connection and try again. If using an emulator, consider testing on a real device.');
      }
      
      // Handle emulator-specific issues
      if (e.toString().contains('Google Play Services') || e.toString().contains('emulator')) {
        throw Exception('Google Play Services issue detected. Android x86 emulators have limited Google Play Services support. Please test on a real device or use an ARM64 emulator with Google Play.');
      }
      
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('Starting sign out process...');
      
      // Sign out from Google
      print('Signing out from Google Sign-In...');
      await _googleSignIn.signOut();
      print('Google Sign-In cleared');
      
      // Sign out from Firebase
      print('Signing out from Firebase...');
      await _auth.signOut();
      
      print('Sign out completed successfully');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
} 