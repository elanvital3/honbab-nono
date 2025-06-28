import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String meetingId;
  final String senderId;
  final String senderName;
  final String? senderProfileImage;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.meetingId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
    required this.content,
    this.type = MessageType.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      meetingId: data['meetingId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderProfileImage: data['senderProfileImage'],
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}',
        orElse: () => MessageType.text,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileImage': senderProfileImage,
      'content': content,
      'type': type.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  Message copyWith({
    String? id,
    String? meetingId,
    String? senderId,
    String? senderName,
    String? senderProfileImage,
    String? content,
    MessageType? type,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileImage: senderProfileImage ?? this.senderProfileImage,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${createdAt.month}/${createdAt.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  String get shortTime {
    return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

enum MessageType {
  text,
  system,  // 시스템 메시지 (입장/퇴장 알림 등)
  image,   // 이미지 (추후 구현)
}