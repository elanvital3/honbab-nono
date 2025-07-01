import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_functions/cloud_functions.dart';
import '../models/meeting.dart';
import 'user_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      final notificationStatus = await Permission.notification.request();
      
      if (kDebugMode) {
        print('Android 알림 권한 상태: $notificationStatus');
      }
      
      // Android 12+ 정확한 알람 권한 요청
      try {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
        if (kDebugMode) {
          print('Android 정확한 알람 권한 상태: $exactAlarmStatus');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 정확한 알람 권한 요청 실패 (구버전 안드로이드일 수 있음): $e');
        }
      }
      
      return notificationStatus == PermissionStatus.granted;
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
    _firebaseMessaging.onTokenRefresh.listen((token) async {
      if (kDebugMode) {
        print('FCM 토큰 갱신됨: ${token.substring(0, 20)}...');
      }
      
      // 현재 로그인된 사용자가 있다면 토큰 업데이트
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await updateFCMToken(currentUser.uid, token);
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ 토큰 갱신 중 오류: $e');
        }
      }
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
    
    final details = NotificationDetails(
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

  /// 근처 사용자들에게 새 모임 생성 알림 발송
  Future<void> notifyNearbyUsersOfNewMeeting(Meeting meeting) async {
    try {
      // 모임 생성자의 위치 정보 조회
      final hostUser = await UserService.getUser(meeting.hostId);
      if (hostUser?.lastLatitude == null || hostUser?.lastLongitude == null) {
        if (kDebugMode) {
          print('⚠️ 호스트의 위치 정보가 없어서 근처 알림을 건너뜁니다');
        }
        return;
      }

      // 5km 반경 내 사용자들의 FCM 토큰 조회
      final nearbyTokens = await UserService.getNearbyUserTokens(
        centerLatitude: hostUser!.lastLatitude!,
        centerLongitude: hostUser.lastLongitude!,
        radiusKm: 5.0,
        excludeUserId: meeting.hostId, // 모임 생성자 제외
        maxResults: 100,
      );

      if (nearbyTokens.isEmpty) {
        if (kDebugMode) {
          print('📭 근처에 알림 받을 사용자가 없습니다');
        }
        return;
      }

      // Firebase Functions를 통해 실제 FCM 알림 발송
      await sendRealFCMMulticast(
        tokens: nearbyTokens,
        title: '🍽️ 근처에 새로운 모임이 생성되었어요!',
        body: '${meeting.restaurantName ?? meeting.location}에서 함께 식사하실래요?',
        type: 'new_meeting',
        meetingId: meeting.id,
        channelId: _newMeetingChannelId,
      );

      if (kDebugMode) {
        print('✅ 근처 사용자 ${nearbyTokens.length}명에게 새 모임 알림 발송 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 근처 모임 알림 발송 실패: $e');
      }
    }
  }

  /// 새 모임 알림 (로컬) - 기존 유지
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
    
    final details = NotificationDetails(
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
    
    final details = NotificationDetails(
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
    
    // 정확한 알람 권한 확인 (Android 12+)
    if (Platform.isAndroid) {
      try {
        // 안드로이드 정확한 알람 권한 확인
        final exactAlarmPermission = await Permission.scheduleExactAlarm.status;
        if (kDebugMode) {
          print('정확한 알람 권한 상태: $exactAlarmPermission');
        }
        
        if (exactAlarmPermission != PermissionStatus.granted) {
          if (kDebugMode) {
            print('⚠️ 정확한 알람 권한이 없어서 리마인더 스케줄을 건너뜁니다');
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 정확한 알람 권한 확인 실패: $e');
        }
        // 권한 확인 실패 시에도 시도해봅니다
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes = prefs.getInt('reminderMinutes') ?? 60;
    
    final reminderTime = meeting.dateTime.subtract(Duration(minutes: reminderMinutes));
    
    // 과거 시간이면 예약하지 않음
    if (reminderTime.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('⚠️ 리마인더 시간이 과거이므로 예약하지 않습니다: $reminderTime');
      }
      return;
    }
    
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
    
    final details = NotificationDetails(
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
    
    final details = NotificationDetails(
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

  /// 모임 신청 알림 (호스트에게)
  Future<void> notifyMeetingApplication({
    required Meeting meeting,
    required String applicantUserId,
    required String applicantName,
  }) async {
    try {
      if (kDebugMode) {
        print('📬 모임 신청 알림 발송 시작: ${meeting.id}');
      }

      // 호스트의 FCM 토큰 조회
      final hostUser = await UserService.getUser(meeting.hostId);
      if (kDebugMode) {
        print('🔍 호스트 정보 조회 결과:');
        print('  - 호스트 ID: ${meeting.hostId}');
        print('  - 사용자 존재: ${hostUser != null}');
        print('  - FCM 토큰: ${hostUser?.fcmToken?.substring(0, 20) ?? '없음'}...');
      }
      
      if (hostUser?.fcmToken == null) {
        if (kDebugMode) {
          print('❌ 호스트 FCM 토큰 없음: ${meeting.hostId}');
        }
        return;
      }

      final title = '🙋‍♀️ 새로운 참여 신청';
      final body = '$applicantName님이 "${meeting.description}" 모임에 참여 신청했습니다';

      // 임시로 로컬 알림으로 대체 (FCM Functions 문제 해결용)
      try {
        await sendRealFCMMessage(
          targetToken: hostUser!.fcmToken!,
          title: title,
          body: body,
          type: 'meeting_application',
          meetingId: meeting.id,
          channelId: _participantChannelId,
          customData: {
            'applicantId': applicantUserId,
            'clickAction': 'MEETING_DETAIL',
          },
        );
      } catch (fcmError) {
        if (kDebugMode) {
          print('⚠️ FCM 발송 실패, 로컬 알림으로 대체: $fcmError');
        }
        // 로컬 알림으로 대체
        await showTestNotification(title, body);
      }

      if (kDebugMode) {
        print('✅ 모임 신청 알림 발송 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 신청 알림 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 모임 신청 승인 알림 (신청자에게)
  Future<void> notifyMeetingApproval({
    required Meeting meeting,
    required String applicantUserId,
    required String applicantName,
  }) async {
    try {
      if (kDebugMode) {
        print('🎉 모임 승인 알림 발송 시작: ${meeting.id}');
      }

      // 신청자의 FCM 토큰 조회
      final applicantUser = await UserService.getUser(applicantUserId);
      if (applicantUser?.fcmToken == null) {
        if (kDebugMode) {
          print('❌ 신청자 FCM 토큰 없음: $applicantUserId');
        }
        return;
      }

      final title = '🎉 참여 승인 완료!';
      final body = '"${meeting.description}" 모임 참여가 승인되었습니다. 채팅방에 입장하세요!';

      await sendRealFCMMessage(
        targetToken: applicantUser!.fcmToken!,
        title: title,
        body: body,
        type: 'meeting_approval',
        meetingId: meeting.id,
        channelId: _participantChannelId,
        customData: {
          'clickAction': 'MEETING_DETAIL',
        },
      );

      if (kDebugMode) {
        print('✅ 모임 승인 알림 발송 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 승인 알림 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 모임 신청 거절 알림 (신청자에게)
  Future<void> notifyMeetingRejection({
    required Meeting meeting,
    required String applicantUserId,
    required String applicantName,
  }) async {
    try {
      if (kDebugMode) {
        print('😔 모임 거절 알림 발송 시작: ${meeting.id}');
      }

      // 신청자의 FCM 토큰 조회
      final applicantUser = await UserService.getUser(applicantUserId);
      if (applicantUser?.fcmToken == null) {
        if (kDebugMode) {
          print('❌ 신청자 FCM 토큰 없음: $applicantUserId');
        }
        return;
      }

      final title = '😔 참여 신청이 거절되었습니다';
      final body = '"${meeting.description}" 모임 참여 신청이 거절되었습니다. 다른 모임을 찾아보세요!';

      await sendRealFCMMessage(
        targetToken: applicantUser!.fcmToken!,
        title: title,
        body: body,
        type: 'meeting_rejection',
        meetingId: meeting.id,
        channelId: _participantChannelId,
        customData: {
          'clickAction': 'HOME',
        },
      );

      if (kDebugMode) {
        print('✅ 모임 거절 알림 발송 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 거절 알림 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 범용 로컬 알림 표시 (테스트용)
  Future<void> showTestNotification(String title, String body, {String? channelId}) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? _participantChannelId,
        '테스트 알림',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
      
      if (kDebugMode) {
        print('✅ 테스트 알림 표시 완료: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 테스트 알림 표시 실패: $e');
      }
      rethrow;
    }
  }

  /// 실제 모임 알림 강제 테스트 (디버그용)
  Future<void> testRealMeetingNotification() async {
    try {
      // 현재 사용자의 FCM 토큰으로 테스트
      if (_fcmToken == null) {
        print('❌ FCM 토큰 없음 - 초기화 필요');
        return;
      }

      print('🧪 실제 모임 알림 테스트 시작');
      
      await sendRealFCMMessage(
        targetToken: _fcmToken!,
        title: '🧪 모임 신청 테스트',
        body: '테스트님이 "맛집 탐방" 모임에 참여 신청했습니다',
        type: 'meeting_application',
        meetingId: 'test_meeting_id',
        channelId: _participantChannelId,
        customData: {
          'applicantId': 'test_user_id',
          'clickAction': 'MEETING_DETAIL',
        },
      );
      
      print('✅ 실제 모임 알림 테스트 완료');
    } catch (e) {
      print('❌ 실제 모임 알림 테스트 실패: $e');
    }
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

  /// 모든 참여자에게 알림 발송 (FCM)
  Future<void> notifyAllParticipants({
    required List<String> participantIds,
    required String excludeUserId,
    required String title,
    required String body,
    String? type,
    Map<String, String>? data,
  }) async {
    try {
      if (kDebugMode) {
        print('🔔 모든 참여자에게 알림 발송 시작');
        print('📝 참여자 ID들: $participantIds');
        print('🚫 제외할 사용자: $excludeUserId');
      }

      // 제외할 사용자를 제외한 참여자 목록
      final targetParticipants = participantIds.where((id) => id != excludeUserId).toList();
      
      if (targetParticipants.isEmpty) {
        if (kDebugMode) {
          print('📭 알림을 받을 참여자가 없습니다');
        }
        return;
      }

      // 참여자들의 FCM 토큰 가져오기
      final fcmTokens = await _getFCMTokensForUsers(targetParticipants);
      
      if (fcmTokens.isEmpty) {
        if (kDebugMode) {
          print('📭 유효한 FCM 토큰이 없습니다');
        }
        return;
      }

      // FCM 메시지 구성
      final messageData = <String, String>{
        'type': type ?? 'general',
        'title': title,
        'body': body,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...?data,
      };

      // 각 토큰으로 개별 발송 (배치 발송은 Firebase Functions에서 처리)
      for (final token in fcmTokens) {
        await _sendSingleFCMMessage(
          token: token,
          title: title,
          body: body,
          data: messageData,
        );
      }

      if (kDebugMode) {
        print('✅ ${fcmTokens.length}명의 참여자에게 알림 발송 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 참여자 알림 발송 실패: $e');
      }
    }
  }

  /// 사용자들의 FCM 토큰 가져오기 (단순화된 버전 - users 문서에서 직접 조회)
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds) async {
    try {
      final tokens = <String>[];
      
      if (kDebugMode) {
        print('🔍 단순화된 FCM 토큰 조회 시작 - 대상 사용자: $userIds');
      }
      
      // 각 사용자의 문서에서 직접 FCM 토큰 조회
      for (final userId in userIds) {
        if (kDebugMode) {
          print('📋 사용자 FCM 토큰 조회 중: $userId');
        }
        
        final userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final fcmToken = userData['fcmToken'] as String?;
          
          if (kDebugMode) {
            print('👤 사용자 $userId: FCM 토큰 ${fcmToken != null ? "있음" : "없음"}');
          }
          
          if (fcmToken != null && fcmToken.isNotEmpty && fcmToken != _fcmToken) {
            tokens.add(fcmToken);
          }
        } else {
          if (kDebugMode) {
            print('❌ 사용자 $userId 문서가 존재하지 않음');
          }
        }
      }
      
      if (kDebugMode) {
        print('🔑 최종 조회된 FCM 토큰 수: ${tokens.length}/${userIds.length}');
      }
      
      return tokens;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 토큰 조회 실패: $e');
      }
      return [];
    }
  }

  /// 개별 FCM 메시지 발송 (실제 FCM API 사용)
  Future<void> _sendSingleFCMMessage({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      if (kDebugMode) {
        print('📨 실제 Firebase Functions FCM 메시지 발송 시도: $title -> ${token.substring(0, 20)}...');
      }
      
      // Firebase Functions를 통한 실제 크로스 디바이스 FCM 발송
      await sendRealFCMMessage(
        targetToken: token,
        title: title,
        body: body,
        type: data['type'] ?? 'general',
        meetingId: data['meetingId'],
        clickAction: data['clickAction'],
        channelId: data['channelId'] ?? 'default',
        customData: Map<String, dynamic>.from(data),
      );
      
      if (kDebugMode) {
        print('✅ Firebase Functions 통한 실제 FCM 발송 완료');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 메시지 발송 실패: $e');
      }
    }
  }
  
  /// 특정 FCM 토큰으로 직접 테스트 메시지 발송
  Future<void> sendDirectTestMessage({
    required String targetToken,
    required String title,
    required String body,
    String? type,
  }) async {
    try {
      if (kDebugMode) {
        print('🎯 직접 FCM 토큰으로 테스트 메시지 발송');
        print('대상 토큰: ${targetToken.substring(0, 30)}...');
      }
      
      await _sendSingleFCMMessage(
        token: targetToken,
        title: title,
        body: body,
        data: {
          'type': type ?? 'direct_test',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 직접 테스트 메시지 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 카카오 ID 기반으로 FCM 토큰을 Firestore에 저장
  /// 단순화된 FCM 토큰 저장 (users 문서에만)
  Future<void> saveFCMTokenToFirestore(String userId) async {
    try {
      if (_fcmToken == null) {
        if (kDebugMode) {
          print('⚠️ FCM 토큰이 없어서 저장할 수 없습니다');
        }
        return;
      }

      // 사용자 문서 존재 확인
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        if (kDebugMode) {
          print('❌ 사용자 문서를 찾을 수 없습니다: $userId');
        }
        return;
      }

      // 사용자 문서에 FCM 토큰 저장 (단순화된 단일 저장)
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('✅ 단순화된 FCM 토큰 저장 완료');
        print('  - 사용자 ID: $userId');
        print('  - 토큰: ${_fcmToken!.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 토큰 저장 실패: $e');
      }
    }
  }

  // 카카오 ID 기반 FCM 토큰 관리 메서드들 제거됨
  // 이제 users 문서의 fcmToken 필드만 사용

  /// 단순화된 FCM 토큰 갱신 (users 문서에만)
  Future<void> updateFCMToken(String userId, String newToken) async {
    try {
      // 새 토큰 업데이트
      _fcmToken = newToken;
      
      // 사용자 문서에 새 토큰 저장 (단순화됨)
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
        'fcmTokenUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (kDebugMode) {
        print('✅ 단순화된 FCM 토큰 갱신 완료: ${newToken.substring(0, 20)}...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 토큰 갱신 실패: $e');
      }
    }
  }

  /// 모임 참여 시 모든 참여자에게 알림
  Future<void> notifyMeetingParticipation({
    required Meeting meeting,
    required String joinerUserId,
    required String joinerName,
  }) async {
    await notifyAllParticipants(
      participantIds: meeting.participantIds,
      excludeUserId: joinerUserId,
      title: '새로운 참여자',
      body: '$joinerName님이 "${meeting.restaurantName ?? meeting.location}" 모임에 참여했습니다.',
      type: 'participant_joined',
      data: {
        'meetingId': meeting.id,
        'userId': joinerUserId,
      },
    );
  }

  /// 모임 탈퇴 시 남은 참여자들에게 알림
  Future<void> notifyMeetingLeave({
    required Meeting meeting,
    required String leaverUserId,
    required String leaverName,
  }) async {
    await notifyAllParticipants(
      participantIds: meeting.participantIds,
      excludeUserId: leaverUserId,
      title: '참여자 변동',
      body: '$leaverName님이 "${meeting.restaurantName ?? meeting.location}" 모임에서 나가셨습니다.',
      type: 'participant_left',
      data: {
        'meetingId': meeting.id,
        'userId': leaverUserId,
      },
    );
  }

  /// 채팅 메시지 발송 시 모든 참여자에게 알림
  Future<void> notifyChatMessage({
    required Meeting meeting,
    required String senderUserId,
    required String senderName,
    required String message,
  }) async {
    await notifyAllParticipants(
      participantIds: meeting.participantIds,
      excludeUserId: senderUserId,
      title: meeting.restaurantName ?? meeting.location,
      body: '$senderName: $message',
      type: 'chat_message',
      data: {
        'meetingId': meeting.id,
        'senderId': senderUserId,
      },
    );
  }
  
  /// 모임 취소 시 모든 참여자에게 알림
  Future<void> notifyMeetingCancelled({
    required Meeting meeting,
    required String hostUserId,
    required String hostName,
  }) async {
    await notifyAllParticipants(
      participantIds: meeting.participantIds,
      excludeUserId: hostUserId,
      title: '모임이 취소되었습니다',
      body: '$hostName님이 "${meeting.restaurantName ?? meeting.location}" 모임을 취소했습니다.',
      type: 'meeting_cancelled',
      data: {
        'meetingId': meeting.id,
        'hostId': hostUserId,
      },
    );
  }
  
  /// 새 모임 생성 시 지역 사용자들에게 알림 (선택적)
  Future<void> notifyNewMeetingToArea({
    required Meeting meeting,
    required String hostUserId,
  }) async {
    // 실제로는 같은 지역의 사용자들을 조회해서 알림을 발송해야 함
    // 현재는 테스트용으로 로컬 알림만 발송
    
    if (kDebugMode) {
      print('🆕 새 모임 지역 알림: ${meeting.restaurantName ?? meeting.location}');
    }
    
    await showNewMeetingNotification(meeting);
  }

  // ============================================
  // Firebase Functions 기반 실제 크로스 디바이스 FCM
  // ============================================

  /// 실제 크로스 디바이스 FCM 메시지 발송 (Firebase Functions 사용)
  Future<Map<String, dynamic>?> sendRealFCMMessage({
    required String targetToken,
    required String title,
    required String body,
    String? type,
    String? meetingId,
    String? clickAction,
    String? channelId,
    Map<String, dynamic>? customData,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 실제 FCM 발송 시작: $title');
        print('   대상 토큰: ${targetToken.substring(0, 20)}...');
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendFCMMessage');
      
      final result = await callable.call({
        'targetToken': targetToken,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'meetingId': meetingId ?? '',
        'clickAction': clickAction ?? '',
        'channelId': channelId ?? 'default',
        'customData': customData ?? {},
      });

      if (kDebugMode) {
        print('✅ 실제 FCM 발송 성공: ${result.data}');
      }

      return result.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 실제 FCM 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 여러 기기에 실제 FCM 멀티캐스트 발송
  Future<Map<String, dynamic>?> sendRealFCMMulticast({
    required List<String> tokens,
    required String title,
    required String body,
    String? type,
    String? meetingId,
    String? clickAction,
    String? channelId,
    Map<String, dynamic>? customData,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 실제 FCM 멀티캐스트 발송 시작: $title');
        print('   대상 토큰 수: ${tokens.length}개');
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendFCMMulticast');
      
      final result = await callable.call({
        'tokens': tokens,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'meetingId': meetingId ?? '',
        'clickAction': clickAction ?? '',
        'channelId': channelId ?? 'default',
        'customData': customData ?? {},
      });

      if (kDebugMode) {
        final data = result.data as Map<String, dynamic>;
        print('✅ 실제 FCM 멀티캐스트 성공: ${data['successCount']}/${tokens.length}');
      }

      return result.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 실제 FCM 멀티캐스트 실패: $e');
      }
      rethrow;
    }
  }

  /// 모임 관련 실제 FCM 알림 발송 (Firebase Functions 사용)
  Future<Map<String, dynamic>?> sendRealMeetingNotification({
    required String meetingId,
    required String notificationType,
    String? excludeUserId,
    String? senderName,
    String? message,
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 실제 모임 알림 발송 시작: $notificationType');
        print('   모임 ID: $meetingId');
      }

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendMeetingNotification');
      
      final result = await callable.call({
        'meetingId': meetingId,
        'notificationType': notificationType,
        'excludeUserId': excludeUserId ?? '',
        'senderName': senderName ?? '',
        'message': message ?? '',
      });

      if (kDebugMode) {
        final data = result.data as Map<String, dynamic>;
        print('✅ 실제 모임 알림 발송 성공: ${data['successCount']}명에게 전송');
      }

      return result.data as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 실제 모임 알림 발송 실패: $e');
      }
      rethrow;
    }
  }

}