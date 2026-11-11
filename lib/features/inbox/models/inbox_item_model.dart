class InboxItemModel {
  final int id;
  final String title;
  final String source;
  final String sourceLabel;
  final String status;
  final String createdAt;
  final String? subtitle;
  final bool isComplete;

  InboxItemModel({
    required this.id,
    required this.title,
    required this.source,
    required this.sourceLabel,
    required this.status,
    required this.createdAt,
    this.subtitle,
    this.isComplete = false,
  });

  factory InboxItemModel.fromJson(Map<String, dynamic> json) {
    return InboxItemModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Inbox Task',
      source: json['source'] as String? ?? 'general',
      sourceLabel: json['source_label'] as String? ?? json['source'] as String? ?? 'Task',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? 'Today',
      subtitle: json['description'] as String? ?? json['subtitle'] as String?,
      isComplete: json['is_complete'] as bool? ?? false,
    );
  }
}
