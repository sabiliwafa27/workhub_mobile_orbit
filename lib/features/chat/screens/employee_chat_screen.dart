import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

class EmployeeChatScreen extends ConsumerStatefulWidget {
  const EmployeeChatScreen({super.key});
  @override
  ConsumerState<EmployeeChatScreen> createState() => _EmployeeChatScreenState();
}

class _EmployeeChatScreenState extends ConsumerState<EmployeeChatScreen> {
  final search = TextEditingController();
  List<dynamic> chats = [];
  bool loading = true, unread = false;
  String? error;
  Timer? timer;

  @override
  void initState() { super.initState(); load(); timer = Timer.periodic(const Duration(seconds: 20), (_) => load()); }
  @override
  void dispose() { timer?.cancel(); search.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final response = await ref.read(apiClientProvider).dio.get('/employee-chat/conversations');
      final items = response.data['data'] as List;
      if (mounted) setState(() { chats = items; error = null; loading = false; });
    } catch (_) {
      if (mounted) setState(() { error = 'Unable to load chats.'; loading = false; });
    }
  }

  Future<void> open(int id, String name) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeMessagesScreen(id: id, name: name)));
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = chats.where((item) => item['name'].toString().toLowerCase().contains(search.text.toLowerCase()) && (!unread || (item['unread_count'] as num? ?? 0) > 0)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Chats'), actions: [PopupMenuButton<String>(onSelected: (value) { if (value == 'logout') ref.read(authProvider.notifier).logout(); }, itemBuilder: (_) => [const PopupMenuItem(value: 'logout', child: Text('Log out'))])]),
      floatingActionButton: FloatingActionButton(onPressed: () async {
        final selected = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const EmployeePickerScreen()));
        if (selected != null && mounted) open((selected['id'] as num).toInt(), selected['name'].toString());
      }, child: const Icon(Icons.add)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search chats', border: OutlineInputBorder()))),
        Row(children: [const SizedBox(width: 12), ChoiceChip(label: const Text('All'), selected: !unread, onSelected: (_) => setState(() => unread = false)), const SizedBox(width: 8), ChoiceChip(label: const Text('Unread'), selected: unread, onSelected: (_) => setState(() => unread = true))]),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: TextButton(onPressed: load, child: Text('$error Tap to retry.'))) : RefreshIndicator(onRefresh: load, child: filtered.isEmpty ? ListView(children: const [SizedBox(height: 100), Center(child: Text('No chats yet.'))]) : ListView.builder(itemCount: filtered.length, itemBuilder: (_, index) {
          final chat = filtered[index]; final count = (chat['unread_count'] as num? ?? 0).toInt();
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(chat['name'].toString()), subtitle: Text((chat['latest_message'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis), trailing: count > 0 ? CircleAvatar(radius: 12, child: Text('$count', style: const TextStyle(fontSize: 11))) : null, onTap: () => open((chat['id'] as num).toInt(), chat['name'].toString()));
        }))),
      ]),
    );
  }
}

class EmployeePickerScreen extends ConsumerStatefulWidget {
  const EmployeePickerScreen({super.key});
  @override
  ConsumerState<EmployeePickerScreen> createState() => _EmployeePickerScreenState();
}

class _EmployeePickerScreenState extends ConsumerState<EmployeePickerScreen> {
  late Future<List<dynamic>> employees;
  final search = TextEditingController();
  Timer? searchTimer;
  @override
  void initState() { super.initState(); employees = load(); }
  @override
  void dispose() { searchTimer?.cancel(); search.dispose(); super.dispose(); }
  Future<List<dynamic>> load() async => (await ref.read(apiClientProvider).dio.get('/employee-chat/employees', queryParameters: {'search': search.text.trim()})).data['data'] as List;
  Future<void> start(dynamic employee) async {
    try {
      final result = await ref.read(apiClientProvider).dio.post('/employee-chat/conversations', data: {'user_id': employee['id']});
      if (mounted) Navigator.pop(context, {'id': result.data['data']['id'], 'name': employee['name']});
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to start chat.'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('New chat')), body: Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search employees'), onChanged: (_) {
      searchTimer?.cancel();
      searchTimer = Timer(const Duration(milliseconds: 350), () { if (mounted) setState(() => employees = load()); });
    })),
    Expanded(child: FutureBuilder<List<dynamic>>(future: employees, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => employees = load()), child: const Text('Unable to load employees. Tap to retry.')));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final items = snapshot.data!;
    return ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ListTile(title: Text(items[i]['name'].toString()), onTap: () => start(items[i])));
  }))]));
}

class EmployeeMessagesScreen extends ConsumerStatefulWidget {
  final int id; final String name;
  const EmployeeMessagesScreen({super.key, required this.id, required this.name});
  @override
  ConsumerState<EmployeeMessagesScreen> createState() => _EmployeeMessagesScreenState();
}

class _EmployeeMessagesScreenState extends ConsumerState<EmployeeMessagesScreen> {
  final message = TextEditingController();
  late Future<List<dynamic>> messages;
  bool sending = false;
  Timer? timer;
  @override
  void initState() { super.initState(); messages = load(); timer = Timer.periodic(const Duration(seconds: 10), (_) { if (mounted) setState(() => messages = load()); }); }
  @override
  void dispose() { timer?.cancel(); message.dispose(); super.dispose(); }
  Future<List<dynamic>> load() async {
    final dio = ref.read(apiClientProvider).dio;
    final response = await dio.get('/employee-chat/conversations/${widget.id}/messages');
    final items = response.data['data'] as List;
    if (items.isNotEmpty) {
      await dio.post('/employee-chat/conversations/${widget.id}/read', data: {'last_read_message_id': items.last['id']});
    }
    return items;
  }
  Future<void> send() async {
    final body = message.text.trim(); if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await ref.read(apiClientProvider).dio.post('/employee-chat/conversations/${widget.id}/messages', data: {'body': body});
      message.clear(); if (mounted) setState(() => messages = load());
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to send message.'))); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.name)), body: Column(children: [
    Expanded(child: FutureBuilder<List<dynamic>>(future: messages, builder: (context, snapshot) {
      if (snapshot.hasError) return Center(child: TextButton(onPressed: () => setState(() => messages = load()), child: const Text('Unable to load messages. Tap to retry.')));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final items = snapshot.data!; final userId = ref.read(authProvider).user?.id;
      return ListView.builder(itemCount: items.length, itemBuilder: (_, i) => Align(alignment: items[i]['sender_user_id'] == userId ? Alignment.centerRight : Alignment.centerLeft, child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(items[i]['body'].toString())))));
    })),
    SafeArea(child: Row(children: [Expanded(child: TextField(controller: message, decoration: const InputDecoration(hintText: 'Message'))), IconButton(onPressed: sending ? null : send, icon: const Icon(Icons.send))])),
  ]));
}
