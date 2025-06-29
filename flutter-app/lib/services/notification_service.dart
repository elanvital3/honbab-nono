import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/meeting.dart';
import '../models/user.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  bool _isInitialized = false;
  String? _fcmToken;
  
  // 알림 채널 ID들
  static const String _newMeetingChannelId = 'new_meeting';
  static const String _chatChannelId = 'chat_message';
  static const String _reminderChannelId = 'meeting_reminder';
  static const String _participantChannelId = 'participant_update';

  /// 알림 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 알림 권한 요청
      await _requestPermissions();
      
      // 로컬 알림 초기화
      await _initializeLocalNotifications();
      
      // Firebase 메시징 초기화
      await _initializeFirebaseMessaging();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ NotificationService 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ NotificationService 초기화 실패: $e');
      }
    }
  }

  /// 알림 권한 요청
  Future<bool> _requestPermissions() async {
    if (Platform.isIOS) {
      // iOS 알림 권한 요청
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      if (kDebugMode) {
        print('iOS 알림 권한 상태: ${settings.authorizationStatus}');
      }
      
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } else {
      // Android 알림 권한 요청
      final status = await Permission.notification.request();
      
      if (kDebugMode) {
        print('Android 알림 권한 상태: $status');
      }
      
      return status == PermissionStatus.granted;
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    // Android 초기화 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 초기화 설정
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Android 알림 채널 생성
  Future<void> _createNotificationChannels() async {
    final channels = [
      // 새 모임 알림 채널
      const AndroidNotificationChannel(
        _newMeetingChannelId,
        '새 모임 알림',
        description: '내 근처에 새로운 모임이 생성될 때 알림',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      
      // 채팅 메시지 채널
      const AndroidNotificationChannel(
        _chatChannelId,
        '채팅 메시지',
        description: '참여한 모임의 새 메시지 알림',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      
      // 모임 리마인더 채널
      const AndroidNotificationChannel(
        _reminderChannelId,
        '모임 리마인더',
        description: '참여한 모임 시작 전 알림',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
      
      // 참여자 업데이트 채널
      const AndroidNotificationChannel(
        _participantChannelId,
        '참여 알림',
        description: '모임 참여 승인/거절 및 참여자 변동사항 알림',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification'),
      ),
    ];
    
    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Firebase 메시징 초기화
  Future<void> _initializeFirebaseMessaging() async {
    // FCM 토큰 가져오기
    _fcmToken = await _firebaseMessaging.getToken();
    
    if (kDebugMode) {
      print('FCM 토큰: $_fcmToken');
    }
    
    // 토큰 갱신 리스너
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      if (kDebugMode) {
        print('FCM 토큰 갱신: $token');
      }
      // TODO: 서버에 새 토큰 전송
    });
    
    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // 백그라운드 메시지 처리
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  /// 포그라운드에서 받은 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('포그라운드 메시지 수신: ${message.notification?.title}');
    }
    
    // 방해금지 모드 체크
    if (await _isDoNotDisturbActive()) {
      if (kDebugMode) {
        print('방해금지 모드 활성화 - 알림 무시');
      }
      return;
    }
    
    // 사용자 설정에 따른 알림 표시
    await _showLocalNotification(message);
  }

  /// 백그라운드에서 앱을 연 메시지 처리
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('백그라운드 메시지로 앱 열림: ${message.notification?.title}');
    }
    
    // TODO: 메시지 타입에 따른 네비게이션 처리
  }

  /// 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    final messageType = message.data['type'] ?? '';
    String channelId = _newMeetingChannelId;
    
    // 메시지 타입에 따른 채널 선택
    switch (messageType) {
      case 'chat':
        channelId = _chatChannelId;
        break;
      case 'reminder':
        channelId = _reminderChannelId;
        break;
      case 'participant':
        channelId = _participantChannelId;
        break;
      default:
        channelId = _newMeetingChannelId;
    }
    
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// 새 모임 알림 (로컬)
  Future<void> showNewMeetingNotification(Meeting meeting) async {
    if (!await _isNotificationEnabled('newMeetingNotification')) return;
    if (await _isDoNotDisturbActive()) return;
    
    const androidDetails = AndroidNotificationDetails(
      _newMeetingChannelId,
      '새 모임 알림',
      channelDescription: '내 근처에 새로운 모임이 생성될 때 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      meeting.hashCode,
      '🍽️ 새로운 모임이 생성되었어요!',
      '${meeting.restaurantName ?? meeting.location}에서 함께 식사하실래요?',
      details,
      payload: 'meeting:${meeting.id}',
    );
  }

  /// 채팅 메시지 알림 (로컬)
  Future<void> showChatNotification(String meetingTitle, String senderName, String message) async {
    if (!await _isNotificationEnabled('chatNotification')) return;
    if (await _isDoNotDisturbActive()) return;
    
    const androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      '채팅 메시지',
      channelDescription: '참여한 모임의 새 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '$meetingTitle',
      '$senderName: $message',
      details,
      payload: 'chat:$meetingTitle',
    );
  }

  /// 모임 리마인더 알림 예약
  Future<void> scheduleMeetingReminder(Meeting meeting) async {
    if (!await _isNotificationEnabled('meetingReminderNotification')) return;
    
    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes = prefs.getInt('reminderMinutes') ?? 60;
    
    final reminderTime = meeting.dateTime.subtract(Duration(minutes: reminderMinutes));
    
    // 과거 시간이면 예약하지 않음
    if (reminderTime.isBefore(DateTime.now())) return;
    
    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      '모임 리마인더',
      channelDescription: '참여한 모임 시작 전 알림',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.zonedSchedule(
      meeting.hashCode + 1000, // 유니크한 ID
      '⏰ 곧 모임 시간이에요!',
      '${meeting.restaurantName ?? meeting.location}에서 ${_getReminderText(reminderMinutes)} 후 모임이 시작됩니다.',
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      payload: 'reminder:${meeting.id}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 참여자 업데이트 알림
  Future<void> showParticipantNotification(String title, String body) async {
    if (!await _isNotificationEnabled('participantNotification')) return;
    if (await _isDoNotDisturbActive()) return;
    
    const androidDetails = AndroidNotificationDetails(
      _participantChannelId,
      '참여 알림',
      channelDescription: '모임 참여 승인/거절 및 참여자 변동사항 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  /// 알림 탭 처리
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    
    if (kDebugMode) {
      print('알림 탭됨: $payload');
    }
    
    // TODO: payload에 따른 네비게이션 처리
    // 예: meeting:123 -> 모임 상세 화면으로 이동
    // 예: chat:모임명 -> 채팅방으로 이동
  }

  /// 특정 알림 타입이 활성화되어 있는지 확인
  Future<bool> _isNotificationEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  /// 방해금지 모드가 활성화되어 있는지 확인
  Future<bool> _isDoNotDisturbActive() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('doNotDisturbEnabled') ?? false;
    
    if (!isEnabled) return false;
    
    final now = TimeOfDay.now();
    final startHour = prefs.getInt('doNotDisturbStartHour') ?? 22;
    final startMinute = prefs.getInt('doNotDisturbStartMinute') ?? 0;
    final endHour = prefs.getInt('doNotDisturbEndHour') ?? 8;
    final endMinute = prefs.getInt('doNotDisturbEndMinute') ?? 0;
    
    final start = TimeOfDay(hour: startHour, minute: startMinute);
    final end = TimeOfDay(hour: endHour, minute: endMinute);
    
    return _isTimeInRange(now, start, end);
  }

  /// 시간이 범위 안에 있는지 확인 (다음날 넘어가는 경우 고려)
  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    if (startMinutes <= endMinutes) {
      // 같은 날 범위 (예: 10:00 - 18:00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // 다음날 넘어가는 범위 (예: 22:00 - 08:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  /// 채널 이름 반환
  String _getChannelName(String channelId) {
    switch (channelId) {
      case _newMeetingChannelId:
        return '새 모임 알림';
      case _chatChannelId:
        return '채팅 메시지';
      case _reminderChannelId:
        return '모임 리마인더';
      case _participantChannelId:
        return '참여 알림';
      default:
        return '일반 알림';
    }
  }

  /// 채널 설명 반환
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _newMeetingChannelId:
        return '내 근처에 새로운 모임이 생성될 때 알림';
      case _chatChannelId:
        return '참여한 모임의 새 메시지 알림';
      case _reminderChannelId:
        return '참여한 모임 시작 전 알림';
      case _participantChannelId:
        return '모임 참여 승인/거절 및 참여자 변동사항 알림';
      default:
        return '일반 알림';
    }
  }

  /// 리마인더 시간 텍스트 반환
  String _getReminderText(int minutes) {
    if (minutes == 30) return '30분';
    if (minutes == 60) return '1시간';
    if (minutes == 120) return '2시간';
    if (minutes == 1440) return '하루';
    return '$minutes분';
  }

  /// FCM 토큰 반환
  String? get fcmToken => _fcmToken;

  /// 초기화 상태 반환
  bool get isInitialized => _isInitialized;

  /// 모든 예약된 알림 취소
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// 특정 모임의 알림 취소
  Future<void> cancelMeetingNotifications(Meeting meeting) async {
    await _localNotifications.cancel(meeting.hashCode); // 새 모임 알림
    await _localNotifications.cancel(meeting.hashCode + 1000); // 리마인더 알림
  }
}