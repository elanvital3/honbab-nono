import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/meeting.dart';
import 'user_service.dart';
import 'meeting_service.dart';
import 'meeting_auto_completion_service.dart';
import '../screens/chat/chat_room_screen.dart';
import '../screens/meeting/meeting_detail_screen.dart';
import '../components/evaluation_request_dialog.dart';
import '../components/meeting_auto_complete_dialog.dart';

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
  Map<String, dynamic>? _pendingNotificationData;
  
  // 평가 요청 이벤트 스트림 컨트롤러
  static final StreamController<String> _evaluationRequestController = 
      StreamController<String>.broadcast();
  
  // 평가 요청 이벤트 스트림 getter
  static Stream<String> get evaluationRequestStream => _evaluationRequestController.stream;
  
  // 알림 채널 ID들
  static const String _newMeetingChannelId = 'new_meeting';
  static const String _chatChannelId = 'chat_message';
  static const String _reminderChannelId = 'meeting_reminder';
  static const String _participantChannelId = 'participant_update';
  static const String _evaluationChannelId = 'evaluation_request';
  

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
    // Android 초기화 설정 - 알림 아이콘 확인
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    
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
    
    final initialized = await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    print('🔔 [NOTIFICATION] 로컬 알림 초기화 결과: $initialized');
    print('🔔 [NOTIFICATION] 콜백 함수 등록됨: ${_onNotificationTapped != null}');
    
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
        enableVibration: true,
        showBadge: true,
      ),
      
      // 채팅 메시지 채널 - 탭 액션 중요!
      const AndroidNotificationChannel(
        _chatChannelId,
        '채팅 메시지',
        description: '참여한 모임의 새 메시지 알림',
        importance: Importance.high,
        enableVibration: true,
        showBadge: true,
      ),
      
      // 모임 리마인더 채널
      const AndroidNotificationChannel(
        _reminderChannelId,
        '모임 리마인더',
        description: '참여한 모임 시작 전 알림',
        importance: Importance.max,
        enableVibration: true,
        showBadge: true,
      ),
      
      // 참여자 업데이트 채널
      const AndroidNotificationChannel(
        _participantChannelId,
        '참여 알림',
        description: '모임 참여 승인/거절 및 참여자 변동사항 알림',
        importance: Importance.high,
        enableVibration: true,
        showBadge: true,
      ),
      
      // 평가 요청 채널
      const AndroidNotificationChannel(
        _evaluationChannelId,
        '평가 요청',
        description: '모임 완료 후 참여자 평가 요청 알림',
        importance: Importance.high,
        enableVibration: true,
        showBadge: true,
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
    
    final messageType = message.data['type'] ?? '';
    
    // 평가 요청 메시지는 바로 다이얼로그로 표시
    if (messageType == 'evaluation_request') {
      final meetingId = message.data['meetingId'];
      if (meetingId != null && meetingId.isNotEmpty) {
        // 평가 요청 데이터를 임시 저장하여 앱 컨텍스트에서 다이얼로그 표시
        _pendingNotificationData = {
          'type': 'evaluation_request',
          'meetingId': meetingId,
          'showDialog': 'true', // 다이얼로그 즉시 표시 플래그
        };
        
        if (kDebugMode) {
          print('⭐ 평가 요청 메시지 수신 - 다이얼로그 표시 예약');
        }
        return;
      }
    }
    
    // 일반적인 알림 표시
    await _showLocalNotification(message);
  }

  /// 백그라운드에서 앱을 연 메시지 처리
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('백그라운드 메시지로 앱 열림: ${message.notification?.title}');
      print('메시지 데이터: ${message.data}');
    }
    
    // 메시지 타입에 따른 네비게이션 처리
    await handleNotificationNavigation(message.data);
  }

  /// 알림 클릭 시 네비게이션 처리 (전역에서 접근 가능하도록 수정)
  static Future<void> handleNotificationNavigation(Map<String, dynamic> data) async {
    try {
      final type = data['type'] ?? '';
      final meetingId = data['meetingId'];
      
      if (kDebugMode) {
        print('📱 알림 네비게이션 처리: type=$type, meetingId=$meetingId');
      }
      
      if (meetingId == null || meetingId.isEmpty) {
        if (kDebugMode) {
          print('❌ meetingId가 없어 네비게이션 처리 불가');
        }
        return;
      }
      
      // 알림 클릭 데이터를 임시 저장하여 앱 시작 시 처리
      _instance._pendingNotificationData = {
        'type': type,
        'meetingId': meetingId,
      };
      
      if (kDebugMode) {
        print('💾 알림 데이터 임시 저장 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 알림 네비게이션 처리 실패: $e');
      }
    }
  }
  
  /// 목적지로 네비게이션
  static Future<void> _navigateToDestination(BuildContext context, String type, String meetingId) async {
    try {
      print('🔔 [NOTIFICATION] 목적지 네비게이션 시작: type=$type, meetingId=$meetingId');
      print('🔔 [NOTIFICATION] Context 마운트 상태: ${context.mounted}');
      
      switch (type) {
        case 'chat_message':
        case 'chat':
          print('🔔 [NOTIFICATION] 💬 채팅방 네비게이션 선택됨');
          await _navigateToChatRoom(context, meetingId);
          break;
        case 'meeting_application':
        case 'meeting_approval':
        case 'meeting_rejection':
        case 'new_meeting':
        case 'nearby_meeting':
        case 'favorite_restaurant_meeting':
          if (kDebugMode) {
            print('📝 모임상세 네비게이션 선택됨');
          }
          await _navigateToMeetingDetail(context, meetingId);
          break;
        case 'test':
          print('🔔 [NOTIFICATION] 🧪 테스트 알림 탭 감지 성공! meetingId=$meetingId');
          // 테스트 알림은 네비게이션하지 않고 로그만 출력
          break;
        case 'auto_complete':
          print('🔔 [NOTIFICATION] ⏰ 모임 자동 완료 알림 탭 감지: meetingId=$meetingId');
          await _navigateToMeetingDetail(context, meetingId);
          break;
        case 'meeting_auto_complete':
          print('🔔 [NOTIFICATION] 🍽️ Firebase Functions 모임 자동 완료 알림: meetingId=$meetingId');
          await _showAutoCompleteDialog(context, meetingId);
          break;
        case 'evaluation_request':
          print('🔔 [NOTIFICATION] ⭐ 평가 요청 알림 탭 감지: meetingId=$meetingId');
          await _showEvaluationRequestDialog(context, meetingId);
          break;
        default:
          if (kDebugMode) {
            print('⚠️ 알 수 없는 알림 타입: $type');
          }
          break;
      }
      
      print('🔔 [NOTIFICATION] ✅ 목적지 네비게이션 완료');
    } catch (e) {
      print('🔔 [NOTIFICATION] ❌ 목적지 네비게이션 실패: $e');
      print('🔔 [NOTIFICATION] ❌ 스택 트레이스: ${StackTrace.current}');
    }
  }
  
  /// 앱 시작 시 대기 중인 알림 처리
  Future<void> processPendingNotification(BuildContext context) async {
    print('🔔 [NOTIFICATION] processPendingNotification 호출됨');
    print('🔔 [NOTIFICATION] 대기 데이터: $_pendingNotificationData');
    
    if (_pendingNotificationData == null) {
      print('🔔 [NOTIFICATION] 대기 중인 알림 데이터 없음');
      return;
    }
    
    try {
      final type = _pendingNotificationData!['type'] ?? '';
      final meetingId = _pendingNotificationData!['meetingId'];
      final showDialog = _pendingNotificationData!['showDialog'] ?? 'false';
      
      print('🔔 [NOTIFICATION] 대기 알림 처리 시작: type=$type, meetingId=$meetingId, showDialog=$showDialog');
      print('🔔 [NOTIFICATION] Context 상태: mounted=${context.mounted}');
      
      if (meetingId == null || meetingId.isEmpty) {
        print('🔔 [NOTIFICATION] ❌ meetingId가 비어있어서 처리 중단');
        _pendingNotificationData = null;
        return;
      }
      
      // 처리 후 데이터 삭제
      _pendingNotificationData = null;
      
      // 평가 요청이고 즉시 다이얼로그 표시가 필요한 경우
      if (type == 'evaluation_request' && showDialog == 'true') {
        print('🔔 [NOTIFICATION] ⭐ 평가 요청 다이얼로그 즉시 표시');
        await _showEvaluationRequestDialog(context, meetingId);
      } else {
        // 일반적인 네비게이션 처리
        await _navigateToDestination(context, type, meetingId);
      }
    } catch (e) {
      print('🔔 [NOTIFICATION] ❌ 대기 중인 알림 처리 실패: $e');
      print('🔔 [NOTIFICATION] ❌ 스택 트레이스: ${StackTrace.current}');
      _pendingNotificationData = null; // 오류 발생 시에도 데이터 삭제
    }
  }
  
  /// 채팅방으로 이동
  static Future<void> _navigateToChatRoom(BuildContext context, String meetingId) async {
    try {
      print('🔔 [NOTIFICATION] 💬 채팅방으로 이동 시작: meetingId=$meetingId');
      print('🔔 [NOTIFICATION] Context 마운트 상태: ${context.mounted}');
      
      // MeetingService를 통해 모임 정보 가져오기
      print('🔔 [NOTIFICATION] 모임 정보 조회 중...');
      
      final meeting = await MeetingService.getMeeting(meetingId);
      if (meeting == null) {
        print('🔔 [NOTIFICATION] ❌ 모임을 찾을 수 없음: $meetingId');
        return;
      }
      
      print('🔔 [NOTIFICATION] ✅ 모임 정보 조회 성공: ${meeting.description}');
      print('🔔 [NOTIFICATION] 네비게이션 실행 전 Context 상태: ${context.mounted}');
      
      if (context.mounted) {
        print('🔔 [NOTIFICATION] 🚀 채팅방 화면으로 네비게이션 실행');
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(meeting: meeting),
          ),
        );
        
        print('🔔 [NOTIFICATION] ✅ 채팅방 네비게이션 완료');
      } else {
        print('🔔 [NOTIFICATION] ❌ Context가 마운트되지 않아 네비게이션 실패');
      }
    } catch (e) {
      print('🔔 [NOTIFICATION] ❌ 채팅방 이동 실패: $e');
      print('🔔 [NOTIFICATION] ❌ 스택 트레이스: ${StackTrace.current}');
    }
  }
  
  /// 모임 상세로 이동
  static Future<void> _navigateToMeetingDetail(BuildContext context, String meetingId) async {
    try {
      if (kDebugMode) {
        print('📝 모임 상세로 이동: $meetingId');
      }
      
      // MeetingService를 통해 모임 정보 가져오기
      final meeting = await MeetingService.getMeeting(meetingId);
      if (meeting == null) {
        if (kDebugMode) {
          print('❌ 모임을 찾을 수 없음: $meetingId');
        }
        return;
      }
      
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MeetingDetailScreen(meeting: meeting),
          ),
        );
        
        if (kDebugMode) {
          print('✅ 모임 상세 이동 완료');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 모임 상세 이동 실패: $e');
      }
    }
  }

  /// 평가 요청 다이얼로그 표시
  static Future<void> _showEvaluationRequestDialog(BuildContext context, String meetingId) async {
    try {
      if (kDebugMode) {
        print('⭐ 평가 요청 다이얼로그 표시: $meetingId');
      }
      
      // MeetingService를 통해 모임 정보 가져오기
      final meeting = await MeetingService.getMeeting(meetingId);
      if (meeting == null) {
        if (kDebugMode) {
          print('❌ 모임을 찾을 수 없음: $meetingId');
        }
        return;
      }
      
      if (context.mounted) {
        await EvaluationRequestDialog.show(
          context: context,
          meeting: meeting,
          onEvaluationCompleted: () {
            if (kDebugMode) {
              print('✅ 평가 완료 콜백 호출됨');
            }
          },
        );
        
        if (kDebugMode) {
          print('✅ 평가 요청 다이얼로그 표시 완료');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 요청 다이얼로그 표시 실패: $e');
      }
    }
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
      case 'evaluation':
        channelId = _evaluationChannelId;
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
      icon: '@mipmap/launcher_icon',
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
    
    // payload 형태: "type:meetingId"
    final meetingId = message.data['meetingId'] ?? '';
    final payload = '$messageType:$meetingId';
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  /// 근처 사용자들에게 새 모임 생성 알림 발송
  Future<void> notifyNearbyUsersOfNewMeeting(Meeting meeting) async {
    try {
      // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
      // 발송자가 방해금지여도 근처 사용자들은 알림을 받아야 함
      
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

      // Firebase Functions 제거됨 - 크로스 디바이스 FCM 기능 비활성화
      // Phase 2에서 Firebase Admin SDK로 재구현 예정
      if (kDebugMode) {
        print('🔔 주변 사용자 FCM 알림: ${nearbyTokens.length}개 토큰');
        print('   제목: 🍽️ 근처에 새로운 모임이 생성되었어요!');
      }

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
      icon: '@mipmap/launcher_icon',
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
  Future<void> showChatNotification(String meetingId, String meetingTitle, String senderName, String message) async {
    if (!await _isNotificationEnabled('chatNotification')) return;
    if (await _isDoNotDisturbActive()) return;
    
    const androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      '채팅 메시지',
      channelDescription: '참여한 모임의 새 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      autoCancel: true,
      enableVibration: true,
      enableLights: true,
      category: AndroidNotificationCategory.message,
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
      payload: 'chat_message:$meetingId',
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
      icon: '@mipmap/launcher_icon',
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
      icon: '@mipmap/launcher_icon',
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
    // 🔔 중요한 알림 관련 로그만 유지
    print('🔔 [NOTIFICATION] 로컬 알림 탭됨!');
    print('🔔 [NOTIFICATION] Payload: ${response.payload}');
    print('🔔 [NOTIFICATION] ActionId: ${response.actionId}');
    print('🔔 [NOTIFICATION] Input: ${response.input}');
    
    final payload = response.payload;
    if (payload == null) {
      print('🔔 [NOTIFICATION] ❌ Payload가 null입니다');
      return;
    }
    
    try {
      // payload 파싱: "type:meetingId" 형태
      final parts = payload.split(':');
      if (parts.length >= 2) {
        final type = parts[0];
        final meetingId = parts[1];
        
        print('🔔 [NOTIFICATION] 데이터 파싱 성공: type=$type, meetingId=$meetingId');
        
        // 알림 클릭 데이터를 임시 저장하여 앱 시작 시 처리
        _instance._pendingNotificationData = {
          'type': type,
          'meetingId': meetingId,
        };
        
        print('🔔 [NOTIFICATION] 데이터 임시 저장 완료');
      } else {
        print('🔔 [NOTIFICATION] ❌ 잘못된 payload 형태: $payload');
      }
    } catch (e) {
      print('🔔 [NOTIFICATION] ❌ 알림 탭 처리 실패: $e');
      print('🔔 [NOTIFICATION] ❌ 스택 트레이스: ${StackTrace.current}');
    }
  }

  /// 특정 알림 타입이 활성화되어 있는지 확인
  Future<bool> _isNotificationEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  /// 즐겨찾기 식당 알림이 활성화되어 있는지 확인 (공개 메서드)
  Future<bool> isFavoriteRestaurantNotificationEnabled() async {
    return await _isNotificationEnabled('favoriteRestaurantNotification');
  }

  /// 방해금지 모드가 활성화되어 있는지 확인 (공개 메서드)
  Future<bool> isDoNotDisturbActive() async {
    return await _isDoNotDisturbActive();
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
      case _evaluationChannelId:
        return '평가 요청';
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
      case _evaluationChannelId:
        return '모임 완료 후 참여자 평가 요청 알림';
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
      // 방해금지 모드는 수신자(호스트) 기준으로 체크하지 않음
      // FCM 서버에서 각 사용자의 설정에 따라 처리됨
      
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

      // 호스트에게 실제 FCM 발송 (로컬/원격 구분 없이 항상 FCM)
      if (kDebugMode) {
        print('📨 호스트에게 FCM 알림 발송');
        print('  - 호스트 ID: ${meeting.hostId}');
        print('  - FCM 토큰: ${hostUser?.fcmToken?.substring(0, 20) ?? '없음'}...');
      }
      
      try {
        // Firebase Functions를 통한 실제 FCM 발송
        await _sendSingleFCMMessage(
          token: hostUser!.fcmToken!,
          title: title,
          body: body,
          data: {
            'type': 'meeting_application',
            'meetingId': meeting.id,
            'applicantUserId': applicantUserId,
            'applicantName': applicantName,
          },
        );
        
        if (kDebugMode) {
          print('✅ 호스트에게 FCM 알림 발송 완료');
        }
      } catch (fcmError) {
        if (kDebugMode) {
          print('❌ FCM 발송 실패: $fcmError');
        }
        rethrow;
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
      // 방해금지 모드는 수신자(신청자) 기준으로 체크하지 않음
      // FCM 서버에서 각 사용자의 설정에 따라 처리됨
      
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

      // 신청자에게 실제 FCM 발송 (로컬/원격 구분 없이 항상 FCM)
      if (kDebugMode) {
        print('📨 신청자에게 FCM 알림 발송');
        print('  - 신청자 ID: $applicantUserId');
        print('  - FCM 토큰: ${applicantUser?.fcmToken?.substring(0, 20) ?? '없음'}...');
      }
      
      try {
        // Firebase Functions를 통한 실제 FCM 발송
        await _sendSingleFCMMessage(
          token: applicantUser!.fcmToken!,
          title: title,
          body: body,
          data: {
            'type': 'meeting_approval',
            'meetingId': meeting.id,
            'hostUserId': meeting.hostId,
          },
        );
        
        if (kDebugMode) {
          print('✅ 신청자에게 FCM 알림 발송 완료');
        }
      } catch (fcmError) {
        if (kDebugMode) {
          print('❌ FCM 발송 실패: $fcmError');
        }
        rethrow;
      }

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
      // 방해금지 모드는 수신자(신청자) 기준으로 체크하지 않음
      // FCM 서버에서 각 사용자의 설정에 따라 처리됨
      
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

      // 신청자에게 실제 FCM 발송 (로컬/원격 구분 없이 항상 FCM)
      if (kDebugMode) {
        print('📨 신청자에게 FCM 알림 발송');
        print('  - 신청자 ID: $applicantUserId');
        print('  - FCM 토큰: ${applicantUser?.fcmToken?.substring(0, 20) ?? '없음'}...');
      }
      
      try {
        // Firebase Functions를 통한 실제 FCM 발송
        await _sendSingleFCMMessage(
          token: applicantUser!.fcmToken!,
          title: title,
          body: body,
          data: {
            'type': 'meeting_rejection',
            'meetingId': meeting.id,
            'hostUserId': meeting.hostId,
          },
        );
        
        if (kDebugMode) {
          print('✅ 신청자에게 FCM 알림 발송 완료');
        }
      } catch (fcmError) {
        if (kDebugMode) {
          print('❌ FCM 발송 실패: $fcmError');
        }
        rethrow;
      }

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

  /// 테스트 채팅 알림 표시 (디버깅용)
  Future<void> showTestChatNotification(String meetingId, String meetingTitle) async {
    if (kDebugMode) {
      print('🧪 테스트 채팅 알림 생성: meetingId=$meetingId, title=$meetingTitle');
      print('🧪 알림 서비스 초기화 상태: $_isInitialized');
      print('🧪 _onNotificationTapped 콜백: ${_onNotificationTapped != null}');
    }
    
    const androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      '채팅 메시지',
      channelDescription: '참여한 모임의 새 메시지 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      autoCancel: true,
      enableVibration: true,
      enableLights: true,
      category: AndroidNotificationCategory.message,
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
      '$meetingTitle - 새 메시지',
      '테스트 메시지입니다. 탭하면 채팅방으로 이동합니다.',
      details,
      payload: 'chat_message:$meetingId',
    );
    
    if (kDebugMode) {
      print('🧪 테스트 알림 생성 완료: payload=chat_message:$meetingId');
    }
  }

  /// 스케줄된 알림 생성 (MeetingAutoCompletionService용)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    String? channelId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      channelId ?? _reminderChannelId,
      '모임 자동 완료',
      channelDescription: '모임 시간 후 자동 완료 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      autoCancel: true,
      enableVibration: true,
      enableLights: true,
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
    
    final seoul = tz.getLocation('Asia/Seoul');
    final zonedScheduledTime = tz.TZDateTime.from(scheduledTime, seoul);
    
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      zonedScheduledTime,
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    
    if (kDebugMode) {
      print('🔔 [NOTIFICATION] 스케줄된 알림 생성: $title (id: $id, time: $scheduledTime)');
    }
  }

  /// 스케줄된 알림 취소
  Future<void> cancelScheduledNotification(int id) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    await _localNotifications.cancel(id);
    
    if (kDebugMode) {
      print('🔔 [NOTIFICATION] 스케줄된 알림 취소: id=$id');
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
        icon: '@mipmap/launcher_icon',
        autoCancel: true,
        enableVibration: true,
        enableLights: true,
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
        payload: 'test:simple_test', // 간단한 테스트 payload 추가
      );
      
      if (kDebugMode) {
        print('✅ 테스트 알림 표시 완료: $title (payload: test:simple_test)');
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

      print('🧪 로컬 알림 테스트 시작 (Firebase Functions 제거됨)');
      
      // Firebase Functions 제거됨 - 로컬 알림으로 테스트
      await showTestNotification(
        '🧪 모임 신청 테스트',
        '테스트님이 "맛집 탐방" 모임에 참여 신청했습니다',
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
    String? excludeUserId, // nullable로 변경하여 아무도 제외하지 않을 수 있음
    required String title,
    required String body,
    String? type,
    Map<String, String>? data,
  }) async {
    try {
      // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
      // 발송자가 방해금지여도 상대방은 알림을 받아야 함
      
      if (kDebugMode) {
        print('🔔 모든 참여자에게 알림 발송 시작');
        print('📝 참여자 ID들: $participantIds');
        print('🚫 제외할 사용자: $excludeUserId');
        print('📨 알림 타입: $type');
      }

      // 제외할 사용자를 제외한 참여자 목록 (excludeUserId가 null이면 아무도 제외하지 않음)
      final targetParticipants = excludeUserId != null 
          ? participantIds.where((id) => id != excludeUserId).toList()
          : participantIds;
      
      if (targetParticipants.isEmpty) {
        if (kDebugMode) {
          print('📭 알림을 받을 참여자가 없습니다');
        }
        return;
      }

      // 채팅 메시지 알림의 경우 현재 채팅방 ID 전달
      String? currentChatRoomId;
      if (type == 'chat_message') {
        currentChatRoomId = data?['meetingId'];
        if (kDebugMode) {
          print('💬 채팅 메시지 알림 - 채팅방 활성 사용자 제외 모드 (채팅방: $currentChatRoomId)');
        }
      }

      // 참여자들의 FCM 토큰 가져오기 (채팅방 활성 사용자 제외)
      final fcmTokens = await _getFCMTokensForUsers(targetParticipants, currentChatRoomId: currentChatRoomId);
      
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

  /// 사용자들의 FCM 토큰 가져오기 (사용자 ID 기반 제외 + 채팅방 활성 사용자 제외)
  Future<List<String>> _getFCMTokensForUsers(List<String> userIds, {String? currentChatRoomId}) async {
    try {
      final tokens = <String>[];
      
      if (kDebugMode) {
        print('🔍 FCM 토큰 조회 시작 - 대상 사용자: $userIds');
        if (currentChatRoomId != null) {
          print('📵 채팅방 활성 사용자 제외 모드: $currentChatRoomId');
        }
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
          final userCurrentChatRoom = userData['currentChatRoom'] as String?;
          
          if (kDebugMode) {
            print('👤 사용자 $userId: FCM 토큰 ${fcmToken != null ? "있음" : "없음"}');
            print('   현재 채팅방: $userCurrentChatRoom');
          }
          
          // 채팅방 알림의 경우: 현재 해당 채팅방에 있는 사용자는 제외
          if (currentChatRoomId != null && userCurrentChatRoom == currentChatRoomId) {
            if (kDebugMode) {
              print('📵 채팅방 활성 사용자 알림 제외: $userId (채팅방: $currentChatRoomId)');
            }
            continue;
          }
          
          // FCM 토큰이 유효하면 추가 (사용자 ID는 이미 notifyAllParticipants에서 제외됨)
          if (fcmToken != null && fcmToken.isNotEmpty) {
            tokens.add(fcmToken);
            if (kDebugMode) {
              print('✅ 사용자 $userId의 FCM 토큰 추가됨');
            }
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
      
      // Firebase Functions를 통한 FCM 발송
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendNotification');
      
      final result = await callable.call({
        'token': token,
        'title': title,
        'body': body,
        'data': data,
        'channelId': _participantChannelId,
      });
      
      if (kDebugMode) {
        print('✅ FCM 메시지 발송 성공: ${result.data}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM 메시지 발송 실패: $e');
      }
      
      // 실패 시 로컬 알림으로 폴백 (타입별로 구분)
      final messageType = data['type'] ?? 'general';
      String fallbackTitle;
      
      switch (messageType) {
        case 'chat_message':
          fallbackTitle = '💬 [채팅 알림 - FCM 실패] $title';
          break;
        case 'meeting_application':
          fallbackTitle = '🙋‍♀️ [모임 신청 - FCM 실패] $title';
          break;
        case 'meeting_approval':
          fallbackTitle = '🎉 [참여 승인 - FCM 실패] $title';
          break;
        case 'meeting_rejection':
          fallbackTitle = '😔 [참여 거절 - FCM 실패] $title';
          break;
        case 'favorite_restaurant_meeting':
          fallbackTitle = '❤️ [즐겨찾기 식당 - FCM 실패] $title';
          break;
        default:
          fallbackTitle = '🔔 [알림 - FCM 실패] $title';
      }
      
      await showTestNotification(fallbackTitle, '$body (FCM 실패, 로컬 표시)');
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
    // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
    
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
    // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
    
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
    // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
    // 발송자가 방해금지여도 상대방은 알림을 받아야 함
    
    if (kDebugMode) {
      print('💬 채팅 메시지 알림 발송 시작');
      print('📝 모임: ${meeting.restaurantName ?? meeting.location}');
      print('👤 발송자: $senderName ($senderUserId)');
      print('📱 전체 참여자: ${meeting.participantIds}');
      print('🚫 제외할 사용자: $senderUserId');
    }
    
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
    // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
    
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

  // Firebase Functions는 제거됨 - 현재 로컬 알림만 사용

  /// 모임 완료 후 평가 요청 알림 (모든 참여자에게)
  Future<void> notifyEvaluationRequest({
    required Meeting meeting,
    required List<String> participantIds,
  }) async {
    try {
      // 방해금지 모드는 수신자 기준으로 FCM 서버에서 처리됨
      
      if (kDebugMode) {
        print('⭐ 평가 요청 알림 발송 시작: ${meeting.id}');
        print('   대상자: ${participantIds.length}명');
      }

      // 현재 사용자가 참여자인 경우 평가 요청 다이얼로그 표시 (호스트 제외)
      final currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null && 
          participantIds.contains(currentUserId) && 
          currentUserId != meeting.hostId) {
        // 평가 요청 데이터를 임시 저장하여 다이얼로그 표시
        _pendingNotificationData = {
          'type': 'evaluation_request',
          'meetingId': meeting.id,
          'showDialog': 'true', // 다이얼로그 즉시 표시 플래그
        };
        
        if (kDebugMode) {
          print('⭐ 현재 사용자(참여자)에게 평가 요청 다이얼로그 표시 예약: $currentUserId (호스트 제외됨)');
        }
        
        // 앱이 포그라운드에 있다면 즉시 다이얼로그 표시를 위해 전역 알림 발송
        try {
          await _triggerImmediateEvaluationDialog(meeting.id);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 즉시 평가 다이얼로그 표시 실패: $e');
          }
        }
      }

      // 모든 참여자에게 FCM 알림 발송 (호스트 포함)
      final title = '⭐ 모임 평가 요청';
      final body = '"${meeting.description}" 모임이 완료되었습니다! 🎉\n함께한 멤버들을 평가해주세요.';
      
      // FCM으로 참여자들에게만 평가 요청 알림 (호스트 제외)
      await notifyAllParticipants(
        participantIds: participantIds,
        excludeUserId: meeting.hostId, // 호스트 제외 - 호스트는 이미 완료 확인 후 바로 평가로 이동
        title: title,
        body: body,
        type: 'evaluation_request',
        data: {
          'meetingId': meeting.id,
          'hostId': meeting.hostId,
        },
      );
      
      
      if (kDebugMode) {
        print('✅ 참여자들에게 평가 요청 알림 발송 완료 (${participantIds.length - 1}명, 호스트 제외)');
        print('   📱 푸시 알림: 호스트 제외, 참여자들만');
        print('   💬 즉시 다이얼로그: 호스트 제외, 참여자들만');
        print('   🎯 호스트는 모임 완료 버튼 → 바로 평가 화면으로 이동');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 요청 알림 발송 실패: $e');
      }
      rethrow;
    }
  }

  /// 포그라운드에서 즉시 평가 다이얼로그 표시를 위한 내부 알림 트리거
  Future<void> _triggerImmediateEvaluationDialog(String meetingId) async {
    try {
      if (kDebugMode) {
        print('⭐ 즉시 평가 다이얼로그 표시 트리거 시작: $meetingId');
      }
      
      // 짧은 지연 후 처리 (UI가 완전히 로드된 후)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 평가 다이얼로그 즉시 표시를 위한 글로벌 이벤트 발송
      // 이는 HomeScreen에서 처리될 것임
      _pendingNotificationData = {
        'type': 'evaluation_request',
        'meetingId': meetingId,
        'showDialog': 'true',
        'immediate': 'true', // 즉시 표시 플래그
      };
      
      // 전역 이벤트 스트림을 통해 HomeScreen에 알림
      _evaluationRequestController.add(meetingId);
      
      if (kDebugMode) {
        print('✅ 즉시 평가 다이얼로그 표시 트리거 완료: $meetingId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 즉시 평가 다이얼로그 표시 트리거 실패: $e');
      }
    }
  }

  /// Firebase Functions 자동 완료 알림 클릭 시 다이얼로그 표시
  static Future<void> _showAutoCompleteDialog(BuildContext context, String meetingId) async {
    try {
      print('🔔 [NOTIFICATION] 🍽️ 자동 완료 다이얼로그 표시 시작: meetingId=$meetingId');
      
      // 모임 정보 조회
      final meeting = await MeetingService.getMeeting(meetingId);
      if (meeting == null) {
        print('🔔 [NOTIFICATION] ❌ 모임을 찾을 수 없음: $meetingId');
        return;
      }
      
      // 현재 사용자가 호스트인지 확인
      final currentUserId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || meeting.hostId != currentUserId) {
        print('🔔 [NOTIFICATION] ❌ 호스트가 아니어서 자동 완료 다이얼로그 표시 안 함');
        return;
      }
      
      // 이미 완료된 모임인지 확인
      if (meeting.status == 'completed') {
        print('🔔 [NOTIFICATION] ⚠️ 이미 완료된 모임: $meetingId');
        // 이미 완료된 모임이라도 상세 화면으로 이동
        if (context.mounted) {
          await _navigateToMeetingDetail(context, meetingId);
        }
        return;
      }
      
      if (!context.mounted) {
        print('🔔 [NOTIFICATION] ❌ Context가 마운트되지 않음');
        return;
      }
      
      print('🔔 [NOTIFICATION] 🎯 자동 완료 다이얼로그 표시 중...');
      
      // 다이얼로그 표시
      final result = await MeetingAutoCompleteDialog.show(
        context: context,
        meetingName: meeting.restaurantName ?? meeting.location,
        onComplete: () async {
          print('🔔 [NOTIFICATION] ✅ 사용자가 모임 완료 선택');
        },
        onPostpone: () async {
          print('🔔 [NOTIFICATION] ⏰ 사용자가 1시간 후 재알림 선택');
          // 1시간 후 재알림 로직
          await MeetingAutoCompletionService.postponeMeetingAutoCompletion(
            meetingId,
            meeting.restaurantName ?? meeting.location,
          );
        },
        onCancelMeeting: () async {
          print('🔔 [NOTIFICATION] 🚫 사용자가 모임 취소 선택');
          // 모임 취소 처리
          await MeetingService.deleteMeeting(meetingId);
        },
      );
      
      // 다이얼로그 결과에 따라 처리
      if (result == 'complete_keep' || result == 'complete_close') {
        bool keepChatActive = result == 'complete_keep';
        print('🔔 [NOTIFICATION] 모임 완료 처리 시작 - 채팅방 유지: $keepChatActive');
        await MeetingService.completeMeeting(meetingId, keepChatActive: keepChatActive);
      } else if (result == 'still_ongoing') {
        print('🔔 [NOTIFICATION] 아직 모임중 - 2시간 후 재알림 예약');
        // 2시간 후 재알림 예약
        await MeetingAutoCompletionService.postponeMeetingAutoCompletion(
          meetingId,
          meeting.restaurantName ?? meeting.location,
          delayHours: 2,
        );
      }
      
      print('🔔 [NOTIFICATION] ✅ 자동 완료 다이얼로그 처리 완료');
      
    } catch (e) {
      print('🔔 [NOTIFICATION] ❌ 자동 완료 다이얼로그 표시 실패: $e');
      print('🔔 [NOTIFICATION] 📱 fallback: 모임 상세 화면으로 이동');
      
      // 에러 발생 시 모임 상세 화면으로 이동
      if (context.mounted) {
        await _navigateToMeetingDetail(context, meetingId);
      }
    }
  }

  /// 평가 재알림 예약 (24시간 후)
  Future<void> scheduleEvaluationReminder({
    required Meeting meeting,
    int delayHours = 24,
  }) async {
    try {
      if (kDebugMode) {
        print('⏰ 평가 재알림 예약: ${meeting.id} (${delayHours}시간 후)');
      }
      
      // 현재 시간에서 delayHours 시간 후 계산
      final scheduledTime = DateTime.now().add(Duration(hours: delayHours));
      
      // SharedPreferences에 재알림 정보 저장
      final prefs = await SharedPreferences.getInstance();
      final reminderKey = 'evaluation_reminder_${meeting.id}';
      await prefs.setString(reminderKey, scheduledTime.toIso8601String());
      
      // 로컬 알림 예약
      await _localNotifications.zonedSchedule(
        meeting.id.hashCode + 2000, // 고유 ID (평가 재알림용)
        '⭐ 평가 재알림',
        '${meeting.restaurantName ?? meeting.location} 모임 평가를 완료해주세요',
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _evaluationChannelId,
            _getChannelName(_evaluationChannelId),
            channelDescription: _getChannelDescription(_evaluationChannelId),
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'evaluation_request:${meeting.id}',
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      if (kDebugMode) {
        print('✅ 평가 재알림 예약 완료: ${scheduledTime.toString()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 재알림 예약 실패: $e');
      }
      rethrow;
    }
  }

  /// 평가 완료 시 재알림 취소
  Future<void> cancelEvaluationReminder(String meetingId) async {
    try {
      // 로컬 알림 취소
      await _localNotifications.cancel(meetingId.hashCode + 2000);
      
      // SharedPreferences에서 재알림 정보 제거
      final prefs = await SharedPreferences.getInstance();
      final reminderKey = 'evaluation_reminder_$meetingId';
      await prefs.remove(reminderKey);
      
      if (kDebugMode) {
        print('✅ 평가 재알림 취소 완료: $meetingId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 평가 재알림 취소 실패: $e');
      }
    }
  }

}