import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ai_service.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

/// App-wide service singletons. Initialised once in main() after Firebase is up.
late final FirestoreService db;
late final AuthService auth;
late final AiService ai;

void initServices() {
  db = FirestoreService(FirebaseFirestore.instance);
  auth = AuthService(FirebaseAuth.instance, db);
  ai = AiService(FirebaseFunctions.instanceFor(region: 'us-central1'));
}
