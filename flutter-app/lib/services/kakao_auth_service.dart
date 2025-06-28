import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
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
            if (error is PlatformException && error.code == 'NotSupportError') {
              print('💡 원인: 카카오톡이 카카오 계정에 연결되지 않음 (에뮬레이터 환경)');
            }
            print('🔄 웹 브라우저 로그인으로 자동 전환...');
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
      if (kDebugMode) {
        print('🌐 카카오 계정 로그인 시작...');
      }
      await UserApi.instance.loginWithKakaoAccount();
      if (kDebugMode) {
        print('✅ 카카오 계정으로 로그인 성공');
      }
    } catch (error) {
      if (kDebugMode) {
        print('❌ 카카오 계정으로 로그인 실패: $error');
      }
      // 사용자 취소 외에는 예외를 다시 던지지 않고 null 반환
      if (error is PlatformException && error.code != 'CANCELED') {
        if (kDebugMode) {
          print('🚫 로그인 실패 - 오류 무시하고 계속');
        }
        return; // 예외를 던지지 않고 종료
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
        if (kDebugMode) {
          print('🔍 카카오 ID로 기존 사용자 검색 중: $kakaoId');
        }
        app_user.User? existingUser = await UserService.getUserByKakaoId(kakaoId);
        if (kDebugMode) {
          print('🔍 기존 사용자 검색 결과: ${existingUser != null ? "발견됨 (${existingUser.name})" : "없음"}');
        }
        
        if (existingUser == null) {
          // 신규 사용자 - 특별한 표시자와 함께 반환
          if (kDebugMode) {
            print('🆕 신규 사용자 감지 - 닉네임 입력 화면으로 이동해야 함');
            print('  - 카카오 ID: $kakaoId');
            print('  - Firebase UID: ${firebaseUser.uid}');
            print('  - 카카오 닉네임: $name');
            print('  - 이메일: $email');
            print('  - 프로필 이미지: $profileImage');
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

          // 기존 사용자 문서 삭제 (이전 UID)
          if (kDebugMode) {
            print('🗑️ 기존 사용자 문서 삭제 중: ${existingUser.id}');
          }
          await UserService.deleteUser(existingUser.id);
          
          // 새로운 UID로 사용자 문서 생성
          final updatedUser = existingUser.copyWith(
            id: firebaseUser.uid,
            profileImageUrl: profileImage,
            updatedAt: DateTime.now(),
          );
          
          if (kDebugMode) {
            print('📝 새로운 UID로 사용자 문서 생성: ${firebaseUser.uid}');
          }
          await UserService.createUser(updatedUser);
          
          if (kDebugMode) {
            print('✅ 기존 사용자 정보 마이그레이션 완료');
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
    String? lastError;
    
    try {
      if (kDebugMode) {
        print('🔄 회원탈퇴 프로세스 시작');
      }
      
      // 1. 카카오 연결 끊기 (실패해도 계속 진행)
      try {
        if (kDebugMode) {
          print('🔄 카카오 연결 끊기 시도...');
        }
        await UserApi.instance.unlink();
        if (kDebugMode) {
          print('✅ 카카오 연결 끊기 성공');
        }
      } catch (kakaoError) {
        lastError = kakaoError.toString();
        if (kDebugMode) {
          print('⚠️ 카카오 연결 끊기 실패 (계속 진행): $kakaoError');
        }
      }
      
      // 2. Firebase 계정 삭제 (반드시 실행)
      try {
        if (kDebugMode) {
          print('🔄 Firebase 계정 삭제 시도...');
        }
        await AuthService.deleteAccount();
        if (kDebugMode) {
          print('✅ Firebase 계정 삭제 성공');
        }
      } catch (firebaseError) {
        if (kDebugMode) {
          print('❌ Firebase 계정 삭제 실패: $firebaseError');
        }
        throw firebaseError; // Firebase 삭제는 반드시 성공해야 함
      }
      
      if (kDebugMode) {
        if (lastError != null) {
          print('⚠️ 회원탈퇴 완료 (카카오 연결 끊기 실패했지만 Firebase 계정은 삭제됨)');
        } else {
          print('✅ 회원탈퇴 완전 성공');
        }
      }
      
    } catch (error) {
      if (kDebugMode) {
        print('❌ 회원탈퇴 실패: $error');
      }
      rethrow;
    }
  }
}