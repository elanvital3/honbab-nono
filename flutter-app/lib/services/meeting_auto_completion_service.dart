import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/meeting.dart';
import 'auth_service.dart';

class MeetingAutoCompletionService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // 알림 초기화
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _isInitialized = true;
    
    if (kDebugMode) {
      print('✅ 모임 자동 완료 알림 서비스 초기화 완료');
    }
  }

  // 알림 클릭 시 콜백
  static void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 모임 자동 완료 알림 클릭: ${response.payload}');
    }
    // TODO: 앱이 백그라운드에 있을 때 알림 클릭 시 해당 모임 상세 페이지로 이동
  }

  // 모임 생성/참여 시 자동 완료 알림 예약
  static Future<void> scheduleMeetingAutoCompletion(Meeting meeting) async {
    final currentUserId = AuthService.currentUser?.uid;
    if (currentUserId == null) return;

    // 호스트만 자동 완료 알림 받음
    if (meeting.hostId != currentUserId) return;

    await initialize();

    // 모임 시간 + 2시간 후 알림 시간 계산
    final notificationTime = meeting.dateTime.add(const Duration(hours: 2));
    
    // 과거 시간이면 알림 설정 안 함
    if (notificationTime.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('⏰ 모임 시간이 이미 지나서 자동 완료 알림 설정 안 함: ${meeting.id}');
      }
      return;
    }

    final notificationId = _generateNotificationId(meeting.id);

    // 로컬 알림 예약
    await _notifications.zonedSchedule(
      notificationId,
      '모임 시간이 지났습니다',
      '${meeting.restaurantName ?? meeting.location} 모임을 완료해주세요',
      _convertToTZDateTime(notificationTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meeting_auto_complete',
          '모임 자동 완료',
          channelDescription: '모임 시간 후 자동 완료 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'auto_complete:${meeting.id}',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
    await _notifications.cancel(notificationId);

    // SharedPreferences에서 기록 삭제
    await _removeScheduledNotification(meetingId);

    if (kDebugMode) {
      print('⏰ 모임 자동 완료 알림 취소: $meetingId');
    }
  }

  // 1시간 후 재알림 예약
  static Future<void> postponeMeetingAutoCompletion(String meetingId, String meetingName) async {
    await initialize();

    final notificationId = _generateNotificationId(meetingId);
    final postponedTime = DateTime.now().add(const Duration(hours: 1));

    await _notifications.zonedSchedule(
      notificationId,
      '모임 완료 재알림',
      '$meetingName 모임을 완료해주세요',
      _convertToTZDateTime(postponedTime),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meeting_auto_complete',
          '모임 자동 완료',
          channelDescription: '모임 시간 후 자동 완료 알림',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'auto_complete:$meetingId',
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _saveScheduledNotification(meetingId, postponedTime);

    if (kDebugMode) {
      print('⏰ 모임 자동 완료 알림 1시간 후 재예약: $meetingId');
    }
  }

  // 모임 ID를 알림 ID로 변환 (해시)
  static int _generateNotificationId(String meetingId) {
    return meetingId.hashCode.abs() % 2147483647; // int 최대값 이하로 제한
  }

  // DateTime을 TZDateTime으로 변환 (로컬 타임존)
  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    final seoul = tz.getLocation('Asia/Seoul');
    return tz.TZDateTime.from(dateTime, seoul);
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
    await _notifications.cancelAll();
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('meeting_notification_'));
    for (final key in keys) {
      await prefs.remove(key);
    }

    if (kDebugMode) {
      print('⏰ 모든 모임 자동 완료 알림 취소');
    }
  }
}