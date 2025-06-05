import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '65099514942-knb1nnu57oov6oalt5qt06ig7squr527.apps.googleusercontent.com',
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In process...');
      
      // Clear any existing sign-in state
      await _googleSignIn.signOut();
      print('Cleared previous Google Sign-In state...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In was cancelled by user');
        return null;
      }
      
      print('Google user signed in: ${googleUser.email}');
      print('Getting authentication details...');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print('Access token: ${googleAuth.accessToken != null ? "Present" : "Missing"}');
      print('ID token: ${googleAuth.idToken != null ? "Present" : "Missing"}');
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('ERROR: Missing authentication tokens');
        throw Exception('Failed to get authentication tokens from Google');
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Signing in with Firebase...');
      final UserCredential result = await _auth.signInWithCredential(credential);
      
      print('Firebase sign-in successful: ${result.user?.email}');
      return result;
      
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during Google Sign-In:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.toString()}');
      rethrow;
    } on PlatformException catch (e) {
      print('PlatformException during Google Sign-In:');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('Details: ${e.details}');
      
      // Handle specific Google Sign-In errors
      if (e.code == 'sign_in_failed') {
        throw Exception('Google Sign-In failed. Please make sure you have Google Play Services installed.');
      } else if (e.code == 'network_error') {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.code == 'sign_in_canceled') {
        throw Exception('Sign-in was cancelled.');
      }
      
      rethrow;
    } catch (e, stackTrace) {
      print('Unexpected error during Google Sign-In: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error registering: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      return await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Get error message from FirebaseAuthException
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
} 