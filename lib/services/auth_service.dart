import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Clear any existing sign-in state
      await _googleSignIn.signOut();

      print('Attempting to sign in with Google...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      print('Google user signed in successfully:  {googleUser.email}');
      print('Display name:  {googleUser.displayName}');
      print('Getting authentication details...');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('ID token:  {googleAuth.idToken != null ? "Present ( {googleAuth.idToken!.substring(0, 20)}...)" : "Missing"}');

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get authentication ID token from Google.');
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      print('Authenticating with Firebase...');
      final UserCredential result = await _auth.signInWithCredential(credential);

      print('Firebase sign-in successful!');
      print('User:  {result.user?.email}');
      print('Display name:  {result.user?.displayName}');
      print('User ID:  {result.user?.uid}');

      return result;
    } on FirebaseAuthException catch (e) {
      // Handle network-specific errors
      if (e.code == 'network-request-failed') {
        throw Exception('Network error: Please check your internet connection and try again.');
      } else if (e.code == 'invalid-credential') {
        throw Exception('Authentication failed: Invalid credentials. This might be due to emulator limitations with Google Play Services.');
      }
      rethrow;
    } on PlatformException catch (e) {
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
      if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
        throw Exception('Connection timeout. Please check your internet connection and try again. If using an emulator, consider testing on a real device.');
      }
      if (e.toString().contains('Google Play Services') || e.toString().contains('emulator')) {
        throw Exception('Google Play Services issue detected. Android x86 emulators have limited Google Play Services support. Please test on a real device or use an ARM64 emulator with Google Play.');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
} 