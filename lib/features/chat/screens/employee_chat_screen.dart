import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/orbit_theme.dart';
import '../../../core/widgets/expanding_action_fab.dart';
import '../../../core/widgets/orbit_workspace.dart';

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
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/employee-chat/conversations');
      final items = response.data['data'] as List;
      if (mounted)
        setState(() {
          chats = items;
          error = null;
          loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'Unable to load chats.';
          loading = false;
        });
    }
  }

  Future<void> open(int id, String name) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EmployeeMessagesScreen(id: id, name: name)));
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = chats
        .where((item) =>
            item['name']
                .toString()
                .toLowerCase()
                .contains(search.text.toLowerCase()) &&
            (!unread || (item['unread_count'] as num? ?? 0) > 0))
        .toList();
    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
          title: const Text('Chats',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: OrbitColors.textNavy)),
          actions: [
            PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout')
                    ref.read(authProvider.notifier).logout();
                },
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'logout', child: Text('Log out'))
                    ])
          ]),
      floatingActionButton: OrbitPlusFab(
          heroTag: 'employee-chat-fab',
          onPressed: () async {
            final selected = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                    builder: (_) => const EmployeePickerScreen()));
            if (selected != null && mounted)
              open(
                  (selected['id'] as num).toInt(), selected['name'].toString());
          },
          tooltip: 'New chat'),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'Search'))),
        Row(children: [
          const SizedBox(width: 16),
          ChoiceChip(
              label: const Text('All'),
              selected: !unread,
              selectedColor: OrbitColors.bubbleBlue,
              showCheckmark: false,
              onSelected: (_) => setState(() => unread = false)),
          const SizedBox(width: 8),
          ChoiceChip(
              label: const Text('Unread'),
              selected: unread,
              selectedColor: OrbitColors.bubbleBlue,
              showCheckmark: false,
              onSelected: (_) => setState(() => unread = true))
        ]),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: TextButton(
                            onPressed: load,
                            child: Text('$error Tap to retry.')))
                    : RefreshIndicator(
                        onRefresh: load,
                        child: filtered.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                Center(child: Text('No chats yet.'))
                              ])
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, index) {
                                  final chat = filtered[index];
                                  final count =
                                      (chat['unread_count'] as num? ?? 0)
                                          .toInt();
                                  return Card(
                                      child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                          leading: const CircleAvatar(
                                              radius: 25,
                                              backgroundColor:
                                                  OrbitColors.bubbleBlue,
                                              child: Icon(Icons.person,
                                                  color:
                                                      OrbitColors.primaryNavy)),
                                          title: Text(chat['name'].toString(),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: OrbitColors.textNavy)),
                                          subtitle: Text((chat['latest_message'] ?? '').toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                          trailing: count > 0
                                              ? CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor:
                                                      OrbitColors.primaryNavy,
                                                  child: Text('$count',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.white)))
                                              : null,
                                          onTap: () =>
                                              open((chat['id'] as num).toInt(), chat['name'].toString())));
                                }))),
      ]),
    );
  }
}

class EmployeePickerScreen extends ConsumerStatefulWidget {
  const EmployeePickerScreen({super.key});
  @override
  ConsumerState<EmployeePickerScreen> createState() =>
      _EmployeePickerScreenState();
}

class _EmployeePickerScreenState extends ConsumerState<EmployeePickerScreen> {
  late Future<List<dynamic>> employees;
  final search = TextEditingController();
  Timer? searchTimer;
  @override
  void initState() {
    super.initState();
    employees = load();
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> load() async =>
      (await ref.read(apiClientProvider).dio.get('/employee-chat/employees',
              queryParameters: {'search': search.text.trim()}))
          .data['data'] as List;
  Future<void> start(dynamic employee) async {
    try {
      final result = await ref.read(apiClientProvider).dio.post(
          '/employee-chat/conversations',
          data: {'user_id': employee['id']});
      if (mounted)
        Navigator.pop(context,
            {'id': result.data['data']['id'], 'name': employee['name']});
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to start chat.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('New chat')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
                controller: search,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search employees'),
                onChanged: (_) {
                  searchTimer?.cancel();
                  searchTimer = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) setState(() => employees = load());
                  });
                })),
        Expanded(
            child: FutureBuilder<List<dynamic>>(
                future: employees,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                        child: TextButton(
                            onPressed: () => setState(() => employees = load()),
                            child: const Text(
                                'Unable to load employees. Tap to retry.')));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data!;
                  return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) => ListTile(
                          title: Text(items[i]['name'].toString()),
                          onTap: () => start(items[i])));
                }))
      ]));
}

class EmployeeMessagesScreen extends ConsumerStatefulWidget {
  final int id;
  final String name;
  const EmployeeMessagesScreen(
      {super.key, required this.id, required this.name});
  @override
  ConsumerState<EmployeeMessagesScreen> createState() =>
      _EmployeeMessagesScreenState();
}

class _EmployeeMessagesScreenState
    extends ConsumerState<EmployeeMessagesScreen> {
  final message = TextEditingController();
  late Future<List<dynamic>> messages;
  bool sending = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    messages = load();
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => messages = load());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    message.dispose();
    super.dispose();
  }

  Future<List<dynamic>> load() async {
    final dio = ref.read(apiClientProvider).dio;
    final response =
        await dio.get('/employee-chat/conversations/${widget.id}/messages');
    final items = response.data['data'] as List;
    if (items.isNotEmpty) {
      await dio.post('/employee-chat/conversations/${widget.id}/read',
          data: {'last_read_message_id': items.last['id']});
    }
    return items;
  }

  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await ref.read(apiClientProvider).dio.post(
          '/employee-chat/conversations/${widget.id}/messages',
          data: {'body': body});
      message.clear();
      if (mounted) setState(() => messages = load());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to send message.')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => OrbitWorkspaceScaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(children: [
        Expanded(
            child: FutureBuilder<List<dynamic>>(
                future: messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                        child: TextButton(
                            onPressed: () => setState(() => messages = load()),
                            child: const Text(
                                'Unable to load messages. Tap to retry.')));
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final items = snapshot.data!;
                  final userId = ref.read(authProvider).user?.id;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = Map<String, dynamic>.from(items[i] as Map);
                      final mine = item['sender_user_id'] == userId;
                      final sentAt = _messageDate(item);
                      final previousDate = i == 0
                          ? null
                          : _messageDate(
                              Map<String, dynamic>.from(items[i - 1] as Map));
                      final showDate = sentAt != null &&
                          (i == 0 ||
                              previousDate == null ||
                              !DateUtils.isSameDay(sentAt, previousDate));
                      final body =
                          (item['body'] ?? item['message'] ?? '').toString();

                      return Column(
                        children: [
                          if (showDate) _ChatDateCapsule(date: sentAt),
                          Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * .78,
                              ),
                              padding: const EdgeInsets.fromLTRB(9, 6, 8, 5),
                              decoration: BoxDecoration(
                                color: mine
                                    ? OrbitColors.primaryNavy
                                    : OrbitColors.cardSurface,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(mine ? 12 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 12),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 1,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: body,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.32,
                                      ).copyWith(
                                        color: mine
                                            ? Colors.white
                                            : OrbitColors.textPrimary,
                                      ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 7),
                                        child: Text(
                                          _messageTime(item),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            height: 1,
                                          ).copyWith(
                                            color: mine
                                                ? const Color(0xFFC9D7E8)
                                                : OrbitColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (mine)
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 2),
                                          child: _MessageChecks(status: item),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                })),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: message,
                          decoration: const InputDecoration(
                              hintText: 'Write a message...',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(999))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(999))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(999)))))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: sending ? null : send,
                      icon: const Icon(Icons.send))
                ]))),
      ]));
}

DateTime? _messageDate(Map<String, dynamic> message) {
  final raw = message['created_at'] ?? message['sent_at'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

String _messageTime(Map<String, dynamic> message) {
  final date = _messageDate(message);
  return date == null ? '' : DateFormat('HH:mm').format(date);
}

String _chatDayLabel(DateTime date) {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  if (DateUtils.isSameDay(date, today)) return 'TODAY';
  if (DateUtils.isSameDay(date, yesterday)) return 'YESTERDAY';
  if (_sameWeek(date, today)) return DateFormat('EEEE').format(date);
  return DateFormat('MMMM d, yyyy').format(date);
}

bool _sameWeek(DateTime first, DateTime second) {
  DateTime weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);
  return weekStart(first) == weekStart(second);
}

class _ChatDateCapsule extends StatelessWidget {
  final DateTime date;
  const _ChatDateCapsule({required this.date});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                _chatDayLabel(date),
                style: const TextStyle(
                  color: Color(0xFF54656F),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ),
      );
}

class _MessageChecks extends StatelessWidget {
  final Map<String, dynamic> status;
  const _MessageChecks({required this.status});

  @override
  Widget build(BuildContext context) {
    final value = (status['status'] ?? status['delivery_status'] ?? '')
        .toString()
        .toLowerCase();
    final read = status['is_read'] == true ||
        status['read_at'] != null ||
        status['seen_at'] != null ||
        const {'read', 'seen'}.contains(value);
    final delivered = read ||
        status['is_delivered'] == true ||
        status['delivered_at'] != null ||
        const {'delivered', 'received'}.contains(value);
    return Icon(
      delivered ? Icons.done_all_rounded : Icons.check_rounded,
      size: 15,
      color: read ? const Color(0xFF53BDEB) : const Color(0xFFC9D7E8),
    );
  }
}
