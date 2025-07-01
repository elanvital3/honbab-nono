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

  // Firebase 사용자 연동 (UID 영속성 보장)
  static Future<app_user.User?> _createOrGetFirebaseUser(User kakaoUser) async {
    try {
      final kakaoId = kakaoUser.id.toString();
      final email = kakaoUser.kakaoAccount?.email ?? '$kakaoId@kakao.com';
      final name = kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오사용자';
      final profileImage = kakaoUser.kakaoAccount?.profile?.profileImageUrl;

      if (kDebugMode) {
        print('🔍 카카오 사용자 연동 시작: $kakaoId');
      }

      // 1. 현재 Firebase 인증 상태 확인
      firebase_auth.User? currentFirebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      
      // 2. Firestore에서 카카오 ID로 기존 사용자 찾기
      app_user.User? existingUser = await UserService.getUserByKakaoId(kakaoId);
      
      if (existingUser != null) {
        if (kDebugMode) {
          print('✅ 기존 사용자 발견: ${existingUser.id} (카카오ID: $kakaoId)');
          print('  - 현재 Firebase 사용자: ${currentFirebaseUser?.uid ?? "없음"}');
        }
        
        // 3. Firebase UID 일치 여부 확인
        if (currentFirebaseUser != null && currentFirebaseUser.uid == existingUser.id) {
          if (kDebugMode) {
            print('♻️ 완벽한 세션 재사용: Firebase UID와 Firestore 데이터 일치');
          }
          
          // 완벽한 일치 - 프로필 이미지만 업데이트하고 기존 사용자 반환
          final updatedUser = existingUser.copyWith(
            profileImageUrl: profileImage,
            updatedAt: DateTime.now(),
          );
          
          // Firestore 업데이트 (UID 변경 없이)
          await UserService.updateUserFromObject(updatedUser);
          return updatedUser;
        }
        
        if (kDebugMode) {
          print('⚠️ Firebase UID 불일치 - 세션 정리 필요');
          print('  - Firestore UID: ${existingUser.id}');
          print('  - Firebase UID: ${currentFirebaseUser?.uid ?? "없음"}');
        }
        
        // 4. Firebase 세션 정리 (로그아웃 후 새로 시작)
        if (currentFirebaseUser != null) {
          await firebase_auth.FirebaseAuth.instance.signOut();
          if (kDebugMode) {
            print('🔄 기존 Firebase 세션 로그아웃 완료');
          }
        }
      }
      
      // 5. 새로운 Firebase 익명 인증 시작
      if (kDebugMode) {
        print('🆕 새로운 Firebase 익명 인증 시작');
      }
      
      final credential = await firebase_auth.FirebaseAuth.instance.signInAnonymously();
      final newFirebaseUser = credential.user;

      if (newFirebaseUser != null) {
        if (existingUser != null) {
          if (kDebugMode) {
            print('🔄 기존 사용자 데이터를 새 UID로 마이그레이션');
            print('  - 기존 UID: ${existingUser.id}');
            print('  - 새 UID: ${newFirebaseUser.uid}');
          }
          
          // 기존 사용자 데이터를 새 UID로 마이그레이션
          final migratedUser = existingUser.copyWith(
            id: newFirebaseUser.uid,
            profileImageUrl: profileImage,
            updatedAt: DateTime.now(),
          );
          
          // 안전한 마이그레이션 (트랜잭션 사용)
          await _migrateuserSafely(existingUser.id, migratedUser);
          return migratedUser;
          
        } else {
          if (kDebugMode) {
            print('🆕 완전히 새로운 사용자 생성: ${newFirebaseUser.uid}');
          }
          
          // 신규 사용자 생성
          return app_user.User(
            id: newFirebaseUser.uid,
            name: 'NEW_USER', // 신규 사용자 표시자
            email: email,
            profileImageUrl: profileImage,
            kakaoId: kakaoId,
          );
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase 사용자 연동 실패: $e');
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

  // 안전한 사용자 마이그레이션 (원자적 트랜잭션)
  static Future<void> _migrateuserSafely(String oldUid, app_user.User newUser) async {
    try {
      if (kDebugMode) {
        print('🔄 안전한 사용자 마이그레이션 시작');
        print('  - 기존 UID: $oldUid');
        print('  - 새 UID: ${newUser.id}');
      }

      // Firestore 트랜잭션으로 안전하게 마이그레이션
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final oldDocRef = FirebaseFirestore.instance.collection('users').doc(oldUid);
        final newDocRef = FirebaseFirestore.instance.collection('users').doc(newUser.id);
        
        // 1. 기존 문서 확인
        final oldDocSnapshot = await transaction.get(oldDocRef);
        if (!oldDocSnapshot.exists) {
          if (kDebugMode) {
            print('⚠️ 기존 사용자 문서가 존재하지 않음: $oldUid');
          }
          return;
        }
        
        // 2. 새 문서 생성
        transaction.set(newDocRef, newUser.toFirestore());
        
        // 3. 기존 문서 삭제
        transaction.delete(oldDocRef);
        
        if (kDebugMode) {
          print('✅ 트랜잭션 완료: $oldUid → ${newUser.id}');
        }
      });
      
      if (kDebugMode) {
        print('✅ 사용자 마이그레이션 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 사용자 마이그레이션 실패: $e');
      }
      
      // 마이그레이션 실패 시 폴백 - 기존 방식 사용
      await UserService.deleteUser(oldUid);
      await UserService.createUser(newUser);
      
      if (kDebugMode) {
        print('✅ 폴백 마이그레이션 완료');
      }
    }
  }
}