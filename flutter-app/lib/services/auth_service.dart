import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'user_service.dart';

class AuthService {
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // 현재 사용자 가져오기
  static firebase_auth.User? get currentFirebaseUser => _auth.currentUser;
  static firebase_auth.User? get currentUser => _auth.currentUser;
  
  // 현재 사용자 ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // 로그인 상태 스트림
  static Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  // 이메일 회원가입
  static Future<User?> signUpWithEmail(String email, String password, String name) async {
    try {
      // Firebase Auth 계정 생성
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 사용자 프로필 업데이트
        await credential.user!.updateDisplayName(name);

        // Firestore에 사용자 정보 저장
        final user = User(
          id: credential.user!.uid,
          name: name,
          email: email,
        );

        await UserService.createUser(user);

        if (kDebugMode) {
          print('✅ User signed up: ${credential.user!.uid}');
        }

        return user;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing up: $e');
      }
      rethrow;
    }
  }

  // 이메일 로그인
  static Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Firestore에서 사용자 정보 가져오기
        final user = await UserService.getUser(credential.user!.uid);
        
        if (kDebugMode) {
          print('✅ User signed in: ${credential.user!.uid}');
        }

        return user;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing in: $e');
      }
      rethrow;
    }
  }

  // 구글 로그인 (준비)
  static Future<User?> signInWithGoogle() async {
    try {
      // TODO: Google Sign-In 패키지 추가 후 구현
      // google_sign_in: ^6.1.5
      
      throw UnimplementedError('Google Sign-In not implemented yet');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing in with Google: $e');
      }
      rethrow;
    }
  }

  // 카카오 로그인 (준비)
  static Future<User?> signInWithKakao() async {
    try {
      // TODO: Kakao SDK 추가 후 구현
      // kakao_flutter_sdk: ^1.9.0
      
      throw UnimplementedError('Kakao Sign-In not implemented yet');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing in with Kakao: $e');
      }
      rethrow;
    }
  }

  // 전화번호 인증 시작
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
    Function(firebase_auth.PhoneAuthCredential)? onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // 자동 검색 시간 초과
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // 전화번호 인증 완료
  static Future<User?> signInWithPhoneNumber(String verificationId, String smsCode, String name) async {
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // 기존 사용자인지 확인
        User? existingUser = await UserService.getUser(userCredential.user!.uid);
        
        if (existingUser == null) {
          // 새 사용자 생성
          final user = User(
            id: userCredential.user!.uid,
            name: name,
            phoneNumber: userCredential.user!.phoneNumber,
          );

          await UserService.createUser(user);
          existingUser = user;
        }

        if (kDebugMode) {
          print('✅ User signed in with phone: ${userCredential.user!.uid}');
        }

        return existingUser;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing in with phone: $e');
      }
      rethrow;
    }
  }

  // 로그아웃
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      
      if (kDebugMode) {
        print('✅ User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error signing out: $e');
      }
      rethrow;
    }
  }

  // 비밀번호 재설정
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      
      if (kDebugMode) {
        print('✅ Password reset email sent to: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending password reset: $e');
      }
      rethrow;
    }
  }

  // 계정 삭제 (회원탈퇴)
  static Future<void> deleteAccount({String? reason}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (kDebugMode) {
          print('🗑️ 회원탈퇴 시작: ${user.uid}');
          if (reason != null) print('   탈퇴 사유: $reason');
        }
        
        // 1. Firestore에서 사용자 관련 데이터 삭제 (새로운 메서드 사용)
        await UserService.deleteUserAccount(user.uid, reason: reason);
        if (kDebugMode) {
          print('✅ Firestore 사용자 데이터 삭제 완료');
        }
        
        // 2. Firebase Auth 계정 삭제
        await user.delete();
        if (kDebugMode) {
          print('✅ Firebase Auth 계정 삭제 완료');
        }
        
        if (kDebugMode) {
          print('🎉 회원탈퇴 완료');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 삭제할 사용자가 없음');
        }
        throw Exception('로그인된 사용자가 없습니다');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 회원탈퇴 실패: $e');
      }
      rethrow;
    }
  }
}