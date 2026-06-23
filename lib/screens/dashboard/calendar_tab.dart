import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/appointment.dart';
import '../../services/ics_service.dart';
import '../../services/services.dart';

/// Month calendar of the artist's appointments, with a list of the selected
/// day's bookings and confirm / cancel / details actions.
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.appointments});
  final List<Appointment> appointments;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  List<Appointment> _forDay(DateTime day) => widget.appointments
      .where((a) => a.isActive && isSameDay(a.start, day))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  @override
  Widget build(BuildContext context) {
    final dayAppts = _forDay(_selected);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TableCalendar<Appointment>(
              firstDay: DateTime.utc(2023, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focused,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              eventLoader: _forDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(DateFormat('EEEE, MMMM d').format(_selected),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (dayAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nothing booked this day.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          )
        else
          ...dayAppts.map((a) => _AppointmentCard(
                appt: a,
                onChanged: () => setState(() {}),
              )),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appt, required this.onChanged});
  final Appointment appt;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    return Card(
      child: FutureBuilder<AppointmentDetails>(
        future: db.appointmentDetails(appt.id),
        builder: (context, snap) {
          final d = snap.data;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _color(appt.status).withValues(alpha: 0.2),
              child: Icon(Icons.person, color: _color(appt.status)),
            ),
            title: Text(d?.customerName ?? 'Loading…'),
            subtitle: Text(
              '${time.format(appt.start)} – ${time.format(appt.end)}  •  '
              '${appt.status.name}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _onAction(context, v, d),
              itemBuilder: (_) => [
                if (appt.status != AppointmentStatus.confirmed)
                  const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                const PopupMenuItem(value: 'details', child: Text('View details')),
                const PopupMenuItem(value: 'ics', child: Text('Add to my calendar')),
                const PopupMenuItem(value: 'cancel', child: Text('Cancel booking')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _showDetails(context, d),
          );
        },
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, String action, AppointmentDetails? d) async {
    switch (action) {
      case 'confirm':
        await db.setStatus(appt.id, AppointmentStatus.confirmed);
        onChanged();
      case 'cancel':
        await db.cancelAppointment(appt.id);
        onChanged();
      case 'delete':
        await db.deleteAppointment(appt.id);
        onChanged();
      case 'details':
        if (context.mounted) _showDetails(context, d);
      case 'ics':
        IcsService.download(
          'appointment.ics',
          IcsService.build(
            uid: appt.id,
            title: 'Tattoo: ${d?.customerName ?? 'Client'}',
            start: appt.start,
            end: appt.end,
            description: _summary(d),
          ),
        );
    }
  }

  void _showDetails(BuildContext context, AppointmentDetails? d) {
    if (d == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d.customerName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('When',
                  DateFormat('EEE MMM d, h:mm a').format(appt.start)),
              _row('Status', appt.status.name),
              if (d.customerEmail.isNotEmpty) _row('Email', d.customerEmail),
              if (d.customerPhone.isNotEmpty) _row('Phone', d.customerPhone),
              for (final e in d.responses.entries)
                if (!e.key.startsWith('__label__'))
                  _row(d.responses['__label__${e.key}'] ?? e.key, e.value),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(v),
          ],
        ),
      );

  String _summary(AppointmentDetails? d) {
    if (d == null) return '';
    final parts = <String>[
      if (d.customerEmail.isNotEmpty) 'Email: ${d.customerEmail}',
      if (d.customerPhone.isNotEmpty) 'Phone: ${d.customerPhone}',
      for (final e in d.responses.entries)
        if (!e.key.startsWith('__label__'))
          '${d.responses['__label__${e.key}'] ?? e.key}: ${e.value}',
    ];
    return parts.join('\n');
  }

  Color _color(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => Colors.orangeAccent,
        AppointmentStatus.confirmed => Colors.greenAccent,
        AppointmentStatus.cancelled => Colors.redAccent,
      };
}
