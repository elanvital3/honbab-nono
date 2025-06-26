import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honbab_nono/main.dart';
import 'package:honbab_nono/screens/auth/login_screen.dart';
import 'package:honbab_nono/screens/home/home_screen.dart';

void main() {
  group('HonbabNoNo App Tests', () {
    testWidgets('App launches with LoginScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const HonbabNoNoApp());

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('혼밥노노'), findsOneWidget);
      expect(find.text('🍽️'), findsOneWidget);
    });

    testWidgets('Social login buttons are present', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      expect(find.text('카카오로 시작하기'), findsOneWidget);
      expect(find.text('구글로 시작하기'), findsOneWidget);
      expect(find.text('네이버로 시작하기'), findsOneWidget);
    });

    testWidgets('Login navigates to HomeScreen', (WidgetTester tester) async {
      await tester.pumpWidget(const HonbabNoNoApp());
      
      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();
      
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('홈'), findsOneWidget);
    });

    testWidgets('HomeScreen has bottom navigation', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      
      expect(find.text('홈'), findsOneWidget);
      expect(find.text('지도'), findsOneWidget);
      expect(find.text('채팅'), findsOneWidget);
      expect(find.text('마이페이지'), findsOneWidget);
    });

    testWidgets('HomeScreen has floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('App theme uses correct primary color', (WidgetTester tester) async {
      await tester.pumpWidget(const HonbabNoNoApp());
      
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.theme?.colorScheme.primary, const Color(0xFFFF6B6B));
    });
  });
}
