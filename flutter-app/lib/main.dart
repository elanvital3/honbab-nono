import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/meeting_service.dart';
import 'services/meeting_auto_completion_service.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_complete_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/meeting/create_meeting_screen.dart';
import 'screens/meeting/meeting_detail_screen.dart';
import 'screens/test/badge_test_screen.dart';
import 'models/meeting.dart';
import 'models/user.dart' as app_user;

/// 백그라운드 메시지 핸들러
/// 앱이 백그라운드나 종료된 상태에서 FCM 메시지를 받을 때 실행
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화가 필요한 경우
  await FirebaseConfig.initialize();
  
  print('🔔 백그라운드 메시지 수신: ${message.messageId}');
  print('   제목: ${message.notification?.title}');
  print('   내용: ${message.notification?.body}');
  print('   데이터: ${message.data}');
  
  // 백그라운드에서 로컬 알림 표시
  await NotificationService().initialize();
  
  if (message.notification != null) {
    await NotificationService().showTestNotification(
      message.notification!.title ?? '알림',
      message.notification!.body ?? '새로운 메시지가 도착했습니다.',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경변수 로드
  await dotenv.load(fileName: ".env");
  print('✅ 환경변수 로드 완료');
  
  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: 'aa44527cad103e9986ceedb39cc915f9');
  print('✅ 카카오 SDK 초기화 성공');
  
  try {
    // Firebase 초기화
    await FirebaseConfig.initialize();
    print('✅ Firebase 초기화 성공');
    
    // Firebase Messaging 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print('✅ FCM 백그라운드 핸들러 등록 완료');
  } catch (e) {
    print('❌ Firebase 초기화 실패: $e');
  }
  
  // 타임존 초기화
  tz.initializeTimeZones();
  
  // 알림 서비스 초기화
  try {
    await NotificationService().initialize();
    print('✅ 알림 서비스 초기화 성공');
    
    // 앱이 종료된 상태에서 알림 클릭으로 시작된 경우 처리
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('🔔 앱 시작 시 초기 메시지 발견: ${initialMessage.data}');
      // NotificationService를 통해 처리 예약
      await NotificationService.handleNotificationNavigation(initialMessage.data);
    }
  } catch (e) {
    print('❌ 알림 서비스 초기화 실패: $e');
  }

  // 모임 자동 완료 서비스 초기화
  try {
    await MeetingAutoCompletionService.initialize();
    print('✅ 모임 자동 완료 서비스 초기화 성공');
  } catch (e) {
    print('❌ 모임 자동 완료 서비스 초기화 실패: $e');
  }
  
  // 마이그레이션 제거 - 이제 UID만 사용하므로 불필요
  
  try {
    // 카카오맵 초기화 - JavaScript 키 적용
    final kakaoJSKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'] ?? '';
    await KakaoMapsFlutter.init(kakaoJSKey);
    print('✅ 카카오맵 초기화 성공');
  } catch (e) {
    print('❌ 카카오맵 초기화 실패: $e');
  }
  
  // 백그라운드에서 위치 미리 가져오기 (캐시용)
  LocationService.getCurrentLocation().then((location) {
    if (location != null) {
      print('📍 앱 시작 시 위치 캐시 완료: ${location.latitude}, ${location.longitude}');
    } else {
      print('📍 앱 시작 시 위치 가져오기 실패');
    }
  }).catchError((e) {
    print('📍 앱 시작 시 위치 가져오기 에러: $e');
  });
  
  // 테스트 데이터 추가 제거 - 프로덕션에서 불필요
  print('🚀 앱 초기화 완료');
  
  // 크롤링한 실제 데이터 추가 (임시 비활성화 - 네트워크 문제)
  // try {
  //   await CrawledDataAdder.addCrawledData();
  // } catch (e) {
  //   print('⚠️ 크롤링 데이터 추가 중 오류 (이미 존재할 수 있음): $e');
  // }
  
  runApp(const HonbabNoNoApp());
}

class HonbabNoNoApp extends StatefulWidget {
  const HonbabNoNoApp({super.key});

  @override
  State<HonbabNoNoApp> createState() => _HonbabNoNoAppState();
}

class _HonbabNoNoAppState extends State<HonbabNoNoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (kDebugMode) {
          print('🔄 앱 포그라운드 전환 - UI 새로고침');
        }
        // 포그라운드로 돌아올 때 UI 강제 새로고침
        setState(() {});
        // 추가 지연 후 한번 더 새로고침 (화면이 완전히 로드된 후)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {});
          }
        });
        break;
      case AppLifecycleState.paused:
        if (kDebugMode) {
          print('⏸️ 앱 백그라운드 전환');
        }
        break;
      case AppLifecycleState.detached:
        if (kDebugMode) {
          print('🔌 앱 완전 종료');
        }
        break;
      case AppLifecycleState.inactive:
        if (kDebugMode) {
          print('😴 앱 비활성 상태');
        }
        break;
      case AppLifecycleState.hidden:
        if (kDebugMode) {
          print('🫥 앱 숨김 상태');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamProvider<firebase_auth.User?>.value(
      value: AuthService.authStateChanges,
      initialData: null,
      child: MaterialApp(
      title: '혼밥노노',
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFD2B48C),        // 베이지 - 당근마켓 주황색 위치에
          secondary: Color(0xFF666666),      // 당근마켓 회색
          tertiary: Color(0xFFD2B48C),       // 베이지 - 강조용
          surface: Color(0xFFFFFFFF),        // 당근마켓 순백
          surfaceContainer: Color(0xFFF9F9F9), // 당근마켓 연한 회색 배경
          background: Color(0xFFFFFFFF),     // 당근마켓 순백 배경
          onPrimary: Color(0xFFFFFFFF),      // 흰색 텍스트
          onSecondary: Color(0xFFFFFFFF),    // 흰색 텍스트
          onSurface: Color(0xFF000000),      // 당근마켓 검은색 텍스트
          onBackground: Color(0xFF000000),   // 당근마켓 검은색 텍스트
          outline: Color(0xFF999999),        // 당근마켓 연한 회색
          shadow: Color(0xFF000000),         // 검은색 그림자
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD2B48C), // 베이지 버튼 (당근마켓 주황색 위치)
            foregroundColor: const Color(0xFFFFFFFF),
            elevation: 1,
            shadowColor: const Color(0xFF000000).withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6), // 당근마켓 스타일
            ),
          ),
        ),
        cardTheme: const CardTheme(
          color: Color(0xFFFFFFFF),         // 당근마켓 순백 카드
          shadowColor: Color(0xFF000000),
          elevation: 0.5,                   // 당근마켓 스타일 미약한 그림자
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFD2B48C), // 베이지 FAB (당근마켓 주황색 위치)
          foregroundColor: Color(0xFFFFFFFF),
          elevation: 3,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF), // 당근마켓 흰색 앱바
          foregroundColor: Color(0xFF000000), // 당근마켓 검은색 텍스트
          elevation: 0,
          shadowColor: Color(0xFF000000),
          surfaceTintColor: Color(0xFFFFFFFF),
        ),
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(builder: (context) => const HomeScreen());
          case '/create-meeting':
            return MaterialPageRoute(
              builder: (context) => const CreateMeetingScreen(),
              settings: settings, // arguments 전달을 위해 settings 추가
            );
          case '/meeting-detail':
            final meeting = settings.arguments as Meeting;
            return MaterialPageRoute(
              builder: (context) => MeetingDetailScreen(meeting: meeting),
            );
          case '/badge-test':
            return MaterialPageRoute(
              builder: (context) => const BadgeTestScreen(),
            );
          default:
            return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
      },
      debugShowCheckedModeBanner: false,
      ),
    );
  }
}
