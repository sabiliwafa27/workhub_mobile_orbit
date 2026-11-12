class ChatItemModel {
  final String id;
  final String title;
  final String lastMessage;
  final String time;
  final String? avatarUrl;
  final bool isPinned;
  final bool isRead;
  final int unreadCount;
  final String? tag; // e.g. "WORKING", "Follow up"
  final bool isGroup;
  final String? senderPrefix;

  ChatItemModel({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.time,
    this.avatarUrl,
    this.isPinned = false,
    this.isRead = true,
    this.unreadCount = 0,
    this.tag,
    this.isGroup = false,
    this.senderPrefix,
  });

  factory ChatItemModel.fromJson(Map<String, dynamic> json) {
    final latestComment = json['latest_comment'] as Map<String, dynamic>?;
    final lastMsg = json['last_message'] as Map<String, dynamic>?;

    String preview = 'No messages yet';
    if (latestComment != null && latestComment['preview'] != null) {
      preview = latestComment['preview'] as String;
    } else if (lastMsg != null && lastMsg['body'] != null) {
      preview = lastMsg['body'] as String;
    } else if (json['has_conversation'] == true) {
      preview = 'Active discussion';
    }

    final author = latestComment?['author'] as String? ?? lastMsg?['sender_name'] as String?;
    final rawDate = latestComment?['created_at'] as String? ?? json['updated_at'] as String?;

    return ChatItemModel(
      id: json['customer_uuid'] as String? ?? json['id']?.toString() ?? '',
      title: json['customer_name'] as String? ?? json['name'] as String? ?? 'Discussion',
      lastMessage: preview,
      time: _formatTime(rawDate),
      isPinned: json['is_pinned'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      tag: json['tag'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      senderPrefix: author,
    );
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'Today';
    try {
      final dt = DateTime.parse(raw);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '$hour:$min';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return raw.length > 5 ? raw.substring(raw.length - 5) : raw;
    }
  }
}
