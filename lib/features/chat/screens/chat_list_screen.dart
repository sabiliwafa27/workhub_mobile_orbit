import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/orbit_theme.dart';
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

  final List<String> _filters = ['All', 'Favorites', 'WORKING', 'Follow up'];

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatNotifierProvider);
    final displayChats = chatState.chats;

    return Scaffold(
      backgroundColor: OrbitColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Customer Discussions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: OrbitColors.textNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: OrbitColors.textNavy),
            onPressed: () {
              ref.read(chatNotifierProvider.notifier).loadChats(
                search: _searchController.text,
                filter: _selectedFilter == 'All' ? null : _selectedFilter.toLowerCase(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: OrbitColors.primaryNavy,
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
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: OrbitColors.cardSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: OrbitColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: OrbitColors.textMuted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (val) {
                          ref.read(chatNotifierProvider.notifier).loadChats(
                            search: val,
                            filter: _selectedFilter == 'All' ? null : _selectedFilter.toLowerCase(),
                          );
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: TextStyle(
                            color: OrbitColors.textMuted,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Horizontal Filter Chips
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                      ref.read(chatNotifierProvider.notifier).loadChats(
                        search: _searchController.text,
                        filter: filter == 'All' ? null : filter.toLowerCase(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? OrbitColors.pillDark : OrbitColors.cardSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? OrbitColors.pillDark : OrbitColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : OrbitColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Chats List
            Expanded(
              child: chatState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: OrbitColors.primaryNavy),
                    )
                  : displayChats.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: OrbitColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'No conversations found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: OrbitColors.textNavy,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Customer and internal discussions will appear here.',
                                style: TextStyle(fontSize: 12, color: OrbitColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                          itemCount: displayChats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final chat = displayChats[index];
                            return _buildChatItem(chat);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatItemModel chat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OrbitColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OrbitColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          ref.read(chatRepositoryProvider).markRead(chat.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening thread with ${chat.title}...'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: chat.isGroup
                  ? OrbitColors.coralIconBg
                  : OrbitColors.bubbleBlue,
              child: chat.isGroup
                  ? const Icon(Icons.group, color: OrbitColors.coralIcon, size: 22)
                  : Text(
                      chat.title.isNotEmpty ? chat.title[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: OrbitColors.primaryNavy,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Chat Info
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: OrbitColors.textNavy,
                          ),
                        ),
                      ),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.unreadCount > 0 ? OrbitColors.brandOrange : OrbitColors.textMuted,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.senderPrefix != null) ...[
                        Text(
                          '${chat.senderPrefix}: ',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OrbitColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: OrbitColors.textSecondary,
                          ),
                        ),
                      ),
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: OrbitColors.accentCoral,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
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
