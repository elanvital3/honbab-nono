import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_user;
import 'user_service.dart';
import 'auth_service.dart';

class KakaoAuthService {
  // 카카오 로그인
  static Future<app_user.User?> signInWithKakao() async {
    try {
      // 카카오톡 설치 여부 확인
      final isKakaoTalkAvailable = await isKakaoTalkInstalled();
      if (kDebugMode) {
        print('🔍 카카오톡 설치 여부: $isKakaoTalkAvailable');
      }
      
      if (isKakaoTalkAvailable) {
        try {
          if (kDebugMode) {
            print('📱 카카오톡 앱으로 로그인 시도...');
          }
          // 카카오톡으로 로그인
          await UserApi.instance.loginWithKakaoTalk();
          if (kDebugMode) {
            print('✅ 카카오톡으로 로그인 성공');
          }
        } catch (error) {
          if (kDebugMode) {
            print('❌ 카카오톡으로 로그인 실패: $error');
          }
          
          // 카카오톡 로그인 실패시 카카오 계정으로 로그인
          if (error is PlatformException && error.code == 'CANCELED') {
            return null; // 사용자가 로그인을 취소한 경우
          }
          
          // 카카오 계정으로 로그인 시도
          await _loginWithKakaoAccount();
        }
      } else {
        if (kDebugMode) {
          print('🌐 카카오톡이 설치되어 있지 않음 - 웹 로그인으로 진행');
        }
        // 카카오톡이 설치되어 있지 않으면 카카오 계정으로 로그인
        await _loginWithKakaoAccount();
      }

      // 카카오 사용자 정보 가져오기
      User kakaoUser = await UserApi.instance.me();
      
      if (kDebugMode) {
        print('📋 카카오 사용자 상세 정보:');
        print('  - ID: ${kakaoUser.id}');
        print('  - 닉네임: ${kakaoUser.kakaoAccount?.profile?.nickname}');
        print('  - 프로필 사진: ${kakaoUser.kakaoAccount?.profile?.profileImageUrl}');
        print('  - 이메일: ${kakaoUser.kakaoAccount?.email}');
        print('  - 전체 프로필 정보: ${kakaoUser.kakaoAccount?.profile}');
      }

      // Firebase Custom Token으로 로그인 (백엔드 필요)
      // 현재는 임시로 이메일/비밀번호로 Firebase 계정 생성
      return await _createOrGetFirebaseUser(kakaoUser);
      
    } catch (error) {
      if (kDebugMode) {
        print('❌ 카카오 로그인 에러: $error');
      }
      rethrow;
    }
  }

  // 카카오 계정으로 로그인
  static Future<void> _loginWithKakaoAccount() async {
    try {
      await UserApi.instance.loginWithKakaoAccount();
      if (kDebugMode) {
        print('✅ 카카오 계정으로 로그인 성공');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ 카카오 계정으로 로그인 실패: $error');
      }
      rethrow;
    }
  }

  // Firebase 익명 인증으로 카카오 사용자 연동
  static Future<app_user.User?> _createOrGetFirebaseUser(User kakaoUser) async {
    try {
      final kakaoId = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email ?? '$kakaoId@kakao.com';
      final name = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오사용자';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (kDebugMode) {
        print('🔥 Firebase 익명 인증 시작...');
      }

      // Firebase 익명 인증
      final credential = await firebase_auth.FirebaseAuth.instance.signInAnonymously();
      final firebaseUser = credential.user;

      if (firebaseUser != null) {
        if (kDebugMode) {
          print('✅ Firebase 익명 인증 성공: ${firebaseUser.uid}');
        }

        if (kDebugMode) {
          print('🔍 Firestore에서 기존 사용자 확인 중...');
        }

        // Firestore에서 카카오 ID로 기존 사용자 찾기
        app_user.User? existingUser = await UserService.getUserByKakaoId(kakaoId);
        
        if (existingUser == null) {
          // 신규 사용자 - 특별한 표시자와 함께 반환
          if (kDebugMode) {
            print('🆕 신규 사용자 감지 - 닉네임 입력 화면으로 이동해야 함');
            print('  - 카카오 ID: $kakaoId');
            print('  - Firebase UID: ${firebaseUser.uid}');
            print('  - 카카오 닉네임: $name');
          }
          
          // 신규 사용자임을 명확히 표시 (name을 "NEW_USER"로 설정)
          return app_user.User(
            id: firebaseUser.uid,
            name: 'NEW_USER', // 신규 사용자 표시자
            email: email,
            profileImageUrl: profileImage,
            kakaoId: kakaoId,
          );
        } else {
          // 기존 사용자 - Firebase UID 업데이트 후 반환
          if (kDebugMode) {
            print('✅ 기존 사용자 발견: ${existingUser.name}');
            print('  - 기존 Firebase UID: ${existingUser.id}');
            print('  - 새 Firebase UID: ${firebaseUser.uid}');
          }

          // 기존 사용자의 Firebase UID와 프로필 사진 업데이트
          await UserService.updateUser(existingUser.id, {
            'id': firebaseUser.uid,
            'profileImageUrl': profileImage, // 최신 프로필 사진으로 업데이트
            'updatedAt': DateTime.now(),
          });
          
          // 업데이트된 사용자 정보 반환
          final updatedUser = existingUser.copyWith(
            id: firebaseUser.uid,
            profileImageUrl: profileImage,
          );
          
          if (kDebugMode) {
            print('✅ 기존 사용자 정보 업데이트 완료');
          }
          return updatedUser;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase 사용자 생성/가져오기 실패: $e');
      }
      rethrow;
    }
  }

  // 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      await AuthService.signOut();
      
      if (kDebugMode) {
        print('✅ 카카오 로그아웃 성공');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ 카카오 로그아웃 실패: $error');
      }
      rethrow;
    }
  }

  // 카카오 연결 끊기 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      await UserApi.instance.unlink();
      await AuthService.deleteAccount();
      
      if (kDebugMode) {
        print('✅ 카카오 연결 끊기 성공');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ 카카오 연결 끊기 실패: $error');
      }
      rethrow;
    }
  }
}