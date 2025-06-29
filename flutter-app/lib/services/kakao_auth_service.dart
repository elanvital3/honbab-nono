import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_user;
import 'user_service.dart';
import 'auth_service.dart';

class KakaoAuthService {
  // 카카오 로그인 (카카오톡 앱 우선, 실패시 브라우저)
  static Future<app_user.User?> signInWithKakao() async {
    try {
      // 1. 카카오톡 설치 여부 확인
      bool isKakaoTalkAvailable = await isKakaoTalkInstalled();
      
      // 2. 카카오톡 앱으로 로그인 시도 (설치된 경우)
      if (isKakaoTalkAvailable) {
        try {
          await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            return null; // 사용자가 로그인을 취소한 경우
          }
          
          // 카카오톡 앱 로그인 실패 시 브라우저로 fallback
          await _loginWithKakaoAccount();
        }
      } else {
        // 카카오톡 앱이 설치되지 않은 경우 브라우저 로그인
        await _loginWithKakaoAccount();
      }

      // 3. 카카오 사용자 정보 가져오기
      User kakaoUser = await UserApi.instance.me();

      // 4. Firebase 연동 시작
      return await _createOrGetFirebaseUser(kakaoUser);
      
    } catch (error) {
      rethrow;
    }
  }

  // 카카오 계정으로 로그인
  static Future<void> _loginWithKakaoAccount() async {
    try {
      await UserApi.instance.loginWithKakaoAccount();
    } catch (error) {
      if (error is PlatformException && error.code == 'CANCELED') {
        rethrow; // 취소는 상위로 전달
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

      // Firebase 익명 인증
      final credential = await firebase_auth.FirebaseAuth.instance.signInAnonymously();
      final firebaseUser = credential.user;

      if (firebaseUser != null) {
        // Firestore에서 카카오 ID로 기존 사용자 찾기
        app_user.User? existingUser = await UserService.getUserByKakaoId(kakaoId);
        
        if (existingUser == null) {
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
          // 기존 사용자 문서 삭제 (이전 UID)
          await UserService.deleteUser(existingUser.id);
          
          // 새로운 UID로 사용자 문서 생성
          final updatedUser = existingUser.copyWith(
            id: firebaseUser.uid,
            profileImageUrl: profileImage,
            updatedAt: DateTime.now(),
          );
          
          await UserService.createUser(updatedUser);
          return updatedUser;
        }
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      await AuthService.signOut();
    } catch (error) {
      rethrow;
    }
  }

  // 카카오 연결 끊기 (회원 탈퇴)
  static Future<void> unlink() async {
    try {
      // 1. 카카오 연결 끊기 (실패해도 계속 진행)
      try {
        await UserApi.instance.unlink();
      } catch (kakaoError) {
        // 카카오 연결 끊기 실패해도 Firebase 계정 삭제는 진행
      }
      
      // 2. Firebase 계정 삭제 (반드시 실행)
      await AuthService.deleteAccount();
      
    } catch (error) {
      rethrow;
    }
  }
}