import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';

class CreateWorkItemScreen extends ConsumerStatefulWidget {
  final bool isEc;
  final int? projectId;
  const CreateWorkItemScreen({super.key, this.isEc = false, this.projectId});

  @override
  ConsumerState<CreateWorkItemScreen> createState() => _CreateWorkItemScreenState();
}

class _CreateWorkItemScreenState extends ConsumerState<CreateWorkItemScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  DateTime dueDate = DateTime.now();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final employeeId = ref.read(authProvider).user?.employeeId;
    if (title.text.trim().isEmpty || (!widget.isEc && employeeId == null)) {
      setState(() => error = employeeId == null && !widget.isEc ? 'Your account has no employee record.' : 'Enter a title.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await ref.read(apiClientProvider).dio.post(widget.isEc ? '/ec/entries' : '/tasks', data: widget.isEc
          ? {'title': title.text.trim(), 'intended_benefit': description.text.trim(), 'creation_key': const Uuid().v4()}
          : {'title': title.text.trim(), 'description': description.text.trim(), 'due_date': dueDate.toIso8601String().split('T').first, 'assignee_scope': 'specific', 'employee_ids': [employeeId], if (widget.projectId != null) 'project_id': widget.projectId});
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => error = 'Unable to create this item. Check your access and try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.isEc ? 'Create EC' : 'Create task')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
      TextField(controller: description, maxLines: 3, decoration: InputDecoration(labelText: widget.isEc ? 'Intended benefit' : 'Description')),
      if (!widget.isEc) ListTile(title: const Text('Due date'), subtitle: Text(dueDate.toIso8601String().split('T').first), onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) setState(() => dueDate = picked);
      }),
      if (!widget.isEc) const Text('Assigned to you'),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      FilledButton(onPressed: saving ? null : submit, child: Text(saving ? 'Saving…' : 'Create')),
    ]),
  );
}
