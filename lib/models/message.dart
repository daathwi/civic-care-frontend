import 'package:intl/intl.dart';

class InternalMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String? senderName;

  InternalMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.senderName,
  });

  factory InternalMessage.fromMap(Map<String, dynamic> map) {
    return InternalMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      receiverId: map['receiver_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at']).toLocal()
          : DateTime.now(),
      senderName: map['sender_name']?.toString(),
    );
  }

  String get timeFormatted => DateFormat('h:mm a').format(createdAt);
  String get dateFormatted => DateFormat('MMM d').format(createdAt);
}

class ConversationMember {
  final String id;
  final String name;
  final String role;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ConversationMember({
    required this.id,
    required this.name,
    required this.role,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationMember.fromMap(Map<String, dynamic> map) {
    return ConversationMember(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown',
      role: map['role']?.toString() ?? '',
      lastMessage: map['last_message'],
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.parse(map['last_message_time']).toLocal()
          : null,
      unreadCount: map['unread_count'] ?? 0,
    );
  }

  String get lastTimeFormatted {
    if (lastMessageTime == null) return '';
    final now = DateTime.now();
    if (lastMessageTime!.year == now.year &&
        lastMessageTime!.month == now.month &&
        lastMessageTime!.day == now.day) {
      return DateFormat('h:mm a').format(lastMessageTime!);
    }
    return DateFormat('MMM d').format(lastMessageTime!);
  }
}
