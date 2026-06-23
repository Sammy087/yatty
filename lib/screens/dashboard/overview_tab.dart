import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../models/booking_form.dart';
import '../../services/services.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.appointments,
    required this.loading,
  });

  final List<Appointment> appointments;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    final now = DateTime.now();
    final upcoming = appointments
        .where((a) => a.isActive && a.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final pending = appointments
        .where((a) => a.status == AppointmentStatus.pending && a.start.isAfter(now))
        .length;

    return StreamBuilder<List<BookingForm>>(
      stream: db.formsStream(uid),
      builder: (context, formsSnap) {
        final forms = formsSnap.data ?? const <BookingForm>[];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  label: 'Live forms',
                  value: '${forms.length}',
                  icon: Icons.description,
                ),
                _StatCard(
                  label: 'Upcoming',
                  value: '${upcoming.length}',
                  icon: Icons.event_available,
                ),
                _StatCard(
                  label: 'Needs review',
                  value: '$pending',
                  icon: Icons.mark_email_unread,
                  highlight: pending > 0,
                ),
                _StatCard(
                  label: 'Total booked',
                  value: '${appointments.where((a) => a.isActive).length}',
                  icon: Icons.how_to_reg,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/form/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New booking form'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/availability'),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Set availability'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Next appointments',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (upcoming.isEmpty)
              const _EmptyHint(
                  'No upcoming appointments yet. Share a booking form to start filling your calendar.')
            else
              ...upcoming.take(6).map((a) => _UpcomingTile(a)),
          ],
        );
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile(this.appt);
  final Appointment appt;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE MMM d • h:mm a');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(appt.status).withValues(alpha: 0.2),
          child: Icon(Icons.calendar_today,
              size: 18, color: _statusColor(appt.status)),
        ),
        title: Text(fmt.format(appt.start)),
        subtitle: Text(appt.status.name.toUpperCase(),
            style: TextStyle(color: _statusColor(appt.status), fontSize: 12)),
        trailing: FutureBuilder(
          future: db.appointmentDetails(appt.id),
          builder: (context, snap) => Text(snap.data?.customerName ?? '…'),
        ),
      ),
    );
  }
}

Color _statusColor(AppointmentStatus s) => switch (s) {
      AppointmentStatus.pending => Colors.orangeAccent,
      AppointmentStatus.confirmed => Colors.greenAccent,
      AppointmentStatus.cancelled => Colors.redAccent,
    };

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
      );
}
