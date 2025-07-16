import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/user_data_service.dart';
import '../../services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_providers.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error, guest }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.standard();
  final SyncService _syncService = SyncService();
  
  User? _currentUser;
  AuthState _authState = AuthState.initial;
  String? _errorMessage;
  
  // Getters
  User? get currentUser => _currentUser;
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => _authState == AuthState.guest;
  bool get isLoading => _authState == AuthState.loading;
  
  AuthProvider() {
    _listenToAuthChanges();
  }
  
  void _listenToAuthChanges() {
    _auth.authStateChanges().listen((User? user) async {
      _currentUser = user;
      if (user != null) {
        _authState = AuthState.authenticated;
        _errorMessage = null;
        
        // Initialize sync service and pull data from cloud
        await _syncService.initialize();
        await _syncService.pullFromCloud();
        
      } else {
        _authState = AuthState.unauthenticated;
      }
      notifyListeners();
    });
  }

  // Guest mode methods
  void enterGuestMode() {
    _authState = AuthState.guest;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void exitGuestMode() {
    _authState = AuthState.unauthenticated;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
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
      
      // Auth state will be updated by the listener, which will trigger sync
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

      // Push any pending changes to cloud before signing out
      if (isAuthenticated) {
        await _syncService.pushToCloud();
      }

      // Clear all user data before signing out
      await UserDataService().clearAllUserData();

      await _googleSignIn.signOut();
      await _auth.signOut();

      // Auth state will be updated by the listener
    } catch (e) {
      _handleAuthError(e);
    }
  }

  // Method to clear provider states (called from UI when needed)
  static void clearProviderStates(BuildContext context) {
    AppProviders.clearAllProviderStates(context);
  }

  Future<void> deleteAccount() async {
    try {
      _authState = AuthState.loading;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');

      print('🗑️ Starting account deletion process...');

      // Step 1: Clear all user data from cloud and local storage
      print('📱 Clearing all user data...');
      await _syncService.clearAllUserData();
      print('✅ User data cleared successfully');

      // Step 2: Verify data deletion
      print('🔍 Verifying data deletion...');
      final deletionVerified = await _syncService.verifyDataDeletion();
      if (!deletionVerified) {
        print('⚠️ Warning: Some data may not have been fully deleted');
      } else {
        print('✅ Data deletion verified successfully');
      }

      // Step 3: Delete user from Firebase Auth
      print('👤 Deleting Firebase Auth account...');
      await user.delete();
      print('✅ Firebase Auth account deleted');

      // Step 4: Sign out from Google
      print('🔓 Signing out from Google...');
      await _googleSignIn.signOut();
      print('✅ Google sign out completed');

      // Step 5: Clear local auth state
      _authState = AuthState.unauthenticated;
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();

      print('✅ Account deletion completed successfully');

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during account deletion: $e');
      
      // Handle specific Firebase Auth errors
      String errorMessage;
      switch (e.code) {
        case 'requires-recent-login':
          errorMessage = 'For security reasons, please sign in again before deleting your account.';
          break;
        case 'user-not-found':
          errorMessage = 'User account not found.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;
        default:
          errorMessage = 'Failed to delete account: ${e.message}';
      }
      
      _authState = AuthState.error;
      _errorMessage = errorMessage;
      notifyListeners();
      
    } catch (e) {
      print('❌ General error during account deletion: $e');
      _authState = AuthState.error;
      _errorMessage = 'Failed to delete account: $e';
      notifyListeners();
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