import 'package:flutter/material.dart';
import '../../../../core/theme/whatsapp_colors.dart';
import '../models/chat_item_model.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<ChatItemModel> _chats = [
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
    return Scaffold(
      backgroundColor: WhatsAppColors.background,
      body: Column(
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
                style: const TextStyle(fontSize: 14, color: WhatsAppColors.titleText),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: WhatsAppColors.subtitleText, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: WhatsAppColors.subtitleText, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Horizontal Filter Chips matching screenshot
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                _buildFilterChip('All', isSelected: _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Favorites', isSelected: _selectedFilter == 'Favorites'),
                const SizedBox(width: 8),
                _buildFilterChip('WORKING',
                    isSelected: _selectedFilter == 'WORKING',
                    dotColor: WhatsAppColors.workingBlue),
                const SizedBox(width: 8),
                _buildFilterChip('Follow up',
                    isSelected: _selectedFilter == 'Follow up',
                    dotColor: WhatsAppColors.followUpGreen),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: WhatsAppColors.chipBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: WhatsAppColors.chipBorder),
                  ),
                  child: const Icon(Icons.add, size: 16, color: WhatsAppColors.chipText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Archived Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Icon(Icons.archive_outlined, size: 20, color: WhatsAppColors.subtitleText),
                SizedBox(width: 16),
                Text(
                  'Archived',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WhatsAppColors.titleText,
                  ),
                ),
                Spacer(),
                Text(
                  '30',
                  style: TextStyle(fontSize: 12, color: WhatsAppColors.subtitleText),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 64, color: WhatsAppColors.searchBarBg),

          // Chat items list
          Expanded(
            child: ListView.separated(
              itemCount: _chats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return _buildChatItem(chat);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: WhatsAppColors.fabBg,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false, Color? dotColor}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE7FCE3) : WhatsAppColors.chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? WhatsAppColors.primaryGreen : WhatsAppColors.chipBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? WhatsAppColors.darkGreen : WhatsAppColors.chipText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatItemModel chat) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE2E8F0),
              child: chat.isGroup
                  ? const Icon(Icons.group_rounded, color: Color(0xFF64748B), size: 24)
                  : Text(
                      chat.title.isNotEmpty ? chat.title[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: WhatsAppColors.titleText,
                          ),
                        ),
                      ),
                      Text(
                        chat.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: WhatsAppColors.timeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.isPinned) ...[
                        const Icon(Icons.done_all, size: 16, color: WhatsAppColors.checkBlue),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          (chat.senderPrefix != null ? '${chat.senderPrefix}: ' : '') + chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: WhatsAppColors.subtitleText,
                          ),
                        ),
                      ),
                      if (chat.isPinned)
                        const Icon(Icons.push_pin, size: 16, color: WhatsAppColors.timeText),
                    ],
                  ),
                  if (chat.tag != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chat.tag!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
