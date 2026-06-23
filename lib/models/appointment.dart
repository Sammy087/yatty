import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, confirmed, cancelled }

AppointmentStatus _statusFrom(String? s) => AppointmentStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AppointmentStatus.pending,
    );

/// The publicly-readable part of a booking: just enough to compute availability
/// (which slots are taken) without exposing any customer PII. PII lives in the
/// `private/details` subcollection, readable only by the owning artist.
class Appointment {
  final String id;
  final String artistId;
  final String formId;
  final DateTime start;
  final DateTime end;
  final AppointmentStatus status;
  final DateTime? createdAt;

  const Appointment({
    required this.id,
    required this.artistId,
    required this.formId,
    required this.start,
    required this.end,
    required this.status,
    this.createdAt,
  });

  bool get isActive => status != AppointmentStatus.cancelled;

  Map<String, dynamic> toMap() => {
        'artistId': artistId,
        'formId': formId,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'status': status.name,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Appointment(
      id: doc.id,
      artistId: data['artistId'] as String? ?? '',
      formId: data['formId'] as String? ?? '',
      start: (data['start'] as Timestamp).toDate(),
      end: (data['end'] as Timestamp).toDate(),
      status: _statusFrom(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Customer PII for an appointment, stored at appointments/{id}/private/details.
class AppointmentDetails {
  final String customerName;
  final String customerEmail;
  final String customerPhone;

  /// Answers to the form's custom fields, keyed by field id. Also carries a
  /// `__label__<fieldId>` entry so the artist can render labels without the form.
  final Map<String, String> responses;

  const AppointmentDetails({
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.responses,
  });

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'responses': responses,
      };

  factory AppointmentDetails.fromMap(Map<String, dynamic>? map) =>
      AppointmentDetails(
        customerName: map?['customerName'] as String? ?? '',
        customerEmail: map?['customerEmail'] as String? ?? '',
        customerPhone: map?['customerPhone'] as String? ?? '',
        responses: (map?['responses'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            {},
      );
}

/// The AI design consult result, written by Cloud Functions to
/// appointments/{id}/private/design. Read by the owning artist.
class DesignBrief {
  final String summary;
  final String placement;
  final String style;
  final String size;
  final String colors;

  /// Storage paths (not URLs) — resolve with FirebaseStorage.ref(path).
  final String? conceptPath;
  final List<String> referencePaths;

  const DesignBrief({
    required this.summary,
    required this.placement,
    required this.style,
    required this.size,
    required this.colors,
    required this.conceptPath,
    required this.referencePaths,
  });

  bool get isEmpty =>
      summary.isEmpty &&
      placement.isEmpty &&
      style.isEmpty &&
      conceptPath == null &&
      referencePaths.isEmpty;

  factory DesignBrief.fromMap(Map<String, dynamic> map) => DesignBrief(
        summary: map['summary'] as String? ?? '',
        placement: map['placement'] as String? ?? '',
        style: map['style'] as String? ?? '',
        size: map['size'] as String? ?? '',
        colors: map['colors'] as String? ?? '',
        conceptPath: map['conceptPath'] as String?,
        referencePaths: (map['referencePaths'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
