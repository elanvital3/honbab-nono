import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart' as app_user;
import 'user_service.dart';
import 'notification_service.dart';

class KakaoAuthService {
  static final KakaoAuthService _instance = KakaoAuthService._internal();
  factory KakaoAuthService() => _instance;
  KakaoAuthService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 카카오 로그인 후 Firebase Auth와 연동 (Custom Token 방식)
  static Future<app_user.User?> signInWithKakao() async {
    try {
      // 1. 카카오톡 설치 여부 확인
      final isKakaoTalkInstalled = await isKakaoTalkInstalled();
      
      OAuthToken token;
      if (isKakaoTalkInstalled) {
        if (kDebugMode) {
          print('🔄 카카오톡 앱으로 로그인 시도...');
        }
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        if (kDebugMode) {
          print('🔄 카카오 웹으로 로그인 시도...');
        }
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      if (kDebugMode) {
        print('✅ 카카오 로그인 성공');
      }

      // 2. 카카오 사용자 정보 가져오기
      final User kakaoUser = await UserApi.instance.me();
      final kakaoId = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email;
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '사용자';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (kDebugMode) {
        print('👤 카카오 사용자 정보:');
        print('  - ID: $kakaoId');
        print('  - 닉네임: $nickname');
        print('  - 이메일: $email');
      }

      // 3. 카카오 ID 기반 Custom Token 생성 (서버 호출)
      try {
        final callable = _functions.httpsCallable('createCustomToken');
        final result = await callable.call({
          'kakaoId': kakaoId,
        });
        
        final customToken = result.data['customToken'] as String;
        
        // 4. Custom Token으로 Firebase 로그인
        final credential = await firebase_auth.FirebaseAuth.instance
            .signInWithCustomToken(customToken);
        
        final firebaseUser = credential.user;
        
        if (firebaseUser != null) {
          // 5. Firestore에서 사용자 정보 확인/생성
          final userDoc = await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
          
          if (userDoc.exists) {
            // 기존 사용자 - 프로필 정보 업데이트
            final existingUser = app_user.User.fromFirestore(userDoc);
            final updatedUser = existingUser.copyWith(
              profileImageUrl: profileImage,
              updatedAt: DateTime.now(),
            );
            
            await UserService.updateUserFromObject(updatedUser);
            
            if (kDebugMode) {
              print('✅ 기존 사용자 로그인 완료: ${firebaseUser.uid}');
            }
            
            return updatedUser;
          } else {
            // 신규 사용자
            if (kDebugMode) {
              print('🆕 신규 사용자 감지: ${firebaseUser.uid}');
            }
            
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
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Custom Token 방식 실패, 기존 방식으로 fallback: $e');
        }
        
        // Fallback: 기존 익명 인증 방식 (Custom Token 미구현 시)
        return await _signInWithKakaoAnonymous(
          kakaoId: kakaoId,
          email: email,
          nickname: nickname,
          profileImage: profileImage,
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 카카오 로그인 실패: $e');
      }
      rethrow;
    }
  }

  /// Fallback: 익명 인증 방식 (Custom Token 미구현 시)
  static Future<app_user.User?> _signInWithKakaoAnonymous({
    required String kakaoId,
    String? email,
    required String nickname,
    String? profileImage,
  }) async {
    // 카카오 ID 기반으로 기존 사용자 찾기
    final existingUserQuery = await _firestore
        .collection('users')
        .where('kakaoId', isEqualTo: kakaoId)
        .limit(1)
        .get();
    
    if (existingUserQuery.docs.isNotEmpty) {
      // 기존 사용자 있음
      final existingUser = app_user.User.fromFirestore(existingUserQuery.docs.first);
      
      // 현재 Firebase 세션 확인
      final currentFirebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      
      if (currentFirebaseUser != null && currentFirebaseUser.uid == existingUser.id) {
        // 완벽한 일치 - 세션 재사용
        final updatedUser = existingUser.copyWith(
          profileImageUrl: profileImage,
          updatedAt: DateTime.now(),
        );
        
        await UserService.updateUserFromObject(updatedUser);
        return updatedUser;
      }
    }
    
    // 새로운 익명 인증
    final credential = await firebase_auth.FirebaseAuth.instance.signInAnonymously();
    final firebaseUser = credential.user;
    
    if (firebaseUser != null) {
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
  }

  /// 로그아웃
  static Future<void> signOut() async {
    try {
      // 카카오 로그아웃
      await UserApi.instance.logout();
      
      // Firebase 로그아웃
      await firebase_auth.FirebaseAuth.instance.signOut();
      
      if (kDebugMode) {
        print('✅ 로그아웃 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 로그아웃 실패: $e');
      }
      rethrow;
    }
  }

  /// 회원 탈퇴
  static Future<void> deleteAccount() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인된 사용자가 없습니다');
      }

      // 1. Firestore에서 사용자 데이터 삭제
      await UserService.deleteUser(currentUser.uid);
      
      // 2. Firebase Auth 계정 삭제
      await currentUser.delete();
      
      // 3. 카카오 연결 끊기
      await UserApi.instance.unlink();
      
      if (kDebugMode) {
        print('✅ 회원 탈퇴 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 회원 탈퇴 실패: $e');
      }
      rethrow;
    }
  }
}