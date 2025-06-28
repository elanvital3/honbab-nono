import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/user_service.dart';
import '../../models/user.dart' as app_user;
import 'login_screen.dart';
import '../home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Firestore 사용자 데이터 가져오기 (재시도 로직 포함)
  Future<app_user.User?> _getFirestoreUserWithRetry(String uid) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      if (kDebugMode) {
        print('🔄 AuthWrapper: Firestore 조회 시도 $attempt/3');
      }
      
      try {
        final user = await UserService.getUser(uid);
        if (user != null) {
          if (kDebugMode) {
            print('✅ AuthWrapper: 시도 $attempt에서 사용자 데이터 찾음');
          }
          return user;
        }
        
        // 첫 번째와 두 번째 시도에서 null이면 잠깐 대기
        if (attempt < 3) {
          if (kDebugMode) {
            print('⏳ AuthWrapper: 시도 $attempt 실패, ${attempt * 500}ms 대기 후 재시도...');
          }
          await Future.delayed(Duration(milliseconds: attempt * 500));
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AuthWrapper: 시도 $attempt 오류: $e');
        }
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: attempt * 500));
        }
      }
    }
    
    if (kDebugMode) {
      print('❌ AuthWrapper: 3번 시도 모두 실패, null 반환');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = Provider.of<firebase_auth.User?>(context);
    
    if (kDebugMode) {
      print('🔐 AuthWrapper: Firebase 사용자 상태 확인');
      print('  - Firebase User: ${firebaseUser?.uid ?? "null"}');
      print('  - 이메일: ${firebaseUser?.email ?? "없음"}');
      print('  - 익명 로그인: ${firebaseUser?.isAnonymous ?? false}');
    }
    
    // Firebase 사용자가 없으면 로그인 화면
    if (firebaseUser == null) {
      if (kDebugMode) {
        print('❌ AuthWrapper: Firebase 사용자 없음 → 로그인 화면으로 이동');
      }
      return const LoginScreen();
    }
    
    if (kDebugMode) {
      print('✅ AuthWrapper: Firebase 사용자 있음 → Firestore 데이터 확인 중');
    }
    
    // Firebase 사용자는 있지만 Firestore 데이터 확인 필요
    return FutureBuilder<app_user.User?>(
      future: _getFirestoreUserWithRetry(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            print('⏳ AuthWrapper: Firestore 사용자 데이터 로딩 중...');
          }
          // 로딩 중 - 미니멀한 로딩 화면
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD2B48C),
                strokeWidth: 2,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('❌ AuthWrapper: Firestore 조회 오류 → 로그인 화면으로');
            print('  - 오류: ${snapshot.error}');
          }
          // 에러 발생 시 로그인 화면으로
          return const LoginScreen();
        }
        
        final firestoreUser = snapshot.data;
        
        if (kDebugMode) {
          print('🔍 AuthWrapper: Firestore 사용자 데이터 확인');
          if (firestoreUser != null) {
            print('  - 사용자 ID: ${firestoreUser.id}');
            print('  - 사용자 이름: "${firestoreUser.name}"');
            print('  - 카카오 ID: ${firestoreUser.kakaoId}');
            print('  - 이메일: ${firestoreUser.email}');
          } else {
            print('  - Firestore 사용자 데이터: null');
          }
        }
        
        if (firestoreUser != null && firestoreUser.name.isNotEmpty && firestoreUser.name != 'NEW_USER') {
          if (kDebugMode) {
            print('✅ AuthWrapper: 완전한 사용자 데이터 확인 → 홈 화면으로 이동');
            print('  - 사용자: ${firestoreUser.name}');
          }
          // 완전한 사용자 데이터가 있으면 홈 화면
          return const HomeScreen();
        } else {
          if (kDebugMode) {
            print('❌ AuthWrapper: 불완전한 사용자 데이터 → 로그인 화면으로');
            if (firestoreUser != null) {
              print('  - 이름: "${firestoreUser.name}"');
              print('  - NEW_USER 여부: ${firestoreUser.name == 'NEW_USER'}');
            }
          }
          // Firestore에 데이터가 없거나 불완전하면 로그인 화면
          return const LoginScreen();
        }
      },
    );
  }
}