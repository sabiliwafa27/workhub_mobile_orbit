import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/whatsapp_colors.dart';
import '../models/chat_item_model.dart';
import '../providers/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Favorites', 'WORKING', 'Follow up', '+'];

  // Fallback demo chats to show nice WhatsApp layout when offline or empty
  final List<ChatItemModel> _fallbackChats = [
    ChatItemModel(
      id: '1',
      title: '@tokotechkekinian (You)',
      lastMessage: 'Hermes is shutting down for scheduled maintenance...',
      time: '11:32',
      isPinned: true,
      tag: null,
      isGroup: false,
      senderPrefix: 'Hertod',
    ),
    ChatItemModel(
      id: '2',
      title: 'gatsby',
      lastMessage: 'Photo',
      time: 'Yesterday',
      isPinned: true,
      tag: null,
      isGroup: true,
      senderPrefix: 'siwa',
    ),
    ChatItemModel(
      id: '3',
      title: 'Tukang Gambar',
      lastMessage: 'nggh',
      time: '12:19',
      tag: 'WORKING',
      isGroup: true,
      senderPrefix: 'Mas Ilyas',
    ),
    ChatItemModel(
      id: '4',
      title: 'Mas Rudy PFI',
      lastMessage: '3 orang saja',
      time: '09:25',
      isGroup: false,
    ),
    ChatItemModel(
      id: '5',
      title: 'PFI',
      lastMessage: 'Pagi Semua, menginformasikan kembali untuk b...',
      time: '08:28',
      tag: 'WORKING',
      isGroup: true,
      senderPrefix: 'Mas Vito',
    ),
    ChatItemModel(
      id: '6',
      title: 'Sawi Dojo',
      lastMessage: 'Jumat 6 Nov',
      time: 'Yesterday',
      isGroup: true,
      senderPrefix: 'Mas Vito',
    ),
    ChatItemModel(
      id: '7',
      title: 'Rahmad Bagus DM',
      lastMessage: 'Oke',
      time: 'Yesterday',
      isGroup: false,
    ),
    ChatItemModel(
      id: '8',
      title: 'IT Guys',
      lastMessage: 'kami sudah siap, pak',
      time: 'Yesterday',
      isGroup: true,
      senderPrefix: 'Mas Dhika',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final displayChats = chatState.chats.isNotEmpty ? chatState.chats : _fallbackChats;

    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: RefreshIndicator(
        color: WhatsAppColors.tealGreen,
        onRefresh: () async {
          await ref.read(chatNotifierProvider.notifier).loadChats(
            search: _searchController.text,
            filter: _selectedFilter == 'All' ? null : _selectedFilter.toLowerCase(),
          );
        },
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: WhatsAppColors.searchBarBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 15),
                  onChanged: (val) {
                    ref.read(chatNotifierProvider.notifier).loadChats(
                      search: val,
                      filter: _selectedFilter == 'All' ? null : _selectedFilter.toLowerCase(),
                    );
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(
                      color: WhatsAppColors.textSecondary,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(Icons.search, color: WhatsAppColors.iconMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  if (filter == '+') {
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        border: Border.all(color: WhatsAppColors.chipBorder),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 20, color: WhatsAppColors.chipText),
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      ref.read(chatNotifierProvider.notifier).loadChats(
                        search: _searchController.text,
                        filter: filter == 'All' ? null : filter.toLowerCase(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? WhatsAppColors.navIndicatorBg
                            : WhatsAppColors.chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? WhatsAppColors.tealGreen.withOpacity(0.3)
                              : WhatsAppColors.chipBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filter == 'WORKING') ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: WhatsAppColors.workingBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (filter == 'Follow up') ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: WhatsAppColors.followUpGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            filter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? WhatsAppColors.darkGreen
                                  : WhatsAppColors.chipText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Archived Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: const [
                  Icon(Icons.archive_outlined, color: WhatsAppColors.iconMuted, size: 20),
                  SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      'Archived',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WhatsAppColors.titleText,
                      ),
                    ),
                  ),
                  Text(
                    '30',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: WhatsAppColors.tealGreen,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: WhatsAppColors.divider, height: 1, indent: 64),

            // Chat List
            Expanded(
              child: ListView.separated(
                itemCount: displayChats.length,
                separatorBuilder: (_, __) => const Divider(
                  color: WhatsAppColors.divider,
                  height: 1,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final chat = displayChats[index];
                  return _buildChatItem(chat);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: WhatsAppColors.fabBg,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.add_comment_rounded,
          color: WhatsAppColors.fabIcon,
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatItemModel chat) {
    return InkWell(
      onTap: () {
        ref.read(chatRepositoryProvider).markRead(chat.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: chat.isGroup
                  ? const Color(0xFFFFE0D2)
                  : (chat.title.contains('PFI') ? const Color(0xFFF0F4F8) : const Color(0xFFE2E8F0)),
              child: chat.isGroup
                  ? const Icon(Icons.group, color: Color(0xFFC2410C), size: 24)
                  : Text(
                      chat.title.isNotEmpty ? chat.title[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: WhatsAppColors.titleText,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: WhatsAppColors.titleText,
                          ),
                        ),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: chat.unreadCount > 0
                              ? WhatsAppColors.tealGreen
                              : WhatsAppColors.timeText,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.isRead && !chat.isGroup) ...[
                        const Icon(
                          Icons.done_all,
                          size: 16,
                          color: WhatsAppColors.checkBlue,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (chat.senderPrefix != null) ...[
                        Text(
                          '${chat.senderPrefix}: ',
                          style: const TextStyle(
                            fontSize: 14,
                            color: WhatsAppColors.subtitleText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: WhatsAppColors.subtitleText,
                          ),
                        ),
                      ),
                      if (chat.tag != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            chat.tag!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                      if (chat.isPinned) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.push_pin,
                          size: 16,
                          color: WhatsAppColors.iconMuted,
                        ),
                      ],
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: WhatsAppColors.badgeGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
