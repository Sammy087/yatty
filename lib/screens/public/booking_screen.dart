import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../models/availability.dart';
import '../../models/booking_form.dart';
import '../../services/availability_service.dart';
import '../../services/firestore_service.dart';
import '../../services/ics_service.dart';
import '../../services/services.dart';
import 'booking_success_screen.dart';
import 'design_chat_screen.dart';

/// The public, no-login page a client opens from the shared link: /book/{formId}.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.formId});
  final String formId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _loading = true;
  BookingForm? _form;
  String _artistName = '';
  Availability? _availability;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final Map<String, String> _responses = {};

  DateTime _selectedDay = _stripTime(DateTime.now());
  List<TimeSlot> _slots = [];
  TimeSlot? _chosen;
  bool _slotsLoading = false;

  bool _booking = false;
  String? _error;

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final form = await db.getForm(widget.formId);
    if (form == null) {
      setState(() => _loading = false);
      return;
    }
    final profile = await db.publicProfile(form.artistId);
    _form = form;
    _artistName = profile?.displayName ?? 'Artist';
    _availability = profile?.availability ?? Availability.defaults();
    setState(() => _loading = false);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final form = _form!;
    setState(() {
      _slotsLoading = true;
      _chosen = null;
    });
    final dayStart = _selectedDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    final existing =
        await db.appointmentsInRange(form.artistId, dayStart, dayEnd);
    final slots = AvailabilityService.openSlots(
      day: dayStart,
      availability: _availability!,
      durationMinutes: form.durationMinutes,
      existing: existing,
    );
    if (mounted) {
      setState(() {
        _slots = slots;
        _slotsLoading = false;
      });
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: _stripTime(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (picked != null) {
      setState(() => _selectedDay = _stripTime(picked));
      _loadSlots();
    }
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Please enter your name.';
    if (!_email.text.contains('@')) return 'Please enter a valid email.';
    if (_form!.collectPhone && _phone.text.trim().isEmpty) {
      return 'Please enter your phone number.';
    }
    for (final f in _form!.fields) {
      if (f.required && (_responses[f.id]?.trim().isEmpty ?? true)) {
        return 'Please answer: ${f.label}';
      }
    }
    if (_chosen == null) return 'Please pick an available time.';
    return null;
  }

  Future<void> _book() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    final form = _form!;
    final slot = _chosen!;
    final responses = <String, String>{
      ..._responses,
      for (final f in form.fields) '__label__${f.id}': f.label,
    };
    try {
      final apptId = await db.bookAppointment(
        artistId: form.artistId,
        formId: form.id,
        start: slot.start,
        end: slot.end,
        details: AppointmentDetails(
          customerName: _name.text.trim(),
          customerEmail: _email.text.trim(),
          customerPhone: _phone.text.trim(),
          responses: responses,
        ),
      );
      if (!mounted) return;
      // Booked! Run the AI design consult, then hand off to the confirmation
      // screen (which can generate a concept image from the conversation).
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DesignChatScreen(
          appointmentId: apptId,
          buildSuccess: (messages, refs) => BookingSuccessScreen(
            artistName: _artistName,
            title: form.title,
            start: slot.start,
            end: slot.end,
            icsBuilder: () => IcsService.build(
              uid: '${form.artistId}_${slot.start.millisecondsSinceEpoch}',
              title: '$_artistName — ${form.title}',
              start: slot.start,
              end: slot.end,
              description: form.description,
            ),
            googleCalendarUrl: IcsService.googleCalendarUrl(
              title: '$_artistName — ${form.title}',
              start: slot.start,
              end: slot.end,
              description: form.description,
            ),
            appointmentId: apptId,
            chatMessages: messages,
            referenceImages: refs,
          ),
        ),
      ));
    } on SlotTakenException {
      setState(() {
        _error = 'That time was just taken. Pick another slot.';
        _booking = false;
      });
      _loadSlots();
    } catch (e) {
      setState(() {
        _error = 'Could not book. Please try again.';
        _booking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_form == null) {
      return _Message(
        icon: Icons.link_off,
        title: 'Booking link not found',
        body: 'This link may have been removed. Ask the artist for a new one.',
      );
    }
    if (!_form!.active) {
      return _Message(
        icon: Icons.pause_circle_outline,
        title: 'Bookings paused',
        body: '$_artistName is not accepting bookings right now.',
      );
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset('assets/logo.png', width: 48, height: 48),
              ),
              const SizedBox(height: 20),
              Text(_artistName,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_form!.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              if (_form!.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_form!.description,
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ],
              const SizedBox(height: 8),
              Text('${_form!.durationMinutes} minute appointment',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              const Divider(height: 40),

              // ---- contact ----
              Text('Your details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (_form!.collectPhone) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
              ],

              // ---- custom questions ----
              for (final f in _form!.fields) ...[
                const SizedBox(height: 12),
                _buildField(f),
              ],

              const Divider(height: 40),

              // ---- pick a time ----
              Text('Pick a time',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('EEEE, MMMM d').format(_selectedDay)),
              ),
              const SizedBox(height: 16),
              if (_slotsLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ))
              else if (_slots.isEmpty)
                Text('No open times this day. Try another date.',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.6)))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _slots)
                      ChoiceChip(
                        label: Text(DateFormat('h:mm a').format(s.start)),
                        selected: _chosen == s,
                        onSelected: (_) => setState(() => _chosen = s),
                      ),
                  ],
                ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _booking ? null : _book,
                child: _booking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_chosen == null
                        ? 'Request appointment'
                        : 'Book ${DateFormat('MMM d, h:mm a').format(_chosen!.start)}'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(FormFieldDef f) {
    switch (f.type) {
      case FieldType.choice:
        return InputDecorator(
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _responses[f.id],
              hint: const Text('Select…'),
              items: f.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _responses[f.id] = v ?? ''),
            ),
          ),
        );
      case FieldType.multiline:
        return TextField(
          maxLines: 3,
          decoration:
              InputDecoration(labelText: f.label + (f.required ? ' *' : '')),
          onChanged: (v) => _responses[f.id] = v,
        );
      case FieldType.number:
        return TextField(
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: f.label + (f.required ? ' *' : '')),
          onChanged: (v) => _responses[f.id] = v,
        );
      case FieldType.text:
        return TextField(
          decoration:
              InputDecoration(labelText: f.label + (f.required ? ' *' : '')),
          onChanged: (v) => _responses[f.id] = v,
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}
