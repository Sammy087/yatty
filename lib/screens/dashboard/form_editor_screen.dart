import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/booking_form.dart';
import '../../services/services.dart';

/// Create (formId == null) or edit a booking form.
class FormEditorScreen extends StatefulWidget {
  const FormEditorScreen({super.key, required this.formId});
  final String? formId;

  @override
  State<FormEditorScreen> createState() => _FormEditorScreenState();
}

class _FormEditorScreenState extends State<FormEditorScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  int _duration = 60;
  bool _collectPhone = true;
  bool _active = true;
  List<FormFieldDef> _fields = [];

  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.formId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isNew) {
      final blank = BookingForm.empty(auth.currentUser!.uid);
      _title.text = blank.title;
      setState(() => _loading = false);
      return;
    }
    final form = await db.getForm(widget.formId!);
    if (form != null) {
      _title.text = form.title;
      _description.text = form.description;
      _duration = form.durationMinutes;
      _collectPhone = form.collectPhone;
      _active = form.active;
      _fields = List.of(form.fields);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your form a title.')),
      );
      return;
    }
    setState(() => _saving = true);
    final uid = auth.currentUser!.uid;
    final form = BookingForm(
      id: widget.formId ?? '',
      artistId: uid,
      title: _title.text.trim(),
      description: _description.text.trim(),
      durationMinutes: _duration,
      collectPhone: _collectPhone,
      active: _active,
      fields: _fields,
    );
    try {
      if (_isNew) {
        final id = await db.createForm(form);
        if (mounted) _showCreated(id);
      } else {
        await db.updateForm(form);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form saved.')),
          );
          context.pop();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCreated(String id) {
    final url = '${Uri.base.origin}/book/$id';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Form is live 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with clients:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(url,
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Done'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final nav = Navigator.of(context);
              final router = GoRouter.of(context);
              await Clipboard.setData(ClipboardData(text: url));
              nav.pop();
              router.pop();
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy link'),
          ),
        ],
      ),
    );
  }

  void _editField([int? index]) async {
    final result = await showDialog<FormFieldDef>(
      context: context,
      builder: (_) => _FieldDialog(
        initial: index == null ? null : _fields[index],
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _fields.add(result);
      } else {
        _fields[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New form' : 'Edit form'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Form title',
                  hintText: 'e.g. Custom tattoo consult',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (shown to clients)',
                  hintText: 'Deposit info, studio address, what to bring…',
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Appointment length')),
                          DropdownButton<int>(
                            value: _duration,
                            items: const [30, 45, 60, 90, 120, 180, 240]
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text('$m min'),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _duration = v ?? 60),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Collect phone number'),
                        value: _collectPhone,
                        onChanged: (v) => setState(() => _collectPhone = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Accepting bookings'),
                        subtitle: const Text('Turn off to pause the link'),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text('Custom questions',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: () => _editField(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Name and email are always collected. Add anything else you '
                'need (placement, size, references…).',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 12),
              if (_fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No custom questions yet.'),
                )
              else
                ..._fields.asMap().entries.map((e) => Card(
                      child: ListTile(
                        title: Text(e.value.label),
                        subtitle: Text(
                          '${e.value.type.name}'
                          '${e.value.required ? ' • required' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editField(e.key),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () =>
                                  setState(() => _fields.removeAt(e.key)),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog to add/edit a single custom field.
class _FieldDialog extends StatefulWidget {
  const _FieldDialog({this.initial});
  final FormFieldDef? initial;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  late final _label =
      TextEditingController(text: widget.initial?.label ?? '');
  late final _options = TextEditingController(
      text: widget.initial?.options.join(', ') ?? '');
  late FieldType _type = widget.initial?.type ?? FieldType.text;
  late bool _required = widget.initial?.required ?? false;

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add question' : 'Edit question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FieldType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Answer type'),
              items: const [
                DropdownMenuItem(value: FieldType.text, child: Text('Short text')),
                DropdownMenuItem(value: FieldType.multiline, child: Text('Long text')),
                DropdownMenuItem(value: FieldType.number, child: Text('Number')),
                DropdownMenuItem(value: FieldType.choice, child: Text('Multiple choice')),
              ],
              onChanged: (v) => setState(() => _type = v ?? FieldType.text),
            ),
            if (_type == FieldType.choice) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                decoration: const InputDecoration(
                  labelText: 'Options',
                  helperText: 'Comma-separated',
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_label.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              FormFieldDef(
                id: widget.initial?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                label: _label.text.trim(),
                type: _type,
                required: _required,
                options: _type == FieldType.choice
                    ? _options.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList()
                    : const [],
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
