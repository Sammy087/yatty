import 'package:cloud_firestore/cloud_firestore.dart';

/// The kind of input a custom form field collects.
enum FieldType { text, multiline, number, choice }

FieldType _fieldTypeFromString(String? s) => FieldType.values.firstWhere(
      (t) => t.name == s,
      orElse: () => FieldType.text,
    );

/// A single artist-defined question on a booking form.
///
/// Contact basics (name, email, phone) are always collected separately, so
/// these are the *extra* questions an artist wants answered (placement, size,
/// reference notes, budget, etc.).
class FormFieldDef {
  final String id;
  final String label;
  final FieldType type;
  final bool required;

  /// Options for [FieldType.choice].
  final List<String> options;

  const FormFieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  FormFieldDef copyWith({
    String? label,
    FieldType? type,
    bool? required,
    List<String>? options,
  }) =>
      FormFieldDef(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'type': type.name,
        'required': required,
        'options': options,
      };

  factory FormFieldDef.fromMap(Map<String, dynamic> map) => FormFieldDef(
        id: map['id'] as String,
        label: map['label'] as String? ?? '',
        type: _fieldTypeFromString(map['type'] as String?),
        required: map['required'] as bool? ?? false,
        options:
            (map['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

/// A bookable form created by an artist. Its document id is the public slug used
/// in the share URL: /book/{id}.
class BookingForm {
  final String id;
  final String artistId;
  final String title;
  final String description;

  /// How long each appointment from this form lasts, in minutes.
  final int durationMinutes;

  /// Whether phone number is collected.
  final bool collectPhone;

  /// If false, the public page shows a "not accepting bookings" message.
  final bool active;

  final List<FormFieldDef> fields;
  final DateTime? createdAt;

  const BookingForm({
    required this.id,
    required this.artistId,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.collectPhone,
    required this.active,
    required this.fields,
    this.createdAt,
  });

  BookingForm copyWith({
    String? title,
    String? description,
    int? durationMinutes,
    bool? collectPhone,
    bool? active,
    List<FormFieldDef>? fields,
  }) =>
      BookingForm(
        id: id,
        artistId: artistId,
        title: title ?? this.title,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        collectPhone: collectPhone ?? this.collectPhone,
        active: active ?? this.active,
        fields: fields ?? this.fields,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'artistId': artistId,
        'title': title,
        'description': description,
        'durationMinutes': durationMinutes,
        'collectPhone': collectPhone,
        'active': active,
        'fields': fields.map((f) => f.toMap()).toList(),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      };

  factory BookingForm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BookingForm(
      id: doc.id,
      artistId: data['artistId'] as String? ?? '',
      title: data['title'] as String? ?? 'Booking',
      description: data['description'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      collectPhone: data['collectPhone'] as bool? ?? true,
      active: data['active'] as bool? ?? true,
      fields: (data['fields'] as List?)
              ?.map((e) =>
                  FormFieldDef.fromMap((e as Map).cast<String, dynamic>()))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// A blank form for the editor.
  factory BookingForm.empty(String artistId) => BookingForm(
        id: '',
        artistId: artistId,
        title: 'New tattoo booking',
        description: '',
        durationMinutes: 60,
        collectPhone: true,
        active: true,
        fields: const [],
      );
}
