import '../models/appointment.dart';
import '../models/availability.dart';

/// A concrete open slot a customer can book.
class TimeSlot {
  final DateTime start;
  final DateTime end;
  const TimeSlot(this.start, this.end);
}

/// Pure scheduling logic: given an artist's weekly availability, an appointment
/// duration, and the appointments already on the books, work out which slots
/// are still open on a given day. This is what keeps the artist from being
/// double-booked.
class AvailabilityService {
  /// Open slots for [day] (a local date; time component ignored).
  ///
  /// [existing] should contain the artist's active appointments that touch
  /// [day]. [now] defaults to [DateTime.now] and is used together with
  /// [availability.minNoticeHours] to hide slots that are too soon.
  static List<TimeSlot> openSlots({
    required DateTime day,
    required Availability availability,
    required int durationMinutes,
    required List<Appointment> existing,
    DateTime? now,
  }) {
    final today = DateTime(day.year, day.month, day.day);
    final hours = availability.dayFor(today.weekday);
    if (!hours.enabled || durationMinutes <= 0) return const [];

    final clock = now ?? DateTime.now();
    final earliest = clock.add(Duration(hours: availability.minNoticeHours));

    final slots = <TimeSlot>[];
    for (var m = hours.startMinutes;
        m + durationMinutes <= hours.endMinutes;
        m += durationMinutes) {
      final start = today.add(Duration(minutes: m));
      final end = start.add(Duration(minutes: durationMinutes));
      if (start.isBefore(earliest)) continue;
      if (_overlapsAny(start, end, existing)) continue;
      slots.add(TimeSlot(start, end));
    }
    return slots;
  }

  static bool _overlapsAny(
      DateTime start, DateTime end, List<Appointment> existing) {
    for (final a in existing) {
      if (!a.isActive) continue;
      // Two intervals overlap iff each starts before the other ends.
      if (start.isBefore(a.end) && a.start.isBefore(end)) return true;
    }
    return false;
  }
}
