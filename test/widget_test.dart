// Basic sanity test. The full app requires Firebase initialisation, so here we
// just verify pure scheduling logic that has no Firebase dependency.
import 'package:flutter_test/flutter_test.dart';
import 'package:yatty/models/availability.dart';
import 'package:yatty/services/availability_service.dart';

void main() {
  test('open slots respect working hours and duration', () {
    final availability = Availability.defaults(); // Mon–Fri 9–5
    final monday = DateTime(2030, 1, 7); // 2030-01-07 is a Monday
    final slots = AvailabilityService.openSlots(
      day: monday,
      availability: availability,
      durationMinutes: 60,
      existing: const [],
      now: DateTime(2029, 12, 1),
    );
    // 9am–5pm with 60-min slots = 8 slots.
    expect(slots.length, 8);
    expect(slots.first.start.hour, 9);
    expect(slots.last.end.hour, 17);
  });

  test('weekends are closed by default', () {
    final slots = AvailabilityService.openSlots(
      day: DateTime(2030, 1, 12), // Saturday
      availability: Availability.defaults(),
      durationMinutes: 60,
      existing: const [],
      now: DateTime(2029, 12, 1),
    );
    expect(slots, isEmpty);
  });
}
