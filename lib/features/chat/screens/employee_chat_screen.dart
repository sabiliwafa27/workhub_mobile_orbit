import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/realtime/reverb_service.dart';
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
  final List<void Function()> _unsubscribeRealtime = [];

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => load());
    final userId = ref.read(authProvider).user?.id;
    final reverb = ref.read(reverbServiceProvider);
    if (userId != null) {
      _unsubscribeRealtime.add(
        reverb.subscribe('private-inbox.user.$userId', (_) {
          unawaited(load());
        }),
      );
    }
    _unsubscribeRealtime.add(
      reverb.subscribe('chat-updates', (_) {
        unawaited(load());
      }),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final unsubscribe in _unsubscribeRealtime) {
      unsubscribe();
    }
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
          if (chats.isEmpty) error = 'Unable to load chats.';
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
  final ScrollController _messagesScrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loadingMessages = true;
  String? _messagesError;
  int _loadGeneration = 0;
  bool sending = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load(initial: true);
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    message.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> load(
      {bool initial = false, bool forceScrollToBottom = false}) async {
    final generation = ++_loadGeneration;
    final shouldScrollToBottom = initial ||
        forceScrollToBottom ||
        !_messagesScrollController.hasClients ||
        _messagesScrollController.position.maxScrollExtent -
                _messagesScrollController.position.pixels <
            80;

    if (initial && mounted) {
      setState(() {
        _loadingMessages = true;
        _messagesError = null;
      });
    }

    try {
      final dio = ref.read(apiClientProvider).dio;
      final response =
          await dio.get('/employee-chat/conversations/${widget.id}/messages');
      final items = (response.data['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (items.isNotEmpty) {
        try {
          await dio.post('/employee-chat/conversations/${widget.id}/read',
              data: {'last_read_message_id': items.last['id']});
        } catch (_) {
          // Keep the messages visible if updating the read position fails.
        }
      }

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _messages = items;
        _messagesError = null;
        _loadingMessages = false;
      });
      if (shouldScrollToBottom) _scheduleScrollToBottom();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _messagesError = 'Unable to load messages.';
        _loadingMessages = false;
      });
    }
  }

  void _scheduleScrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) return;
      final position = _messagesScrollController.position;
      if (animated) {
        _messagesScrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messagesScrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  Future<void> send() async {
    final body = message.text.trim();
    if (body.isEmpty || sending) return;
    _loadGeneration++;
    final optimisticId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final currentUserId = ref.read(authProvider).user?.id;
    setState(() {
      sending = true;
      _messages = [
        ..._messages,
        {
          'id': optimisticId,
          'sender_user_id': currentUserId,
          'body': body,
          'created_at': DateTime.now().toIso8601String(),
          'delivery_status': 'sending',
        },
      ];
      _messagesError = null;
    });
    _scheduleScrollToBottom(animated: true);

    try {
      final response = await ref.read(apiClientProvider).dio.post(
          '/employee-chat/conversations/${widget.id}/messages',
          data: {'body': body});
      if (!mounted) return;
      message.clear();
      setState(() {
        _messages = _messages.map((item) {
          if (item is Map && item['id'] == optimisticId) {
            return {
              ...Map<String, dynamic>.from(item),
              'id': response.data['data']['id'],
              'delivery_status': 'sent',
            };
          }
          return item;
        }).toList();
      });
      await load(forceScrollToBottom: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages
              .removeWhere((item) => item is Map && item['id'] == optimisticId);
        });
      }
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
            child: _loadingMessages && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messagesError != null && _messages.isEmpty
                    ? Center(
                        child: TextButton(
                          onPressed: () => load(initial: true),
                          child: const Text(
                              'Unable to load messages. Tap to retry.'),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(child: Text('No messages yet.'))
                        : Builder(builder: (context) {
                            final items = _messages;
                            final userId = ref.read(authProvider).user?.id;
                            return ListView.builder(
                              controller: _messagesScrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(10, 12, 10, 12),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final item =
                                    Map<String, dynamic>.from(items[i] as Map);
                                final mine = item['sender_user_id'] == userId;
                                final sentAt = _messageDate(item);
                                final previousDate = i == 0
                                    ? null
                                    : _messageDate(Map<String, dynamic>.from(
                                        items[i - 1] as Map));
                                final showDate = sentAt != null &&
                                    (i == 0 ||
                                        previousDate == null ||
                                        !DateUtils.isSameDay(
                                            sentAt, previousDate));
                                final body =
                                    (item['body'] ?? item['message'] ?? '')
                                        .toString();

                                return Column(
                                  children: [
                                    if (showDate)
                                      _ChatDateCapsule(date: sentAt),
                                    Align(
                                      alignment: mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width *
                                                  .78,
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                            9, 6, 8, 5),
                                        decoration: BoxDecoration(
                                          color: mine
                                              ? OrbitColors.primaryNavy
                                              : OrbitColors.cardSurface,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(12),
                                            topRight: const Radius.circular(12),
                                            bottomLeft:
                                                Radius.circular(mine ? 12 : 4),
                                            bottomRight:
                                                Radius.circular(mine ? 4 : 12),
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
                                                alignment:
                                                    PlaceholderAlignment.middle,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 7),
                                                  child: Text(
                                                    _messageTime(item),
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      height: 1,
                                                    ).copyWith(
                                                      color: mine
                                                          ? const Color(
                                                              0xFFC9D7E8)
                                                          : OrbitColors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (mine)
                                                WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment
                                                          .middle,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 2),
                                                    child: _MessageChecks(
                                                        status: item),
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
