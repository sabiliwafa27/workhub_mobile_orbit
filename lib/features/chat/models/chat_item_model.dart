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
    final lastMsg = json['last_message'] as Map<String, dynamic>?;
    return ChatItemModel(
      id: json['customer_uuid'] as String? ?? json['id']?.toString() ?? '',
      title: json['customer_name'] as String? ?? json['name'] as String? ?? 'Discussion',
      lastMessage: lastMsg?['body'] as String? ?? 'No messages yet',
      time: '11:32',
      isPinned: json['is_pinned'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      tag: json['tag'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
    );
  }
}
