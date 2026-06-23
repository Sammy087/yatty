/// Working hours for a single weekday.
class DayHours {
  /// Whether the artist takes bookings on this weekday.
  final bool enabled;

  /// Minutes from midnight the day opens (e.g. 9 * 60 = 540 for 9:00 AM).
  final int startMinutes;

  /// Minutes from midnight the day closes (e.g. 17 * 60 = 1020 for 5:00 PM).
  final int endMinutes;

  const DayHours({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
  });

  DayHours copyWith({bool? enabled, int? startMinutes, int? endMinutes}) =>
      DayHours(
        enabled: enabled ?? this.enabled,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory DayHours.fromMap(Map<String, dynamic>? map) => DayHours(
        enabled: map?['enabled'] as bool? ?? false,
        startMinutes: (map?['startMinutes'] as num?)?.toInt() ?? 9 * 60,
        endMinutes: (map?['endMinutes'] as num?)?.toInt() ?? 17 * 60,
      );
}

/// An artist's weekly availability. Keyed by [DateTime.weekday] (1 = Mon … 7 = Sun).
class Availability {
  final Map<int, DayHours> days;

  /// Minimum hours of notice before a slot can be booked.
  final int minNoticeHours;

  const Availability({required this.days, this.minNoticeHours = 12});

  DayHours dayFor(int weekday) =>
      days[weekday] ??
      const DayHours(enabled: false, startMinutes: 9 * 60, endMinutes: 17 * 60);

  Availability copyWith({Map<int, DayHours>? days, int? minNoticeHours}) =>
      Availability(
        days: days ?? this.days,
        minNoticeHours: minNoticeHours ?? this.minNoticeHours,
      );

  /// A reasonable starting point: Mon–Fri, 9–5.
  factory Availability.defaults() => Availability(
        minNoticeHours: 12,
        days: {
          for (var d = 1; d <= 7; d++)
            d: DayHours(
              enabled: d >= 1 && d <= 5,
              startMinutes: 9 * 60,
              endMinutes: 17 * 60,
            ),
        },
      );

  Map<String, dynamic> toMap() => {
        'minNoticeHours': minNoticeHours,
        'days': {
          for (final entry in days.entries)
            entry.key.toString(): entry.value.toMap(),
        },
      };

  factory Availability.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Availability.defaults();
    final rawDays = (map['days'] as Map?) ?? {};
    return Availability(
      minNoticeHours: (map['minNoticeHours'] as num?)?.toInt() ?? 12,
      days: {
        for (var d = 1; d <= 7; d++)
          d: DayHours.fromMap(
            (rawDays[d.toString()] as Map?)?.cast<String, dynamic>(),
          ),
      },
    );
  }
}
