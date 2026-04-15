import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminAuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? _user;
  bool _isAdmin = false;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  bool get isAdmin => _isAdmin;
  bool get loading => _loading;
  String? get error => _error;

  AdminAuthProvider() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? u) async {
    if (u == null) {
      _user = null;
      _isAdmin = false;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      await u.getIdToken(true);
      final snap = await _db.collection('adminUsers').doc(u.email).get();
      _isAdmin = snap.exists;
    } catch (_) {
      _isAdmin = false;
    }
    _user = u;
    _loading = false;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.code == 'invalid-credential'
          ? 'Incorrect email or password.'
          : e.message ?? 'Sign in failed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
