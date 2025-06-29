# 🍽️ 혼밥노노 개발 스토리 - "혼여는 좋지만 맛집은 함께 🥹"

## 📋 프로젝트 탄생 배경

### 💡 아이디어의 시작
"혼자 여행은 좋지만, 맛집만큼은 함께 가고 싶어..."

1인 가구가 33%를 돌파하고 혼자 여행하는 문화가 확산되면서, **혼여족들의 공통된 고민**이 하나 있었습니다. 바로 **맛집을 혼자 가기 어렵다는 것**이었죠. 특히 여행지에서는 현지 맛집을 경험하고 싶지만, 혼자 가기엔 부담스럽고 그렇다고 포기하기엔 아쉬운 상황들이 많았습니다.

기존 서비스들의 한계:
- **당근마켓 "같이해요"**: 동네 기반이라 여행자 제외, 너무 계획적
- **데이팅 앱들**: 목적이 모호하고 부담스러움
- **여행 동행 앱**: 전체 여행 동행 중심, 한 끼 식사만을 위한 건 없음

### 🎯 핵심 가치 정의
**"부담 없는 한 끼 식사로 새로운 인연 만들기"**

- 명확한 목적성: 맛집 동행에만 집중
- 낮은 부담감: 한 끼 식사 약속으로 가벼운 만남
- 안전한 매칭: 소셜 로그인 + 평가 시스템으로 신뢰성 확보

---

## 🛠️ 기술 스택 선택 과정

### Flutter vs React Native 고민
**초기 고민**: "크로스 플랫폼 개발로 빠르게 MVP를 만들자"

**Flutter 선택 이유**:
- 성능이 더 안정적 (특히 지도 연동에서)
- 구글 생태계와의 호환성 (Firebase, Play Store)
- 한번 작성으로 Android/iOS 동시 지원
- Material Design 3 기본 지원으로 빠른 UI 구축

### Backend: Firebase vs Node.js
**Firebase 선택 이유**:
- 빠른 MVP 개발 (서버 구축 시간 단축)
- Authentication 기본 제공 (소셜 로그인 쉬움)
- Realtime Database로 채팅 구현 용이
- 무료 티어로 초기 비용 절약

### 지도 API: 구글맵 vs 카카오맵
**카카오맵 선택 이유**:
- 한국 지역 데이터 정확도
- 식당 검색 API 품질
- 무료 사용량 충분
- 카카오 로그인과 생태계 통합

---

## 🚀 개발 여정 타임라인

### Phase 0: 프로젝트 초기화 (12월 초)
```bash
# Claude Code로 프로젝트 시작
mkdir honbab-nono && cd honbab-nono
claude init
flutter create flutter-app
```

**첫 번째 도전**: Claude Code를 활용한 체계적 개발
- Git 기반 협업 워크플로우 확립
- CLAUDE.md로 프로젝트 상태 관리
- TodoWrite로 작업 단위 추적

### Phase 1: Flutter 기반 구조 구축 (12월 1주)
**목표**: MVP 화면 구조 완성

**주요 성과**:
- 4탭 네비게이션 구조 (홈/지도/채팅/마이페이지)
- 당근마켓 스타일 + 베이지 포인트 컬러 시스템
- MeetingCard 컴포넌트로 모임 리스트 구현
- Noto Sans KR 폰트 시스템 적용

**기술적 결정**:
- Material Design 3 기반 테마 시스템
- Provider 패턴으로 상태 관리
- 컴포넌트 기반 설계 (재사용성 확보)

### Phase 2: 카카오맵 연동의 험난한 여정 (12월 2주)
**가장 큰 도전과제**: 카카오맵 Flutter 연동

**시행착오 과정**:
1. **첫 번째 시도**: 공식 `kakao_maps_flutter` 패키지
   - 문제: 문서 부족, 커스터마이징 한계
   - 결과: 기본 지도만 표시, 검색 기능 연동 어려움

2. **두 번째 시도**: JavaScript API + WebView 하이브리드
   - 선택 이유: 카카오맵 JavaScript API의 완성도
   - 구현: Flutter ↔ JavaScript 양방향 통신
   - 결과: **대성공!** 완전한 지도 기능 구현

**WebView 방식의 장점**:
- 카카오맵 JavaScript API 모든 기능 활용
- 마커, 정보창, 검색 모두 자유자재로 구현
- 실시간 상태 동기화 (검색 결과, 필터 등)

**핵심 구현 포인트**:
```dart
// JavaScript ↔ Flutter 통신
webViewController.addJavaScriptChannel(
  'FlutterChannel',
  onMessageReceived: (message) {
    final data = jsonDecode(message.message);
    // 지도 상태 업데이트 처리
  },
);
```

### Phase 3: Firebase 인증 시스템 구축 (12월 2-3주)
**목표**: 카카오 로그인 + Firebase Auth 완전 연동

**구현 과정**:
1. **Firebase 프로젝트 설정**
   - Authentication 활성화
   - Firestore 데이터베이스 생성
   - 한국어 지역화 설정

2. **카카오 로그인 연동**
   - 카카오 디벨로퍼 콘솔 앱 등록
   - **키 해시 문제 해결**: 디버그/릴리즈 키 모두 등록
   - `kakao_flutter_sdk` 통합

3. **사용자 데이터 모델 설계**
```dart
class User {
  final String uid;
  final String nickname;
  final String? profileImageUrl;
  final String kakaoId;
  final DateTime createdAt;
  // 평가 시스템을 위한 필드들
}
```

**가장 까다로웠던 부분**: 키 해시 문제
```bash
# 디버그 키 해시 추출
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64

# 릴리즈 키 해시 추출
keytool -exportcert -alias upload -keystore release-key.keystore | openssl sha1 -binary | openssl base64
```

### Phase 4: 식당 검색 시스템 (12월 3주)
**도전**: 실시간 식당 검색 + 모임 생성 연동

**카카오 검색 API 활용**:
- 키워드 검색으로 전국 식당 데이터 접근
- 사용자 현재 위치 기준 거리순 정렬
- 검색 결과를 지도에 마커로 표시

**RestaurantSearchModal 컴포넌트**:
- 실시간 검색 (타이핑할 때마다 API 호출)
- 엔터키 검색 지원
- 검색 결과 리스트 + 지도 연동

### Phase 5: UI 일관성 시스템 구축 (12월 4주)
**배경**: 개발이 진행되면서 UI 일관성 문제 발생

**해결 방안**: 디자인 토큰 시스템 도입
```dart
// AppDesignTokens 클래스로 모든 디자인 값 통일
class AppDesignTokens {
  static const double spacing2 = 8.0;  // 1x 기본 단위
  static const double spacing3 = 16.0; // 2x
  static const Color primaryBeige = Color(0xFFD2B48C);
  static const double borderRadius2 = 12.0;
}

// AppTextStyles로 모든 텍스트 스타일 통일
class AppTextStyles {
  static const TextStyle headlineLarge = TextStyle(
    fontSize: AppDesignTokens.fontSizeH2,
    fontWeight: AppDesignTokens.fontWeightBold,
    fontFamily: 'NotoSansKR',
  );
}
```

**적용 결과**:
- 모든 화면에서 일관된 간격과 스타일
- 공통 컴포넌트 (CommonCard, CommonButton) 재사용
- 유지보수성 크게 향상

### Phase 6: Google Play Store 배포 (12월 4주 말)
**목표**: 정식 앱 스토어 출시

**준비 과정**:
1. **앱 아이콘 제작 및 적용**
   - 다양한 해상도 아이콘 생성
   - `flutter_launcher_icons` 패키지로 자동화
   - Android 12+ 적응형 아이콘 지원

2. **스플래시 화면 최적화**
   - 네이티브 스플래시로 통일 (이중 스플래시 문제 해결)
   - 앱 아이콘이 중앙에 표시되는 깔끔한 디자인

3. **릴리즈 빌드 설정**
   - 키스토어 생성 및 앱 서명
   - Proguard 최적화 설정
   - AAB (Android App Bundle) 빌드

4. **Google Play Console 등록**
   - 스토어 등록 정보 작성
   - 스크린샷 및 설명 준비
   - 내부 테스트 → 정식 출시

**최종 성과**: 🎉 **"혼밥노노 v1.0" Google Play Store 정식 출시!**

### Phase 7: 프로젝트 정리 및 최적화 (12월 5주)
**목표**: 깔끔한 프로젝트 구조 완성

**정리 작업**:
- 사용하지 않는 폴더/파일 제거 (React Native, Node.js 백엔드 등)
- 아이콘 관리 시스템 통일 (`assets/images/` 단일 소스)
- 백업 브랜치 생성으로 안전한 정리
- 문서 업데이트 (CLAUDE.md 구조 반영)

---

## 🎯 주요 성취와 배운 점

### ✅ 기술적 성취
1. **Flutter + Firebase 완전 연동**: 서버리스 백엔드로 빠른 개발
2. **카카오 API 생태계 통합**: 지도 + 검색 + 로그인 원스톱
3. **WebView 하이브리드 접근**: 네이티브 한계 극복
4. **디자인 시스템 구축**: 확장 가능한 UI 아키텍처
5. **Google Play Store 배포**: 실제 서비스 런칭 경험

### 🎨 UX/UI 혁신
- **당근마켓 스타일 + 베이지 포인트**: 친숙하면서도 차별화된 디자인
- **지도 ↔ 리스트 동기화**: 필터와 검색 결과 실시간 반영
- **30초 회원가입**: 닉네임만 입력하는 간편한 온보딩

### 🔧 개발 프로세스 혁신
- **Claude Code 활용**: AI와 협업하는 새로운 개발 경험
- **TodoWrite 기반 작업 관리**: 체계적인 작업 추적
- **Git 브랜치 전략**: 안전한 백업과 버전 관리

### 💡 가장 중요한 깨달음
**"완벽한 기술보다는 사용자 문제 해결이 핵심"**

처음엔 최신 기술 스택에 집착했지만, 실제로는 사용자가 원하는 기능을 빠르고 안정적으로 제공하는 것이 더 중요했습니다. WebView를 활용한 카카오맵 연동이 대표적인 예시입니다.

---

## 🚧 아쉬웠던 점과 개선 과제

### 😅 시행착오들
1. **카카오맵 연동 초기 접근**: 공식 패키지만 고집하다 시간 소요
2. **UI 일관성**: 초기에 체계적 설계 없이 시작해서 나중에 대규모 수정
3. **키 해시 문제**: 문서를 꼼꼼히 읽지 않아 반복적인 에러 발생

### 🔮 Phase 2 계획
1. **실시간 채팅**: Socket.io 또는 Firebase Realtime Database
2. **푸시 알림**: 모임 알림, 채팅 메시지 알림
3. **평가 시스템**: 모임 완료 후 상호 평가
4. **고급 필터링**: 연령대, 성별, 관심사 기반 매칭

---

## 🏆 프로젝트 성과 요약

### 📊 정량적 성과
- **개발 기간**: 약 4주
- **총 커밋 수**: 17개 주요 마일스톤
- **파일 구조**: 깔끔하게 정리된 Flutter 단일 프로젝트
- **배포 상태**: Google Play Store 정식 출시 완료

### 🎯 정성적 성과
- **완전한 MVP**: Phase 1의 모든 핵심 기능 100% 구현
- **확장 가능한 아키텍처**: Phase 2 개발을 위한 견고한 기반
- **실제 사용 가능한 앱**: 다운로드하여 바로 사용할 수 있는 완성도

### 🙏 개인적 성장
- **Flutter 생태계 이해**: 패키지 생태계와 네이티브 연동
- **Firebase 서버리스 개발**: NoSQL 데이터베이스 설계와 보안 규칙
- **앱 스토어 배포**: 실제 서비스 출시 프로세스 경험
- **AI 협업**: Claude Code와 함께하는 새로운 개발 경험

---

## 💭 마무리 소감

**"혼여는 좋지만 맛집은 함께 🥹"**

작은 아이디어에서 시작된 혼밥노노가 실제 구글 플레이 스토어에 올라간 완성된 앱이 되기까지의 여정은 정말 값진 경험이었습니다. 

특히 Claude Code와 함께 개발하면서, AI가 단순한 코딩 도구를 넘어 진정한 개발 파트너가 될 수 있다는 것을 경험했습니다. 체계적인 작업 관리, 실시간 피드백, 그리고 끊임없는 품질 개선 - 혼자서는 불가능했을 완성도를 달성할 수 있었습니다.

앞으로 실제 사용자들이 이 앱을 통해 새로운 인연을 만들고, 맛있는 식사를 함께 즐기는 모습을 상상하니 벌써부터 설렙니다. 

**Phase 2에서는 더욱 풍부한 기능으로 사용자들을 만날 예정입니다!** 🚀