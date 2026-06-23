import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/booking_form.dart';
import '../../services/services.dart';

class FormsTab extends StatelessWidget {
  const FormsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/form/new'),
        icon: const Icon(Icons.add),
        label: const Text('New form'),
      ),
      body: StreamBuilder<List<BookingForm>>(
        stream: db.formsStream(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final forms = snap.data!
            ..sort((a, b) => a.title.compareTo(b.title));
          if (forms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text('No booking forms yet'),
                    const SizedBox(height: 8),
                    Text(
                      'Create a form, then share its link with clients so they '
                      'can book without an account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/form/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create your first form'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final f in forms) _FormCard(form: f),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.form});
  final BookingForm form;

  String get _shareUrl => '${Uri.base.origin}/book/${form.id}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(form.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _StatusChip(active: form.active),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${form.durationMinutes} min • '
              '${form.fields.length} custom question'
              '${form.fields.length == 1 ? '' : 's'}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showShare(context),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share link'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/form/${form.id}'),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShare(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share this form'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send clients this link. No account needed — they pick '
                'an open slot and it lands on your calendar.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(_shareUrl,
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _shareUrl));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy link'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this form?'),
        content: const Text(
            'The share link will stop working. Existing appointments stay on '
            'your calendar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () async {
              await db.deleteForm(form.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.greenAccent : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(active ? 'Live' : 'Paused',
          style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
