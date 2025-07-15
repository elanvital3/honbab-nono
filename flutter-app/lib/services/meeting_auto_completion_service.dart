import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class MeetingAutoCompletionService {
  static bool _isInitialized = false;

  // 알림 초기화 - NotificationService를 사용하도록 변경
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // NotificationService를 통해 초기화 (콜백 충돌 방지)
    await NotificationService().initialize();

    _isInitialized = true;
    
    if (kDebugMode) {
      print('✅ 모임 자동 완료 알림 서비스 초기화 완료 (NotificationService 통합)');
    }
  }

  // 모임 생성/참여 시 자동 완료 알림 예약
  static Future<void> scheduleMeetingAutoCompletion(Meeting meeting) async {
    final currentUserId = AuthService.currentUser?.uid;
    if (currentUserId == null) return;

    // 호스트만 자동 완료 알림 받음
    if (meeting.hostId != currentUserId) return;

    await initialize();

    // 🧪 테스트용: 모임 시간 + 5분 후 알림 시간 계산 (원래: 2시간)
    final notificationTime = meeting.dateTime.add(const Duration(minutes: 5));
    
    // 과거 시간이면 알림 설정 안 함
    if (notificationTime.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('⏰ 모임 시간이 이미 지나서 자동 완료 알림 설정 안 함: ${meeting.id}');
      }
      return;
    }

    final notificationId = _generateNotificationId(meeting.id);

    // NotificationService를 통해 알림 예약
    await NotificationService().scheduleNotification(
      id: notificationId,
      title: '모임 시간이 지났습니다',
      body: '${meeting.restaurantName ?? meeting.location} 모임을 완료해주세요',
      scheduledTime: notificationTime,
      payload: 'auto_complete:${meeting.id}',
      channelId: 'meeting_auto_complete',
    );

    // SharedPreferences에 알림 설정 기록
    await _saveScheduledNotification(meeting.id, notificationTime);

    if (kDebugMode) {
      print('⏰ 모임 자동 완료 알림 예약: ${meeting.id} (${notificationTime.toString()})');
    }
  }

  // 모임 완료/삭제 시 예약된 알림 취소
  static Future<void> cancelMeetingAutoCompletion(String meetingId) async {
    await initialize();

    final notificationId = _generateNotificationId(meetingId);
    await NotificationService().cancelScheduledNotification(notificationId);

    // SharedPreferences에서 기록 삭제
    await _removeScheduledNotification(meetingId);

    if (kDebugMode) {
      print('⏰ 모임 자동 완료 알림 취소: $meetingId');
    }
  }

  // 지정된 시간 후 재알림 예약
  static Future<void> postponeMeetingAutoCompletion(String meetingId, String meetingName, {int delayHours = 1}) async {
    await initialize();

    final notificationId = _generateNotificationId(meetingId);
    final postponedTime = DateTime.now().add(Duration(hours: delayHours));

    await NotificationService().scheduleNotification(
      id: notificationId,
      title: '모임 완료 재알림',
      body: '$meetingName 모임을 완료해주세요',
      scheduledTime: postponedTime,
      payload: 'auto_complete:$meetingId',
      channelId: 'meeting_auto_complete',
    );

    await _saveScheduledNotification(meetingId, postponedTime);

    if (kDebugMode) {
      print('⏰ 모임 자동 완료 알림 ${delayHours}시간 후 재예약: $meetingId');
    }
  }

  // 모임 ID를 알림 ID로 변환 (해시)
  static int _generateNotificationId(String meetingId) {
    return meetingId.hashCode.abs() % 2147483647; // int 최대값 이하로 제한
  }

  // 예약된 알림 정보 저장
  static Future<void> _saveScheduledNotification(String meetingId, DateTime scheduledTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meeting_notification_$meetingId', scheduledTime.toIso8601String());
  }

  // 예약된 알림 정보 삭제
  static Future<void> _removeScheduledNotification(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('meeting_notification_$meetingId');
  }

  // 예약된 알림 목록 조회 (디버깅용)
  static Future<Map<String, DateTime>> getScheduledNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('meeting_notification_'));
    
    final notifications = <String, DateTime>{};
    for (final key in keys) {
      final meetingId = key.replaceFirst('meeting_notification_', '');
      final timeString = prefs.getString(key);
      if (timeString != null) {
        notifications[meetingId] = DateTime.parse(timeString);
      }
    }
    
    return notifications;
  }

  // 모든 예약된 알림 취소 (앱 종료 시 등)
  static Future<void> cancelAllScheduledNotifications() async {
    await initialize();
    
    // 개별적으로 알림 취소 (NotificationService를 통해)
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('meeting_notification_'));
    for (final key in keys) {
      final meetingId = key.replaceFirst('meeting_notification_', '');
      final notificationId = _generateNotificationId(meetingId);
      await NotificationService().cancelScheduledNotification(notificationId);
      await prefs.remove(key);
    }

    if (kDebugMode) {
      print('⏰ 모든 모임 자동 완료 알림 취소');
    }
  }
}