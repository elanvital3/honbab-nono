import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_complete_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/meeting/create_meeting_screen.dart';
import 'screens/meeting/meeting_detail_screen.dart';
import 'screens/test/firebase_test_screen.dart';
import 'models/meeting.dart';
import 'models/user.dart' as app_user;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: 'aa44527cad103e9986ceedb39cc915f9');
  print('✅ 카카오 SDK 초기화 성공');
  
  try {
    // Firebase 초기화
    await FirebaseConfig.initialize();
    print('✅ Firebase 초기화 성공');
  } catch (e) {
    print('❌ Firebase 초기화 실패: $e');
  }
  
  try {
    // 카카오맵 초기화 - JavaScript 키 적용
    await KakaoMapsFlutter.init('72f1d70089c36f4a8c9fabe7dc6be080');
    print('✅ 카카오맵 초기화 성공');
  } catch (e) {
    print('❌ 카카오맵 초기화 실패: $e');
  }
  
  runApp(const HonbabNoNoApp());
}

class HonbabNoNoApp extends StatelessWidget {
  const HonbabNoNoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<firebase_auth.User?>.value(
      value: AuthService.authStateChanges,
      initialData: null,
      child: MaterialApp(
      title: '혼밥노노',
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
            return MaterialPageRoute(builder: (context) => const CreateMeetingScreen());
          case '/meeting-detail':
            final meeting = settings.arguments as Meeting;
            return MaterialPageRoute(
              builder: (context) => MeetingDetailScreen(meeting: meeting),
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<firebase_auth.User?>(context);
    
    // Firebase 사용자가 없으면 로그인 화면
    if (firebaseUser == null) {
      return const LoginScreen();
    }
    
    // Firebase 사용자는 있지만 Firestore 데이터 확인 필요
    return FutureBuilder<app_user.User?>(
      future: UserService.getUser(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 중
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD2B48C),
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          // 에러 발생 시 로그인 화면으로
          return const LoginScreen();
        }
        
        final firestoreUser = snapshot.data;
        
        if (firestoreUser != null && firestoreUser.name.isNotEmpty && firestoreUser.name != 'NEW_USER') {
          // 완전한 사용자 데이터가 있으면 홈 화면
          return const HomeScreen();
        } else {
          // Firestore에 데이터가 없거나 불완전하면 로그인 화면
          return const LoginScreen();
        }
      },
    );
  }
}
