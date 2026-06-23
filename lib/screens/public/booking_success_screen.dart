import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ics_service.dart';

/// Shown after a successful booking. Offers the client an .ics download so they
/// can add the appointment to their own device calendar.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.artistName,
    required this.title,
    required this.start,
    required this.end,
    required this.icsBuilder,
  });

  final String artistName;
  final String title;
  final DateTime start;
  final DateTime end;
  final String Function() icsBuilder;

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('EEEE, MMMM d • h:mm a').format(start);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text("You're booked!",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'with $artistName',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(when, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      IcsService.download('appointment.ics', icsBuilder()),
                  icon: const Icon(Icons.event),
                  label: const Text('Add to my calendar'),
                ),
                const SizedBox(height: 8),
                Text(
                  'The artist has also received your booking and it is on their '
                  'calendar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
