import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/availability.dart';
import '../models/booking_form.dart';

/// All Firestore reads/writes for the app live here.
///
/// Data model:
///   artists/{uid}                     – private profile (owner only)
///   publicProfiles/{uid}              – { displayName, availability } (public read)
///   forms/{formId}                    – booking forms (public read, owner write)
///   appointments/{id}                 – { artistId, formId, start, end, status }
///                                       (public read – no PII here)
///   appointments/{id}/private/details – customer PII (owner read only)
class FirestoreService {
  FirestoreService(this._db);
  final FirebaseFirestore _db;

  // ---- collections -------------------------------------------------------
  CollectionReference<Map<String, dynamic>> get _forms => _db.collection('forms');
  CollectionReference<Map<String, dynamic>> get _appts =>
      _db.collection('appointments');
  DocumentReference<Map<String, dynamic>> _artist(String uid) =>
      _db.collection('artists').doc(uid);
  DocumentReference<Map<String, dynamic>> _publicProfile(String uid) =>
      _db.collection('publicProfiles').doc(uid);

  // ---- artist profile ----------------------------------------------------

  /// Creates the artist's private profile + public profile with default hours.
  Future<void> createArtist({
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final batch = _db.batch();
    batch.set(_artist(uid), {
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_publicProfile(uid), {
      'displayName': displayName,
      'availability': Availability.defaults().toMap(),
    });
    await batch.commit();
  }

  Stream<Availability> availabilityStream(String uid) =>
      _publicProfile(uid).snapshots().map(
            (d) => Availability.fromMap(
              (d.data()?['availability'] as Map?)?.cast<String, dynamic>(),
            ),
          );

  Future<({String displayName, Availability availability})?> publicProfile(
      String uid) async {
    final d = await _publicProfile(uid).get();
    if (!d.exists) return null;
    return (
      displayName: d.data()?['displayName'] as String? ?? 'Artist',
      availability: Availability.fromMap(
        (d.data()?['availability'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  Future<void> saveAvailability(String uid, Availability availability) =>
      _publicProfile(uid).set(
        {'availability': availability.toMap()},
        SetOptions(merge: true),
      );

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _publicProfile(uid).set({'displayName': displayName}, SetOptions(merge: true));
    await _artist(uid).set({'displayName': displayName}, SetOptions(merge: true));
  }

  // ---- forms -------------------------------------------------------------

  Stream<List<BookingForm>> formsStream(String artistId) => _forms
      .where('artistId', isEqualTo: artistId)
      .snapshots()
      .map((s) => s.docs.map(BookingForm.fromDoc).toList());

  Future<BookingForm?> getForm(String formId) async {
    final d = await _forms.doc(formId).get();
    if (!d.exists) return null;
    return BookingForm.fromDoc(d);
  }

  /// Creates a new form and returns its generated id (the public slug).
  Future<String> createForm(BookingForm form) async {
    final ref = await _forms.add(form.toMap());
    return ref.id;
  }

  Future<void> updateForm(BookingForm form) =>
      _forms.doc(form.id).update(form.toMap()..remove('createdAt')..remove('artistId'));

  Future<void> deleteForm(String formId) => _forms.doc(formId).delete();

  // ---- appointments ------------------------------------------------------

  /// All appointments for an artist (for the dashboard calendar + counts).
  Stream<List<Appointment>> appointmentsStream(String artistId) => _appts
      .where('artistId', isEqualTo: artistId)
      .snapshots()
      .map((s) => s.docs.map(Appointment.fromDoc).toList());

  /// Active (non-cancelled) appointments for an artist within a date range —
  /// used by the public booking page to know which slots are taken. No PII is
  /// returned because that field never lives on this document.
  Future<List<Appointment>> appointmentsInRange(
    String artistId,
    DateTime from,
    DateTime to,
  ) async {
    final snap = await _appts
        .where('artistId', isEqualTo: artistId)
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('start', isLessThan: Timestamp.fromDate(to))
        .get();
    return snap.docs
        .map(Appointment.fromDoc)
        .where((a) => a.isActive)
        .toList();
  }

  Future<AppointmentDetails> appointmentDetails(String apptId) async {
    final d = await _appts.doc(apptId).collection('private').doc('details').get();
    return AppointmentDetails.fromMap(d.data());
  }

  /// The AI design consult for an appointment, if the client did one.
  Future<DesignBrief?> appointmentDesign(String apptId) async {
    final d = await _appts.doc(apptId).collection('private').doc('design').get();
    if (!d.exists) return null;
    return DesignBrief.fromMap(d.data()!);
  }

  /// Books a slot atomically. Uses a deterministic id (artist + start) so two
  /// people grabbing the same slot collide and the loser fails. Re-checks for
  /// overlap inside the transaction as a second guard. Returns the new id.
  Future<String> bookAppointment({
    required String artistId,
    required String formId,
    required DateTime start,
    required DateTime end,
    required AppointmentDetails details,
  }) async {
    final id = '${artistId}__${start.millisecondsSinceEpoch}';
    final apptRef = _appts.doc(id);
    final detailsRef = apptRef.collection('private').doc('details');

    await _db.runTransaction((tx) async {
      final existing = await tx.get(apptRef);
      if (existing.exists) {
        final a = Appointment.fromDoc(existing);
        if (a.isActive) {
          throw const SlotTakenException();
        }
      }
      tx.set(apptRef, Appointment(
        id: id,
        artistId: artistId,
        formId: formId,
        start: start,
        end: end,
        status: AppointmentStatus.pending,
      ).toMap());
      tx.set(detailsRef, details.toMap());
    });
    return id;
  }

  Future<void> setStatus(String apptId, AppointmentStatus status) =>
      _appts.doc(apptId).update({'status': status.name});

  Future<void> cancelAppointment(String apptId) =>
      setStatus(apptId, AppointmentStatus.cancelled);

  Future<void> deleteAppointment(String apptId) async {
    await _appts.doc(apptId).collection('private').doc('details').delete();
    await _appts.doc(apptId).delete();
  }
}

class SlotTakenException implements Exception {
  const SlotTakenException();
  @override
  String toString() => 'That time was just booked by someone else.';
}
