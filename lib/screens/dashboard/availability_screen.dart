import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/availability.dart';
import '../../services/services.dart';

const _weekdayNames = {
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Edit weekly working hours and minimum booking notice. This is what the
/// public booking page uses to generate open slots.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  Availability? _availability;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await db.publicProfile(auth.currentUser!.uid);
    setState(() =>
        _availability = profile?.availability ?? Availability.defaults());
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await db.saveAvailability(auth.currentUser!.uid, _availability!);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved.')),
      );
      context.pop();
    }
  }

  Future<void> _pickTime(int weekday, bool isStart) async {
    final day = _availability!.dayFor(weekday);
    final current = isStart ? day.startMinutes : day.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      final days = Map<int, DayHours>.from(_availability!.days);
      days[weekday] = isStart
          ? day.copyWith(startMinutes: minutes)
          : day.copyWith(endMinutes: minutes);
      _availability = _availability!.copyWith(days: days);
    });
  }

  String _fmt(int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return t.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final a = _availability;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              onPressed: a == null || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: a == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Expanded(
                                child: Text('Minimum notice before a booking')),
                            DropdownButton<int>(
                              value: a.minNoticeHours,
                              items: const [0, 2, 6, 12, 24, 48, 72]
                                  .map((h) => DropdownMenuItem(
                                        value: h,
                                        child: Text(h == 0 ? 'None' : '$h h'),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _availability =
                                  a.copyWith(minNoticeHours: v ?? 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var d = 1; d <= 7; d++) _dayRow(d, a.dayFor(d)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _dayRow(int weekday, DayHours day) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(_weekdayNames[weekday]!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Switch(
              value: day.enabled,
              onChanged: (v) => setState(() {
                final days = Map<int, DayHours>.from(_availability!.days);
                days[weekday] = day.copyWith(enabled: v);
                _availability = _availability!.copyWith(days: days);
              }),
            ),
            const Spacer(),
            if (day.enabled) ...[
              TextButton(
                onPressed: () => _pickTime(weekday, true),
                child: Text(_fmt(day.startMinutes)),
              ),
              const Text('–'),
              TextButton(
                onPressed: () => _pickTime(weekday, false),
                child: Text(_fmt(day.endMinutes)),
              ),
            ] else
              Text('Closed',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
