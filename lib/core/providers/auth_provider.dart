import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.standard();
  
  User? _currentUser;
  AuthState _authState = AuthState.initial;
  String? _errorMessage;
  
  // Getters
  User? get currentUser => _currentUser;
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _authState == AuthState.loading;
  
  AuthProvider() {
    _listenToAuthChanges();
  }
  
  void _listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _authState = AuthState.authenticated;
        _errorMessage = null;
      } else {
        _authState = AuthState.unauthenticated;
      }
      notifyListeners();
    });
  }
  
  Future<void> signInWithGoogle() async {
    try {
      _authState = AuthState.loading;
      _errorMessage = null;
      notifyListeners();
      
      // Clear any existing sign-in state
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get authentication ID token from Google');
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      
      await _auth.signInWithCredential(credential);
      
      // Auth state will be updated by the listener
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleAuthError(e);
    }
  }
  
  Future<void> signOut() async {
    try {
      _authState = AuthState.loading;
      notifyListeners();

      // Clear all user data before signing out
      await UserDataService().clearAllUserData();

      await _googleSignIn.signOut();
      await _auth.signOut();

      // Auth state will be updated by the listener
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      _authState = AuthState.loading;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');

      // Delete user data from Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(user.uid).delete();

      // Delete user from Firebase Auth
      await user.delete();

      // Clear all user data locally
      await UserDataService().clearAllUserData();

      // Sign out (should be redundant, but ensures state is reset)
      await _auth.signOut();

      _authState = AuthState.unauthenticated;
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }
  
  void _handleAuthError(dynamic error) {
    print('[AuthProvider] Error: $error');
    _authState = AuthState.error;
    _errorMessage = error.toString();
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = null;
    if (_authState == AuthState.error) {
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }
} 