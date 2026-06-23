import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

/// Thin wrapper around FirebaseAuth (email/password) for artist accounts.
/// Customers never authenticate.
class AuthService {
  AuthService(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirestoreService _db;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());
    await _db.createArtist(
      uid: user.uid,
      displayName: displayName.trim(),
      email: email.trim(),
    );
  }

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
