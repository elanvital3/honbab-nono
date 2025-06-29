import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../../services/meeting_service.dart';
import '../../models/meeting.dart';

class FCMTestScreen extends StatefulWidget {
  const FCMTestScreen({super.key});

  @override
  State<FCMTestScreen> createState() => _FCMTestScreenState();
}

class _FCMTestScreenState extends State<FCMTestScreen> {
  final NotificationService _notificationService = NotificationService();
  String _fcmToken = '';
  String _status = '알림 서비스 초기화 중...';

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      setState(() {
        _status = 'FCM 초기화 중...';
      });

      await _notificationService.initialize();
      final token = _notificationService.fcmToken;
      
      setState(() {
        _fcmToken = token ?? '토큰 없음';
        _status = _notificationService.isInitialized ? 'FCM 초기화 완료' : 'FCM 초기화 실패';
      });

      if (kDebugMode) {
        print('✅ FCM 테스트 화면에서 초기화 완료');
        print('🔑 FCM 토큰: ${token?.substring(0, 50)}...');
      }
    } catch (e) {
      setState(() {
        _status = 'FCM 초기화 실패: $e';
      });
      if (kDebugMode) {
        print('❌ FCM 테스트 화면 초기화 실패: $e');
      }
    }
  }

  Future<void> _saveFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = '로그인된 사용자가 없습니다';
        });
        return;
      }

      await _notificationService.saveFCMTokenToFirestore(user.uid);
      setState(() {
        _status = 'FCM 토큰 저장 완료';
      });
      
      if (kDebugMode) {
        print('✅ FCM 토큰 수동 저장 완료');
      }
    } catch (e) {
      setState(() {
        _status = 'FCM 토큰 저장 실패: $e';
      });
      if (kDebugMode) {
        print('❌ FCM 토큰 저장 실패: $e');
      }
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.showParticipantNotification(
        '🧪 FCM 테스트',
        '이것은 FCM 기능 테스트 알림입니다.',
      );
      
      setState(() {
        _status = '테스트 알림 발송 완료';
      });
      
      if (kDebugMode) {
        print('✅ 테스트 알림 발송 완료');
      }
    } catch (e) {
      setState(() {
        _status = '테스트 알림 발송 실패: $e';
      });
      if (kDebugMode) {
        print('❌ 테스트 알림 발송 실패: $e');
      }
    }
  }

  Future<void> _testMultiUserNotification() async {
    try {
      setState(() {
        _status = '멀티유저 알림 테스트 중...';
      });

      // 가상의 참여자 ID들
      final participantIds = ['user1', 'user2', 'user3', 'current_user'];
      
      await _notificationService.notifyAllParticipants(
        participantIds: participantIds,
        excludeUserId: 'current_user',
        title: '🧪 멀티유저 테스트',
        body: '이것은 멀티유저 FCM 알림 테스트입니다.',
        type: 'test',
      );
      
      setState(() {
        _status = '멀티유저 알림 테스트 완료 (3명에게 발송 시도)';
      });
      
      if (kDebugMode) {
        print('✅ 멀티유저 알림 테스트 완료');
      }
    } catch (e) {
      setState(() {
        _status = '멀티유저 알림 테스트 실패: $e';
      });
      if (kDebugMode) {
        print('❌ 멀티유저 알림 테스트 실패: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM 테스트'),
        backgroundColor: const Color(0xFFD2B48C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM 상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FCM 토큰',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _fcmToken.isNotEmpty 
                          ? '${_fcmToken.substring(0, _fcmToken.length > 50 ? 50 : _fcmToken.length)}...'
                          : '토큰 없음',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'FCM 기능 테스트',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveFCMToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2B48C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('FCM 토큰 저장'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendTestNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('로컬 알림 테스트'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _testMultiUserNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('멀티유저 알림 테스트'),
              ),
            ),
            const Spacer(),
            const Card(
              color: Color(0xFFFFF3E0),
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 FCM 테스트 안내',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• FCM 토큰 저장: 현재 사용자의 FCM 토큰을 Firestore에 저장\n'
                      '• 로컬 알림 테스트: 단일 로컬 알림 발송\n'
                      '• 멀티유저 알림 테스트: 여러 사용자에게 FCM 알림 발송 시뮬레이션',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}