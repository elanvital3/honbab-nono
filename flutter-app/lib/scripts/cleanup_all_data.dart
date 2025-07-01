import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../firebase_options.dart';

/// 모든 테스트 데이터 삭제 스크립트 (단순화된 FCM 시스템 적용)
/// 주의: 이 스크립트는 모든 데이터를 삭제합니다!
void main() async {
  print('🧹 혼밥노노 전체 데이터 초기화 시작 (단순화된 FCM 시스템)...\n');
  
  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final functions = FirebaseFunctions.instance;
  
  print('⚠️  경고: 이 작업은 모든 데이터를 삭제합니다!');
  print('계속하려면 10초 기다리세요...\n');
  
  await Future.delayed(const Duration(seconds: 10));
  
  try {
    // 1. Firestore 컬렉션 삭제 (단순화된 FCM 시스템 반영)
    print('📦 Firestore 데이터 삭제 중...');
    
    // users 컬렉션 (FCM 토큰 포함)
    await _deleteCollection(firestore, 'users');
    
    // meetings 컬렉션
    await _deleteCollection(firestore, 'meetings');
    
    // messages 컬렉션
    await _deleteCollection(firestore, 'messages');
    
    // 더 이상 사용하지 않는 fcm_tokens 컬렉션도 정리
    await _deleteCollection(firestore, 'fcm_tokens');
    
    // restaurants 컬렉션 (필요한 경우)
    await _deleteCollection(firestore, 'restaurants');
    
    // privacy_consents 컬렉션
    await _deleteCollection(firestore, 'privacy_consents');
    
    // user_ratings 컬렉션
    await _deleteCollection(firestore, 'user_ratings');
    
    // notifications 컬렉션
    await _deleteCollection(firestore, 'notifications');
    
    print('✅ Firestore 데이터 삭제 완료\n');
    
    // 2. Firebase Auth 사용자 삭제 (Functions 사용)
    print('👤 Firebase Auth 사용자 삭제 중...');
    await _deleteAllAuthUsersViaFunctions(functions);
    print('✅ Firebase Auth 사용자 삭제 완료\n');
    
    // 3. 현재 사용자 로그아웃
    if (auth.currentUser != null) {
      print('🔓 현재 사용자 로그아웃 중...');
      await auth.signOut();
      print('✅ 로그아웃 완료\n');
    }
    
    print('🎉 데이터 초기화 완료!');
    print('이제 단순화된 FCM 시스템으로 새로 테스트할 수 있습니다.');
    print('- FCM 토큰은 users 문서의 fcmToken 필드에만 저장됩니다.');
    print('- 로그인/회원가입 시 자동으로 FCM 토큰이 저장됩니다.');
    
  } catch (e) {
    print('❌ 오류 발생: $e');
  }
}

/// 컬렉션 삭제 함수
Future<void> _deleteCollection(FirebaseFirestore firestore, String collectionName) async {
  try {
    final collection = firestore.collection(collectionName);
    final snapshot = await collection.get();
    
    if (snapshot.docs.isEmpty) {
      print('  - $collectionName: 비어있음');
      return;
    }
    
    print('  - $collectionName: ${snapshot.docs.length}개 문서 삭제 중...');
    
    // 배치로 삭제
    WriteBatch batch = firestore.batch();
    int count = 0;
    
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;
      
      // 500개씩 배치 처리
      if (count % 500 == 0) {
        await batch.commit();
        batch = firestore.batch();
      }
    }
    
    // 남은 것들 처리
    if (count % 500 != 0) {
      await batch.commit();
    }
    
    print('    ✓ $count개 문서 삭제 완료');
  } catch (e) {
    print('    ❌ $collectionName 삭제 실패: $e');
  }
}

/// Firebase Auth 사용자 전체 삭제 함수 (Functions 사용)
Future<void> _deleteAllAuthUsersViaFunctions(FirebaseFunctions functions) async {
  try {
    print('  - Firebase Functions를 통한 Auth 사용자 삭제 시작...');
    
    final callable = functions.httpsCallable('deleteAllAuthUsers');
    final result = await callable.call();
    
    if (result.data['success'] == true) {
      final deletedCount = result.data['deletedCount'] ?? 0;
      print('  - ✅ ${deletedCount}명의 사용자가 성공적으로 삭제되었습니다.');
    } else {
      print('  - ❌ 사용자 삭제 실패: ${result.data['message'] ?? '알 수 없는 오류'}');
    }
    
  } catch (e) {
    print('  - ❌ Firebase Functions를 통한 Auth 사용자 삭제 실패: $e');
    print('  - 대안: Firebase Console에서 수동 삭제');
    print('    1. Firebase Console > Authentication > Users');
    print('    2. 모든 사용자 선택 후 삭제');
  }
}

/// 현재 Firebase Auth 사용자 상태 확인
Future<void> _checkAuthUserStatus(FirebaseAuth auth) async {
  try {
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      print('📋 현재 로그인된 사용자:');
      print('  - UID: ${currentUser.uid}');
      print('  - 이메일: ${currentUser.email ?? '없음'}');
      print('  - 익명 로그인: ${currentUser.isAnonymous}');
      print('  - 로그인 시간: ${currentUser.metadata.lastSignInTime}');
    } else {
      print('📋 현재 로그인된 사용자 없음');
    }
  } catch (e) {
    print('❌ 사용자 상태 확인 실패: $e');
  }
}