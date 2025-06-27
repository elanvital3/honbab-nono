# Firebase 설정 가이드

## 1. Firebase 프로젝트 생성

1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름: `honbab-nono`
4. Google Analytics 설정 (선택사항)

## 2. Firestore 데이터베이스 설정

1. Firebase Console → "Firestore Database" → "데이터베이스 만들기"
2. 보안 규칙: **테스트 모드**로 시작 (개발용)
3. 위치: `asia-northeast3 (Seoul)`

## 3. Authentication 설정

1. Firebase Console → "Authentication" → "시작하기"
2. "Sign-in method" 탭에서 다음 활성화:
   - 이메일/비밀번호
   - 휴대전화 (SMS 인증)
   - Google (선택사항)

## 4. FlutterFire CLI 설정

### 4.1 CLI 설치
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

### 4.2 Firebase 로그인
```bash
firebase login
```

### 4.3 Flutter 프로젝트에 Firebase 연결
```bash
cd flutter-app
flutterfire configure
```

이 명령어 실행 시:
- 프로젝트 선택: `honbab-nono`
- 플랫폼 선택: `android`, `ios`, `web` (모두 선택)
- 자동으로 `firebase_options.dart` 파일 생성됨

## 5. 파일 업데이트

### 5.1 firebase_config.dart 교체
`lib/config/firebase_config.dart` 파일을 다음으로 교체:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      if (kDebugMode) {
        print('🔥 Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase initialization error: $e');
      }
      rethrow;
    }
  }
}
```

### 5.2 Android 설정 확인
`android/app/build.gradle`에 다음 추가되어 있는지 확인:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-analytics'
}
```

### 5.3 iOS 설정 확인
`ios/Runner/Info.plist`에 Firebase 설정이 추가되어 있는지 확인

## 6. Firestore 보안 규칙 설정 (개발용)

Firebase Console → Firestore → "규칙" 탭:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 개발용 - 모든 읽기/쓰기 허용
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

**⚠️ 주의**: 실제 배포 시에는 보안 규칙을 반드시 수정해야 합니다.

## 7. 테스트 실행

```bash
cd flutter-app
flutter run
```

Firebase 연결이 성공하면 콘솔에 "🔥 Firebase initialized successfully" 메시지가 출력됩니다.

## 8. 샘플 데이터 추가 (선택사항)

앱 실행 후 개발자용 샘플 데이터를 추가하려면:

```dart
// main.dart에 임시로 추가
import 'utils/sample_data_seeder.dart';

// main() 함수에서 Firebase 초기화 후:
if (kDebugMode) {
  await SampleDataSeeder.seedSampleData();
}
```

## 9. 문제 해결

### 자주 발생하는 오류:

1. **"No Firebase App"**: `firebase_options.dart` 파일이 없거나 import가 잘못됨
2. **CORS 오류**: 웹에서만 발생, 모바일에서는 정상 작동
3. **권한 오류**: Firestore 보안 규칙 확인

### 도움말:
- [FlutterFire 공식 문서](https://firebase.flutter.dev/)
- [Firebase 콘솔](https://console.firebase.google.com/)