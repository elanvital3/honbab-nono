import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import 'notification_service.dart';
import 'meeting_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _messagesCollection = 'messages';

  // 메시지 전송
  static Future<String> sendMessage({
    required String meetingId,
    required String senderId,
    required String senderName,
    String? senderProfileImage,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      final message = Message(
        id: '', // Firestore에서 자동 생성
        meetingId: meetingId,
        senderId: senderId,
        senderName: senderName,
        senderProfileImage: senderProfileImage,
        content: content,
        type: type,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(_messagesCollection)
          .add(message.toFirestore());

      if (kDebugMode) {
        print('✅ 메시지 전송 성공: ${docRef.id}');
      }

      // 채팅 메시지 FCM 알림 발송 (발송자 제외)
      try {
        final meeting = await MeetingService.getMeeting(meetingId);
        if (meeting != null && type == MessageType.text) {
          await NotificationService().notifyChatMessage(
            meeting: meeting,
            senderUserId: senderId,
            senderName: senderName,
            message: content,
          );
          
          if (kDebugMode) {
            print('✅ 채팅 FCM 알림 발송 완료 (발송자 제외)');
          }
        }
      } catch (notificationError) {
        if (kDebugMode) {
          print('⚠️ 채팅 FCM 알림 발송 실패: $notificationError');
        }
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 메시지 전송 실패: $e');
      }
      rethrow;
    }
  }

  // 특정 모임의 메시지 스트림 가져오기
  static Stream<List<Message>> getMessagesStream(String meetingId) {
    return _firestore
        .collection(_messagesCollection)
        .where('meetingId', isEqualTo: meetingId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    });
  }

  // 최근 메시지 가져오기 (채팅방 리스트용)
  static Future<Message?> getLatestMessage(String meetingId) async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('meetingId', isEqualTo: meetingId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final message = Message.fromFirestore(snapshot.docs.first);
        return message;
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 최근 메시지 가져오기 실패: $e');
      }
      return null;
    }
  }

  // 안읽은 메시지 수 가져오기 (단순화된 버전)
  static Future<int> getUnreadMessageCount(String meetingId, String userId) async {
    try {
      // 단순화된 방식: 모든 메시지를 가져와서 클라이언트에서 필터링
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      int unreadCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final isRead = data['isRead'] as bool? ?? false;
        final messageType = data['type'] as String? ?? 'text';
        
        // 자신이 보낸 메시지가 아니고, 읽지 않은 메시지이며, 시스템 메시지가 아닌 경우
        if (senderId != userId && !isRead && messageType != 'system') {
          unreadCount++;
        }
      }
      
      return unreadCount;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 안읽은 메시지 수 가져오기 실패: $e');
      }
      return 0;
    }
  }

  // 안읽은 메시지 수 실시간 스트림 (개선된 버전)
  static Stream<int> getUnreadMessageCountStream(String meetingId, String userId) {
    return _firestore
        .collection(_messagesCollection)
        .where('meetingId', isEqualTo: meetingId)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final isRead = data['isRead'] as bool? ?? false;
        final messageType = data['type'] as String? ?? 'text';
        
        // 자신이 보낸 메시지가 아니고, 읽지 않은 메시지이며, 시스템 메시지가 아닌 경우
        if (senderId != userId && !isRead && messageType != 'system') {
          count++;
        }
      }
      
      if (kDebugMode) {
        print('📊 안읽은 메시지 카운트 (모임 $meetingId): $count');
      }
      
      return count;
    }).distinct(); // 중복 제거
  }

  // 최근 메시지 실시간 스트림 (최적화된 버전)
  static Stream<Message?> getLatestMessageStream(String meetingId) {
    return _firestore
        .collection(_messagesCollection)
        .where('meetingId', isEqualTo: meetingId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Message.fromFirestore(snapshot.docs.first);
      } else {
        return null;
      }
    }).distinct((prev, next) {
      // 메시지 ID와 내용이 같으면 중복으로 간주
      return prev?.id == next?.id && prev?.content == next?.content;
    });
  }

  // 메시지 읽음 처리 (단순화된 버전)
  static Future<void> markMessagesAsRead(String meetingId, String userId) async {
    try {
      // 단순화된 방식: 모든 메시지를 가져와서 클라이언트에서 필터링
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      final batch = _firestore.batch();
      int updateCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String;
        final isRead = data['isRead'] as bool? ?? false;
        
        // 자신이 보낸 메시지가 아니고 읽지 않은 메시지인 경우만 업데이트
        if (senderId != userId && !isRead) {
          batch.update(doc.reference, {'isRead': true});
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
      }

      if (kDebugMode) {
        print('✅ 메시지 읽음 처리 완료: ${updateCount}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 메시지 읽음 처리 실패: $e');
      }
    }
  }

  // 시스템 메시지 전송 (입장/퇴장 알림)
  static Future<void> sendSystemMessage({
    required String meetingId,
    required String content,
  }) async {
    try {
      await sendMessage(
        meetingId: meetingId,
        senderId: 'system',
        senderName: '시스템',
        content: content,
        type: MessageType.system,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 시스템 메시지 전송 실패: $e');
      }
    }
  }

  // 메시지 삭제 (호스트 권한)
  static Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection(_messagesCollection).doc(messageId).delete();
      
      if (kDebugMode) {
        print('✅ 메시지 삭제 완료: $messageId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 메시지 삭제 실패: $e');
      }
      rethrow;
    }
  }

  // 모임의 모든 메시지 삭제 (모임 삭제 시)
  static Future<void> deleteAllMessages(String meetingId) async {
    try {
      final snapshot = await _firestore
          .collection(_messagesCollection)
          .where('meetingId', isEqualTo: meetingId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('✅ 모임의 모든 메시지 삭제 완료: ${snapshot.docs.length}개');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 메시지 삭제 실패: $e');
      }
    }
  }
}