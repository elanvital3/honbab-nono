import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart' as app_user;
import 'user_service.dart';
import 'auth_service.dart';

class KakaoAuthService {
  // 신규 사용자의 카카오 정보를 임시 저장 (회원가입 프로세스에서 사용)
  static Map<String, dynamic>? _tempKakaoUserInfo;
  
  // 임시 카카오 정보 가져오기 (삭제하지 않음)
  static Map<String, dynamic>? getTempKakaoUserInfo() {
    return _tempKakaoUserInfo;
  }
  
  // 임시 카카오 정보 삭제
  static void clearTempKakaoUserInfo() {
    _tempKakaoUserInfo = null;
  }

  // 회원가입 완료 시점에서 Firebase Auth + Firestore 동시 생성
  static Future<app_user.User?> createFirebaseUserOnSignupComplete(
    String email,
    String kakaoId,
    String name,
    String? profileImageUrl,
    {
      String? phoneNumber,
      String? gender,
      int? birthYear,
      List<String>? badges,
      DateTime? adultVerifiedAt,
    }
  ) async {
    try {
      if (kDebugMode) {
        print('🔥 회원가입 완료 - Firebase Auth + Firestore 동시 생성 시작');
        print('  - 이메일: $email');
        print('  - 카카오ID: $kakaoId');
        print('  - 닉네임: $name');
      }

      // 1. Firebase Auth 생성 (처음 생성)
      final firebaseUser = await _createOrSignInWithEmail(email, kakaoId);
      
      if (firebaseUser != null) {
        // 2. Firestore 사용자 생성
        final newUser = app_user.User(
          id: firebaseUser.uid,
          name: name,
          email: email,
          phoneNumber: phoneNumber,
          profileImageUrl: profileImageUrl,
          kakaoId: kakaoId,
          gender: gender,
          birthYear: birthYear,
          badges: badges ?? [],
          isAdultVerified: true, // 모든 가입자를 인증된 것으로 처리
          adultVerifiedAt: adultVerifiedAt,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 3. Firestore에 저장
        await UserService.createUser(newUser);
        
        if (kDebugMode) {
          print('✅ Firebase Auth + Firestore 동시 생성 완료');
          print('  - Firebase UID: ${firebaseUser.uid}');
          print('  - Firestore 사용자 생성 완료');
        }

        // 4. 임시 카카오 정보 삭제
        clearTempKakaoUserInfo();

        return newUser;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth + Firestore 동시 생성 실패: $e');
      }
      rethrow;
    }
  }
  
  // 카카오 로그인 (Firebase Auth 생성하지 않음)
  static Future<bool> signInWithKakao() async {
    try {
      // 1. 카카오톡 설치 여부 확인
      bool isKakaoTalkAvailable = await isKakaoTalkInstalled();
      
      // 2. 카카오톡 앱으로 로그인 시도 (설치된 경우)
      if (isKakaoTalkAvailable) {
        try {
          await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          if (error is PlatformException && error.code == 'CANCELED') {
            return false; // 사용자가 로그인을 취소한 경우
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

      // 4. 카카오 정보를 메모리에 저장 (Firebase Auth 생성하지 않음)
      return await _saveKakaoUserInfo(kakaoUser);
      
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

  // 카카오 사용자 정보를 메모리에 저장 (Firebase Auth 생성하지 않음)
  static Future<bool> _saveKakaoUserInfo(User kakaoUser) async {
    try {
      final kakaoId = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email;
      final name = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오사용자';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (kDebugMode) {
        print('🔍 카카오 사용자 정보 저장 시작: $kakaoId');
        print('📧 카카오 이메일: $email');
      }

      // 이메일 확인
      if (email == null || email.isEmpty) {
        throw Exception('카카오 계정의 이메일 정보가 필요합니다. 카카오 계정 설정에서 이메일을 공개로 설정해주세요.');
      }

      // 신규 사용자 - 메모리에 카카오 정보만 저장 (Firebase Auth 생성하지 않음)
      _tempKakaoUserInfo = {
        'email': email,
        'kakaoId': kakaoId,
        'name': name,
        'profileImageUrl': profileImage,
      };
      
      if (kDebugMode) {
        print('🆕 카카오 정보 메모리 저장 완료 (Firebase Auth 생성 없음)');
        print('   이메일: $email');
        print('   카카오ID: $kakaoId');
        print('   닉네임: $name');
        print('   프로필 이미지: $profileImage');
      }
      
      return true;
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 카카오 사용자 정보 저장 실패: $e');
      }
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
  
  // 카카오 ID를 기반으로 안전한 비밀번호 생성
  static String _generatePasswordFromKakaoId(String kakaoId) {
    // 고정 salt 값과 카카오 ID를 조합하여 해시 생성
    const salt = 'honbabnono_2025_firebase_auth_salt';
    final bytes = utf8.encode('$kakaoId$salt');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  // 이메일로 Firebase 로그인
  static Future<void> _signInWithEmail(String email, String kakaoId) async {
    try {
      final password = _generatePasswordFromKakaoId(kakaoId);
      
      await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        print('✅ Firebase 이메일 로그인 성공');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase 이메일 로그인 실패: $e');
      }
      rethrow;
    }
  }
  
  // 이메일로 Firebase 계정 생성 또는 로그인
  static Future<firebase_auth.User?> _createOrSignInWithEmail(String email, String kakaoId) async {
    try {
      final password = _generatePasswordFromKakaoId(kakaoId);
      
      try {
        // 먼저 기존 계정 로그인 시도 (UID 재사용 우선)
        final credential = await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (kDebugMode) {
          print('✅ Firebase 이메일 로그인 성공 (기존 UID 재사용)');
        }
        
        return credential.user;
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // 계정이 없거나 비밀번호가 틀리면 새 계정 생성
          if (kDebugMode) {
            print('🔄 기존 계정 없음, 새 계정 생성 시도: ${e.code}');
          }
          
          final credential = await firebase_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          if (kDebugMode) {
            print('✅ Firebase 이메일 계정 생성 성공 (새 UID)');
          }
          
          return credential.user;
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase 이메일 인증 실패: $e');
      }
      rethrow;
    }
  }

}