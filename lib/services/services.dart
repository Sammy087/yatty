import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'firestore_service.dart';

/// App-wide service singletons. Initialised once in main() after Firebase is up.
late final FirestoreService db;
late final AuthService auth;

void initServices() {
  db = FirestoreService(FirebaseFirestore.instance);
  auth = AuthService(FirebaseAuth.instance, db);
}
