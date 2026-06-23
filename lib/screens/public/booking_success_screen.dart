import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ai_service.dart';
import '../../services/ics_service.dart';
import '../../services/services.dart';

/// Shown after a booking is created (and the design chat). Offers .ics /
/// Google Calendar add, plus an optional "generate template image" that turns
/// the client's chat into a concept the artist can see.
class BookingSuccessScreen extends StatefulWidget {
  const BookingSuccessScreen({
    super.key,
    required this.artistName,
    required this.title,
    required this.start,
    required this.end,
    required this.icsBuilder,
    required this.googleCalendarUrl,
    required this.appointmentId,
    required this.chatMessages,
    required this.referenceImages,
  });

  final String artistName;
  final String title;
  final DateTime start;
  final DateTime end;
  final String Function() icsBuilder;
  final String googleCalendarUrl;

  /// Data needed to generate a concept image from the consultation.
  final String appointmentId;
  final List<ChatTurn> chatMessages;
  final List<String> referenceImages;

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  bool _generating = false;
  Uint8List? _concept;
  String? _error;

  bool get _canGenerate =>
      widget.chatMessages.any((m) => m.role == 'user' && m.text.trim().isNotEmpty);

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await ai.generateConcept(
        appointmentId: widget.appointmentId,
        messages: widget.chatMessages,
        referenceImages: widget.referenceImages,
      );
      setState(() => _concept = base64Decode(result.imageBase64));
    } catch (e) {
      setState(() => _error =
          "Couldn't generate the image right now. Your notes are still saved "
          "for your artist.");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('EEEE, MMMM d • h:mm a').format(widget.start);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
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
                Text('with ${widget.artistName}',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(widget.title,
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
                      IcsService.download('appointment.ics', widget.icsBuilder()),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Add to my device calendar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => IcsService.openUrl(widget.googleCalendarUrl),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Add to Google Calendar'),
                ),

                if (_canGenerate) ...[
                  const Divider(height: 40),
                  Text(
                    'Want to preview your idea?',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate a concept image from what you described — your '
                    'artist will see it with your booking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 12),
                  if (_concept != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_concept!),
                    ),
                  if (_concept != null) const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_generating
                        ? 'Generating…'
                        : _concept == null
                            ? 'Generate template image'
                            : 'Regenerate'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  ],
                ],

                const SizedBox(height: 20),
                Text(
                  'Your artist has received your booking and it is on their '
                  'calendar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
