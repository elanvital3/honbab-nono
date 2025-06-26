import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/meeting/create_meeting_screen.dart';
import 'screens/meeting/meeting_detail_screen.dart';
import 'models/meeting.dart';

void main() {
  runApp(const HonbabNoNoApp());
}

class HonbabNoNoApp extends StatelessWidget {
  const HonbabNoNoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const LoginScreen(),
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
    );
  }
}
