import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Firebase 사용자 연동 (익명 인증 + 카카오 정보 연결)
  static Future<app_user.User?> _createOrGetFirebaseUser(User kakaoUser) async {
    try {
      final kakaoId = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email ?? '$kakaoId@kakao.com';
      final name = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오사용자';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (kDebugMode) {
        print('🔍 카카오 사용자 연동 시작: $kakaoId');
      }

      // 1. 카카오 ID로 기존 사용자 찾기
      app_user.User? existingUser = await UserService.getUserByKakaoId(kakaoId);
      
      if (existingUser != null) {
        if (kDebugMode) {
          print('✅ 기존 사용자 발견: ${existingUser.id}');
        }
        
        // 기존 사용자 - 프로필 정보 업데이트하고 Firebase 로그인
        await _signInWithExistingUser(existingUser, profileImage);
        
        final updatedUser = existingUser.copyWith(
          profileImageUrl: profileImage,
          updatedAt: DateTime.now(),
        );
        
        await UserService.updateUserFromObject(updatedUser);
        return updatedUser;
      }
      
      // 2. 신규 사용자 - Firebase 익명 인증
      if (kDebugMode) {
        print('🆕 신규 사용자 - Firebase 익명 인증 시작');
      }
      
      final credential = await firebase_auth.FirebaseAuth.instance.signInAnonymously();
      final firebaseUser = credential.user;
      
      if (firebaseUser != null) {
        if (kDebugMode) {
          print('✅ Firebase 익명 인증 완료: ${firebaseUser.uid}');
        }
        
        // 신규 사용자 데이터 생성
        return app_user.User(
          id: firebaseUser.uid,
          name: 'NEW_USER',
          email: email,
          profileImageUrl: profileImage,
          kakaoId: kakaoId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase 사용자 연동 실패: $e');
      }
      rethrow;
    }
  }
  
  // 기존 사용자를 위한 Firebase 재인증
  static Future<void> _signInWithExistingUser(app_user.User existingUser, String? profileImage) async {
    try {
      // 현재 Firebase 사용자와 기존 사용자 ID가 다르면 재인증
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      
      if (currentUser == null || currentUser.uid != existingUser.id) {
        if (kDebugMode) {
          print('🔄 기존 사용자를 위한 Firebase 재인증 필요');
        }
        
        // 로그아웃 후 새로 익명 인증 (기존 UID는 Firestore에서 관리)
        if (currentUser != null) {
          await firebase_auth.FirebaseAuth.instance.signOut();
        }
        
        await firebase_auth.FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firebase 재인증 실패, 계속 진행: $e');
      }
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