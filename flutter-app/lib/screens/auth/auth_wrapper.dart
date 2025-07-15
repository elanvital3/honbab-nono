import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/user_service.dart';
import '../../services/notification_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../models/user.dart' as app_user;
import '../splash/splash_screen.dart';
import 'login_screen.dart';
import 'privacy_consent_screen.dart';
import '../home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Firestore 사용자 데이터 가져오기 (재시도 로직 포함)
  Future<app_user.User?> _getFirestoreUserWithRetry(String uid) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      if (kDebugMode) {
        print('🔄 AuthWrapper: Firestore 조회 시도 $attempt/2');
      }
      
      try {
        final user = await UserService.getUser(uid);
        if (user != null) {
          if (kDebugMode) {
            print('✅ AuthWrapper: 시도 $attempt에서 사용자 데이터 찾음');
          }
          return user;
        }
        
        // 첫 번째 시도에서 null이면 잠깐 대기
        if (attempt < 2) {
          if (kDebugMode) {
            print('⏳ AuthWrapper: 시도 $attempt 실패, ${attempt * 1000}ms 대기 후 재시도...');
          }
          await Future.delayed(Duration(milliseconds: attempt * 1000));
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AuthWrapper: 시도 $attempt 오류: $e');
        }
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: attempt * 1000));
        }
      }
    }
    
    if (kDebugMode) {
      print('❌ AuthWrapper: 2번 시도 모두 실패, null 반환');
    }
    return null;
  }

  // FCM 토큰을 백그라운드에서 저장
  void _saveFCMTokenInBackground(String userId) {
    Future.microtask(() async {
      try {
        await NotificationService().saveFCMTokenToFirestore(userId);
        if (kDebugMode) {
          print('✅ AuthWrapper: FCM 토큰 저장 백그라운드 작업 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AuthWrapper: FCM 토큰 저장 실패: $e');
        }
      }
    });
  }

  // 미완성 Firebase Auth 삭제 (백그라운드에서 실행)
  void _deleteIncompleteFirebaseAuth(firebase_auth.User firebaseUser) {
    Future.microtask(() async {
      try {
        await firebaseUser.delete();
        if (kDebugMode) {
          print('✅ AuthWrapper: 미완성 Firebase Auth 삭제 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ AuthWrapper: Firebase Auth 삭제 실패: $e');
        }
      }
    });
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
      
      // 카카오 정보가 있으면 신규 사용자 처리
      final kakaoInfo = KakaoAuthService.getTempKakaoUserInfo();
      if (kakaoInfo != null) {
        if (kDebugMode) {
          print('✅ AuthWrapper: 카카오 정보 발견 → PrivacyConsentScreen으로 이동');
        }
        return PrivacyConsentScreen(
          userId: null,
          email: kakaoInfo['email'],
          kakaoId: kakaoInfo['kakaoId'],
          defaultName: kakaoInfo['name'],
          profileImageUrl: kakaoInfo['profileImageUrl'],
        );
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
        
        if (firestoreUser != null && firestoreUser.name.isNotEmpty) {
          if (kDebugMode) {
            print('✅ AuthWrapper: 완전한 사용자 데이터 확인 → 홈 화면으로 이동');
            print('  - 사용자: ${firestoreUser.name}');
          }
          
          // FCM 토큰을 Firestore에 저장 (백그라운드에서 실행)
          _saveFCMTokenInBackground(firestoreUser.id);
          
          return const HomeScreen();
        } else {
          // Firestore에 사용자 데이터가 없음 → 미완성 회원가입으로 판단
          if (kDebugMode) {
            print('🧹 AuthWrapper: Firestore 사용자 없음 → 미완성 회원가입 정리');
            print('  - Firebase Auth UID: ${firebaseUser.uid}');
          }
          
          // 미완성 회원가입 정리 (Firebase Auth 삭제) - 비동기 처리
          _deleteIncompleteFirebaseAuth(firebaseUser);
          
          // 카카오 정보 확인
          final kakaoInfo = KakaoAuthService.getTempKakaoUserInfo();
          if (kakaoInfo != null) {
            if (kDebugMode) {
              print('✅ AuthWrapper: 카카오 정보 발견 → PrivacyConsentScreen으로 이동');
            }
            return PrivacyConsentScreen(
              userId: null,
              email: kakaoInfo['email'],
              kakaoId: kakaoInfo['kakaoId'],
              defaultName: kakaoInfo['name'],
              profileImageUrl: kakaoInfo['profileImageUrl'],
            );
          } else {
            if (kDebugMode) {
              print('❌ AuthWrapper: 카카오 정보 없음 → 로그인 화면으로');
            }
            return const LoginScreen();
          }
        }
      },
    );
  }
}