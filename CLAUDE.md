# 혼밥노노 (HonbabNoNo) - 맛집 동행 매칭 앱

## 📋 프로젝트 개요
혼자 먹기 싫은 사람들이 **"같이 먹고 싶어~"** 니즈를 해결할 수 있는 안전하고 편리한 맛집 동행 매칭 서비스

## 🛠️ 기술 스택
- **Mobile**: Flutter + Dart
- **Backend**: Firebase (Auth + Firestore + Storage)
- **Map**: 카카오맵 API + 카카오 검색 API
- **Chat**: 실시간 채팅 
- **Auth**: 카카오 소셜 로그인 + Firebase Auth
- **Additional APIs**: Google Places API, YouTube Data API v3, 네이버 블로그 API

## 🏗️ 프로젝트 구조 (최신 2025-01-15)
```
honbab-nono/
├── flutter-app/        # Flutter 메인 앱 📱
│   ├── lib/
│   │   ├── components/ # 재사용 컴포넌트
│   │   │   ├── common/ # 공통 컴포넌트 (CommonCard, CommonButton)
│   │   │   ├── meeting_card.dart
│   │   │   ├── restaurant_search_modal.dart
│   │   │   └── kakao_webview_map.dart
│   │   ├── screens/    # 화면 컴포넌트 (⭐ 하단 매핑 가이드 참조)
│   │   │   ├── auth/   # 로그인/회원가입/인증
│   │   │   ├── home/   # 홈 화면 (4탭 네비게이션)
│   │   │   ├── meeting/# 모임 생성/리스트/상세
│   │   │   ├── chat/   # 채팅
│   │   │   ├── profile/# 프로필 관리
│   │   │   ├── settings/# 설정 화면
│   │   │   ├── restaurant/# 맛집 관련
│   │   │   └── evaluation/# 사용자 평가
│   │   ├── services/   # API 서비스 (Firebase + 외부 API)
│   │   ├── models/     # 데이터 모델
│   │   ├── styles/     # 텍스트 스타일 (AppTextStyles)
│   │   ├── constants/  # 디자인 토큰 (AppDesignTokens)
│   │   ├── config/     # Firebase 설정
│   │   └── utils/      # 유틸리티
│   ├── assets/images/  # 앱 아이콘 및 이미지
│   ├── android/        # 안드로이드 설정
│   ├── ios/           # iOS 설정
│   └── pubspec.yaml   # Flutter 의존성
├── functions/          # Firebase Functions 🔥
├── docs/              # 📚 프로젝트 문서
│   ├── PRD.md                    # 제품 요구사항 명세서
│   ├── DEVELOPMENT_STORY.md      # 개발 과정 전체 스토리
│   ├── FLUTTER_FIREBASE_GUIDE.md # 실무 개발 가이드
│   └── MARKETING_STRATEGY.md     # 마케팅 전략 가이드
├── config/            # 설정 파일
├── ui-reference/      # UI 참조 이미지
├── firebase.json      # Firebase 설정
├── firestore.rules   # Firestore 보안 규칙
└── CLAUDE.md         # 프로젝트 가이드 (이 파일)
```

## 📱 화면별 파일 매핑 가이드 (2025-01-15)

### 🎯 주요 화면 매핑 (실제 사용되는 파일들)

#### 홈 화면 시스템
- **홈 화면 (4탭)**: `/screens/home/home_screen.dart` 
  - **홈 탭**: `_HomeTab` class (같은 파일 내)
  - **지도 탭**: `_MapTab` class (같은 파일 내) 
  - **채팅 탭**: `_ChatListTab` class (같은 파일 내)
  - **내 프로필 탭**: `_ProfileTab` class (같은 파일 내) ⭐ **실제 마이페이지**

#### 인증 시스템
- **로그인 화면**: `/screens/auth/login_screen.dart`
- **닉네임 입력**: `/screens/auth/nickname_input_screen.dart`
- **개인정보 동의**: `/screens/auth/privacy_consent_screen.dart`
- **성인 인증**: `/screens/auth/adult_verification_screen.dart`
- **기존 사용자 성인 인증**: `/screens/auth/existing_user_adult_verification_screen.dart`
- **웹뷰 인증**: `/screens/auth/webview_certification_screen.dart`
- **회원가입 완료**: `/screens/auth/signup_complete_screen.dart`
- **인증 래퍼**: `/screens/auth/auth_wrapper.dart` (라우팅 관리)

#### 모임 관련 화면
- **모임 생성**: `/screens/meeting/create_meeting_screen.dart`
- **모임 상세**: `/screens/meeting/meeting_detail_screen.dart`
- **모임 수정**: `/screens/meeting/edit_meeting_screen.dart`
- **참여자 관리**: `/screens/meeting/participant_management_screen.dart`
- **신청자 관리**: `/screens/meeting/applicant_management_screen.dart`

#### 채팅 시스템
- **채팅방**: `/screens/chat/chat_room_screen.dart`
- **채팅 목록**: `/screens/chat/chat_screen.dart` (별도 화면, 현재 미사용)

#### 프로필 시스템
- **다른 사용자 프로필**: `/screens/profile/user_profile_screen.dart`
- **프로필 편집**: `/screens/profile/profile_edit_screen.dart`
- **뱃지 선택**: `/screens/profile/badge_selection_screen.dart`
- **모임 히스토리**: `/screens/profile/my_meetings_history_screen.dart`

#### 설정 화면
- **알림 설정**: `/screens/settings/notification_settings_screen.dart`
- **계정 삭제**: `/screens/settings/account_deletion_screen.dart`

#### 맛집 시스템
- **맛집 상세**: `/screens/restaurant/restaurant_detail_screen.dart`
- **맛집 리스트**: `/screens/restaurant/restaurant_list_screen.dart`

#### 평가 시스템
- **사용자 평가**: `/screens/evaluation/user_evaluation_screen.dart`

### 🚨 중요한 구분사항

#### ❌ 삭제된 파일 (더 이상 사용하지 않음)
- ~~`/screens/profile/my_profile_detail_screen.dart`~~ → **삭제됨** (2025-01-15)
  - **이유**: `home_screen.dart`의 `_ProfileTab`이 실제 마이페이지였음
  - **실수 방지**: 마이페이지 수정 시 `home_screen.dart`의 `_ProfileTab` 수정해야 함

#### ⚠️ 혼동하기 쉬운 파일들
- **마이페이지**: `home_screen.dart`의 `_ProfileTab` ⭐ (실제 사용)
- **다른 사용자 프로필**: `user_profile_screen.dart` (별도 화면)
- **채팅 리스트**: `home_screen.dart`의 `_ChatListTab` ⭐ (실제 사용)
- **채팅 화면**: `chat_screen.dart` (별도 화면, 현재 미사용)

### 📋 개발 시 체크리스트

#### UI 수정 전 확인사항
1. **화면이 어떤 파일인지 확실히 확인**
   - 홈 화면 탭들은 모두 `home_screen.dart` 안에 있음
   - 독립적인 화면들은 별도 파일
2. **실제 사용되는 파일인지 확인**
   - 삭제된 파일이나 미사용 파일 수정 금지
   - 의심스러면 먼저 확인 후 작업
3. **변경사항 테스트**
   - UI 변경 후 실제 앱에서 반영되는지 확인
   - Hot reload로 즉시 확인 가능

## 🗄️ Firestore 데이터베이스 구조

### 📊 핵심 컬렉션

#### `users` - 사용자 정보
```javascript
{
  id: string,                    // Firebase Auth UID
  name: string,                  // 닉네임
  email: string?,                // 이메일 (선택)
  phoneNumber: string?,          // 전화번호 (선택)
  profileImageUrl: string?,      // 프로필 이미지 URL
  kakaoId: string?,              // 카카오 ID (로그인용)
  gender: string?,               // 성별 (선택)
  birthYear: number?,            // 출생연도 (선택)
  badges: string[],              // 사용자 특성 뱃지
  favoriteRestaurants: string[], // 즐겨찾기 식당 ID 목록
  rating: number,                // 평균 평점 (기본값: 0.0)
  meetingsHosted: number,        // 주최한 모임 수
  meetingsJoined: number,        // 참여한 모임 수
  lastLatitude: number?,         // 마지막 위치 (위도)
  lastLongitude: number?,        // 마지막 위치 (경도)
  lastLocationUpdated: Timestamp?, // 위치 업데이트 시간
  currentChatRoom: string?,      // 현재 채팅방 ID
  fcmToken: string?,             // FCM 푸시 토큰
  createdAt: Timestamp,          // 가입일
  updatedAt: Timestamp           // 수정일
}
```

#### `meetings` - 모임 정보
```javascript
{
  id: string,                    // 모임 고유 ID
  title: string,                 // 모임 제목
  description: string,           // 모임 설명
  hostId: string,                // 호스트 사용자 ID
  hostName: string,              // 호스트 닉네임
  dateTime: Timestamp,           // 모임 일시
  location: string,              // 모임 장소 (주소)
  restaurantName: string?,       // 식당명
  restaurantId: string?,         // 카카오 장소 ID
  latitude: number,              // 위치 (위도)
  longitude: number,             // 위치 (경도)
  maxParticipants: number,       // 최대 참여인원
  participantIds: string[],      // 참여자 ID 목록
  tags: string[],                // 태그 목록
  imageUrl: string?,             // 대표 이미지 URL
  status: string,                // 모임 상태 (active, completed, cancelled)
  chatRoomId: string?,           // 채팅방 ID
  createdAt: Timestamp,          // 생성일
  updatedAt: Timestamp           // 수정일
}
```

#### `restaurants` - 맛집 정보 (확장)
```javascript
{
  // 기본 정보 (카카오 API)
  id: string,
  name: string,
  address: string,
  latitude: number,
  longitude: number,
  category: string,
  phone: string?,
  url: string?,
  city: string,
  province: string,
  
  // YouTube 데이터
  youtubeStats: {
    mentionCount: number,
    channels: string[],
    recentMentions: number,
    representativeVideo: {...}
  },
  
  // Google Places 데이터
  googlePlaces: {
    placeId: string,
    rating: number,
    userRatingsTotal: number,
    reviews: GoogleReview[],
    photos: string[],
    regularOpeningHours: {...}
  },
  
  // 네이버 블로그 데이터
  naverBlog: {
    totalCount: number,
    posts: NaverBlogPost[],
    updatedAt: DateTime
  },
  
  // 메타 정보
  isActive: boolean,
  updatedAt: Timestamp
}
```

#### 기타 컬렉션
- **`user_evaluations`**: 사용자 평가 (평점 시스템)
- **`chat_rooms`**: 채팅방 정보
- **`messages`**: 채팅 메시지
- **`user_blacklist`**: 악용 방지 블랙리스트 (해시 기반)

### 🛡️ 보안 및 악용방지 시스템

#### 회원탈퇴 시 데이터 처리 전략
1. **Phase 1**: 기본 사용자 데이터 삭제
2. **Phase 2**: 평가 데이터 정리
3. **Phase 3**: 모임 데이터 처리 (익명화)
4. **Phase 4**: 채팅 메시지 익명화
5. **Phase 5**: 블랙리스트 등록 (재가입 제한)

#### 🚨 평점 조작 및 가짜 모임 방지 시스템 (2025-01-15 추가)

**중요도**: ⭐⭐⭐⭐⭐ (최우선 장기 과제)

##### 📊 현재 시스템의 취약점
1. **가짜 모임 생성**: 실제 만나지 않고 평가만 주고받기
2. **다중 계정 악용**: 여러 계정으로 자신에게 좋은 평가 주기
3. **평가 거래**: 서로 좋은 평가 주고받기 약속
4. **악의적 평가**: 개인적 감정으로 나쁜 평가 주기
5. **위치 조작**: GPS 스푸핑으로 가짜 위치 정보 제공

##### 🔒 단계별 방어 시스템 구축 계획

###### Phase 1: 기본 검증 시스템 (3개월 내)
- **모임 완료 조건 강화**
  - 호스트만 "모임 완료" 처리 가능
  - 모임 시간에 실제 위치 확인 (GPS 체크인)
  - 최소 모임 지속 시간 (30분) 확인
  - 모임 장소 반경 500m 내에서만 완료 처리

- **평가 시스템 제한**
  - 모임 완료 후 24시간 내에만 평가 가능
  - 평가 후 수정 불가 (또는 1회만 수정 허용)
  - 상호 평가 필수 (한 쪽만 평가 방지)
  - 참여자 2명 이상이어야 평가 시스템 활성화

###### Phase 2: 행동 패턴 분석 시스템 (6개월 내)
- **의심스러운 패턴 탐지**
  - 같은 사용자들끼리 반복적으로 모임 참여 (>3회)
  - 비정상적으로 높은 평점 패턴 (평균 4.8+ 지속)
  - 평가 시간이 모임 완료와 동시에 일어나는 경우
  - 일정 기간 내 급격한 평점 상승

- **지리적 검증 강화**
  - 모임 장소에서 일정 거리 내에서만 평가 가능
  - GPS 스푸핑 탐지 시스템 도입
  - 이동 패턴 분석 (비정상적으로 빠른 이동 탐지)
  - 연속 모임 간 시간/거리 검증

- **소셜 그래프 분석**
  - 서로만 평가하는 폐쇄적 그룹 탐지
  - 평가 네트워크의 다양성 분석
  - 신규 계정과 기존 계정의 연관성 분석

###### Phase 3: AI 기반 고급 탐지 시스템 (1년 내)
- **머신러닝 이상 탐지**
  - 평가 패턴의 이상값 탐지
  - 텍스트 리뷰의 진위성 분석 (자연어 처리)
  - 사용자 행동 패턴 학습 및 예측

- **이미지 분석 시스템**
  - 모임 중 사진 업로드 권장/필수화
  - 같은 장소, 다른 시간의 사진 재사용 탐지
  - 얼굴 인식으로 실제 참여자 확인 (개인정보 동의 필요)

##### 🚨 즉시 적용 가능한 기본 방어책

```javascript
// 모임 완료 프로세스 강화
meetingCompletion: {
  hostOnlyCompletion: true,        // 호스트만 완료 처리
  minimumDuration: 30,             // 최소 30분 경과
  locationRadius: 500,             // 500m 반경 내
  minimumParticipants: 2,          // 최소 2명 참여
  evaluationTimeLimit: 24,         // 24시간 내 평가
  evaluationEditLimit: 0,          // 평가 수정 불가
  mutualEvaluationRequired: true   // 상호 평가 필수
}

// 사용자 신뢰도 시스템
userTrustScore: {
  meetingCount: number,            // 참여한 모임 수
  evaluationConsistency: number,   // 받은 평가의 일관성
  accountAge: number,              // 계정 생성 기간 (일)
  verificationLevel: string,       // phone/email 인증 여부
  profileCompleteness: number,     // 프로필 완성도 (%)
  reportCount: number              // 신고당한 횟수
}

// 의심 패턴 탐지 알고리즘
suspiciousPatternDetection: {
  repeatedMeetings: 3,             // 같은 멤버 3회 이상
  ratingSpike: 0.5,                // 급격한 평점 상승
  evaluationTiming: 300,           // 완료 후 5분 내 평가
  locationJumping: 1000,           // 1km 이상 급격한 이동
  newAccountWarning: 7             // 신규 계정 7일 주의
}
```

##### 📈 모니터링 지표 및 대응 방안

**핵심 지표**:
1. **평점 분포**: 정상 분포 vs 편향된 분포
2. **평가 시간**: 모임 완료와 평가 시간의 간격
3. **재방문율**: 같은 사용자들의 반복 만남 빈도
4. **지리적 패턴**: 평가 위치와 모임 위치의 일치성
5. **신고율**: 사용자 신고 대비 실제 조치 비율

**자동 대응 시스템**:
- **경고 단계**: 의심 패턴 1-2개 탐지 시 사용자에게 경고
- **제한 단계**: 의심 패턴 3개 이상 시 평가 권한 일시 정지
- **조사 단계**: 관리자 수동 검토 및 계정 조사
- **차단 단계**: 확실한 악용 확인 시 계정 영구 정지

##### 🔮 장기 비전 (2-3년 후)
- **블록체인 기반 평가 무결성**: 평가 데이터의 변조 불가능한 저장
- **커뮤니티 자율 관리**: 사용자들이 직접 신고/검증하는 시스템
- **AI 챗봇 모니터링**: 실시간 대화 분석으로 가짜 모임 탐지
- **바이오메트릭 인증**: 지문/얼굴 인식으로 본인 확인 강화

**⚠️ 중요 원칙**: 사용자 경험을 해치지 않으면서도 보안을 강화하는 균형점 찾기

#### 🎯 구현 완료: 혁신적인 1대1 평가 시스템 (2025-01-15)

**핵심 아이디어**: 한 카카오 계정으로부터 받을 수 있는 평가는 평생 1번만 허용 (수정 가능)

##### ✅ 완료된 구현 사항
1. **EvaluationService 업데이트**:
   - `submitEvaluation()`: 기존 평가 있으면 업데이트, 없으면 신규 생성
   - `getExistingEvaluation()`: 기존 평가 조회 메소드
   - `getPendingEvaluations()`: 신규/수정 모드 정보 포함하여 반환

2. **평가 화면 UI 개선**:
   - 기존 평가가 있는 사용자에게 "수정" 뱃지 표시
   - 기존 평가 데이터 자동 로드 및 수정 모드
   - 완료 메시지도 신규/수정 상황에 맞게 변경

3. **데이터 구조 최적화**:
   - meetingId 조건 제거로 사용자별 평생 1번 평가 보장
   - 기존 평가 수정 시 동일 문서 업데이트

##### 🛡️ 평점 조작 방지 효과
- **가짜 모임**: 아무리 많이 만나도 1번만 평가 → 의미없음
- **다중 계정**: 카카오 인증으로 계정 생성 어려움
- **반복 부풀리기**: 같은 사람끼리 1번씩만 평가 가능
- **자연스러운 제한**: 첫인상이 가장 중요하다는 현실적 접근

##### 📱 사용자 경험
- **직관적**: "이전에 평가한 게 있네? 수정할까?"
- **유연성**: 더 친해지면 평점 올려줄 수 있음
- **복잡하지 않음**: GPS나 시간 제한 등 불편한 검증 없음

## 🔥 Firebase Functions 현황 (2025-01-15 분석)

### ✅ 현재 프로덕션에서 사용 중인 함수들 (10개)

#### 🔔 푸시 알림 시스템
- **`sendFCMMessage`** - 개별 FCM 푸시 알림 발송
- **`sendFCMMulticast`** - 여러 기기에 일괄 푸시 알림 발송  
- **`sendMeetingNotification`** - 모임 관련 자동 알림 (참여자 변경, 채팅 등)
- **`sendNotification`** - 범용 푸시 알림 발송

#### 🍽️ 맛집 데이터 관리
- **`updateRestaurantsWeekly`** - 주간 자동 맛집 데이터 업데이트 (매주 일요일 새벽 2시)
- **`updateRestaurantsManual`** - 수동 맛집 데이터 업데이트 (HTTP 엔드포인트)

#### 📅 모임 자동 완료 시스템
- **`checkMeetingAutoCompletion`** - 모임 자동 완료 알림 체크 (현재 2분마다 실행 - 테스트용 설정)
- **`scheduleMeetingAutoCompletion`** - 모임 생성 시 자동 완료 스케줄 등록

#### 🔧 시스템 관리
- **`healthCheck`** - 시스템 상태 확인 HTTP 엔드포인트

### ⚠️ 레거시/사용 의심 함수들 (1개)
- **`deleteAllAuthUsers`** - 모든 Firebase Auth 사용자 삭제 *(개발용, 프로덕션에서 위험)*

### 🔧 로컬 유틸리티 파일들 (유지 필요, 8개)

#### 맛집 데이터 크롤링 시스템
- **`ultimate_restaurant_crawler.js`** - 통합 맛집 데이터 수집 시스템 (YouTube + Google Places + 네이버)
- **`naver_crawler.js`** - 네이버 API 전용 크롤러
- **`kakao_crawler.js`** - 카카오 API 전용 크롤러

#### 데이터 관리 스크립트
- **`backup_restaurants.js`** - 식당 데이터 백업 유틸리티
- **`update_existing_restaurants.js`** - 기존 식당 정보 업데이트 스크립트

#### 데이터베이스 상태 확인 스크립트
- **`check_firestore_structure.js`** - Firestore 구조 확인
- **`check_google_places_data.js`** - Google Places 데이터 확인
- **`check_naver_blog_structure.js`** - 네이버 블로그 데이터 구조 확인
- **`check_restaurants.js`** - 식당 데이터 상태 확인
- **`check_province_values.js`** - 지역 데이터 확인
- **`check_region_field.js`** - 지역 필드 확인

### 🧪 테스트/개발용 파일들 (정리 대상, 7개)
- **`test_crawler_fix.js`** - 크롤러 Google Places 기능 테스트
- **`test_google_places_only.js`** - Google Places API 단독 테스트
- **`test_google_places_simple.js`** - 간단한 Google Places 테스트
- **`test_flutter_model.js`** - Flutter 모델 테스트
- **`test_flutter_parsing.js`** - Flutter 파싱 테스트
- **`delete_all_restaurants.js`** - 모든 식당 데이터 삭제 *(위험)*
- **`delete_seoul_restaurants.js`** - 서울 식당 데이터 삭제 *(위험)*

### 🚨 주요 이슈 및 개선사항
1. **테스트용 설정이 프로덕션 적용**: `checkMeetingAutoCompletion`이 2분마다 실행 (원래 30분)
2. ✅ **레거시 함수 정리 완료**: `createCustomToken` 제거됨 (2025-01-15)
3. **위험한 삭제 함수들**: `deleteAllAuthUsers`, `delete_*_restaurants.js` 보안 강화 필요
4. **강력한 크롤링 시스템**: YouTube, Google Places, 네이버 API를 활용한 종합적 맛집 데이터 수집

## 🚀 개발 명령어

### Flutter 앱
- `flutter run` - Flutter 앱 실행 (개발 모드)
- `flutter test` - Flutter 앱 테스트 실행
- `flutter build` - Flutter 앱 빌드
- `flutter pub get` - 의존성 설치

### Firebase Functions
- `firebase deploy --only functions` - Firebase Functions 배포
- `firebase functions:log` - Functions 로그 확인
- `firebase functions:list` - 배포된 Functions 목록 확인

## 🎨 UI 디자인 시스템

### 🎨 컬러 팔레트 (당근마켓 스타일 + 베이지 포인트)
- **Primary**: `#D2B48C` (베이지 - 당근마켓 주황색 위치에만!)
- **Secondary**: `#666666` (당근마켓 회색)
- **Background**: `#FFFFFF` (당근마켓 순백색)
- **Surface**: `#FFFFFF` (당근마켓 순백색)
- **SurfaceContainer**: `#F9F9F9` (당근마켓 연한 회색 배경)
- **OnSurface**: `#000000` (당근마켓 검은색 텍스트)
- **Outline**: `#999999` (당근마켓 연한 회색)
- **베이지 사용처**: FAB, 모집중 배지, 선택된 필터, 중요 버튼만
- **폰트**: Noto Sans KR (Google Fonts)

### 📐 디자인 가이드라인
- **카드 스타일**: 당근마켓 참조, 둥근 모서리 12px
- **간격**: 16px 기본, 8px 작은 간격, 24px 큰 간격
- **그림자**: elevation 2-4, 베이지 톤 그림자
- **버튼**: FAB은 Highlight 컬러, 일반 버튼은 Primary
- **타이포그래피**: 제목 18-24px, 본문 14-16px, 캡션 12px

### 📱 UI 참조 이미지 (ui-reference/)
- `ref_home.jpeg` - 당근마켓 스타일 홈 화면 (카드형 리스트)
- `ref_chat.jpeg` - 채팅 리스트 화면 (프로필 + 메시지 미리보기)
- `ref_map.jpeg` - 카카오맵 스타일 지도 화면 (검색바 + 필터 칩)
- `ref_profile.jpeg` - 마이페이지 (사용자 정보 + 그리드 메뉴)
- `ref_etc.jpeg` - 동네 모임 스타일 (카테고리 + 텍스트 리스트)

## 📊 현재 개발 상태 (2025-01-15 최신)

### ✅ Phase 1 MVP - 100% 완료 🎉

#### 🎨 완성된 UI/UX 시스템
- ✅ Flutter 프로젝트 완전 구조 설정
- ✅ 당근마켓 컬러 팔레트 + 베이지 포인트 적용
- ✅ Noto Sans KR 폰트 시스템 & Material 3 테마
- ✅ 디자인 토큰 시스템 (8px 그리드)
- ✅ 통합 TextStyle 클래스 및 공통 컴포넌트 시스템

#### 🔐 완벽한 인증 시스템
- ✅ 카카오 로그인 완전 구현 (키 해시 문제 해결)
- ✅ Firebase 익명 인증 연동
- ✅ 미니멀 회원가입 시스템 (30초 완료)
- ✅ 개인정보 수집 확장 (성별, 출생연도, 전화번호)
- ✅ AuthWrapper로 완벽한 사용자 상태 관리

#### 🗺️ 카카오맵 통합 시스템
- ✅ 카카오맵 API 완전 연동 (WebView 방식)
- ✅ 풀스크린 지도 UI + 플로팅 검색바
- ✅ 동적 마커 시스템 (SVG 기반)
- ✅ 지도 상태 유지 기능
- ✅ 실시간 식당 검색 (카카오 API)

#### 📱 모임 시스템
- ✅ 모임 생성 화면 완성 (식당 검색 연동)
- ✅ 모임 리스트 시스템 (MeetingCard 컴포넌트)
- ✅ 완벽한 필터 시스템 (홈 ↔ 지도 탭 동기화)
- ✅ 모임 상세 화면 기본 구조

#### 💬 채팅 & 프로필
- ✅ 채팅방 리스트 화면
- ✅ 마이페이지 완성 (프로필 헤더, 통계, 평가)
- ✅ 사용자 프로필 화면 (뱃지, 즐겨찾기 맛집)

#### 🍽️ 맛집 데이터 시스템
- ✅ 카카오 API 실시간 식당 검색
- ✅ Google Places API 상세 정보 통합
- ✅ YouTube 맛집 데이터 수집 시스템
- ✅ 네이버 블로그 리뷰 수집
- ✅ 맛집 상세 화면 (다중 사진 갤러리, 영업시간)

#### 🚀 배포 완료
- ✅ Google Play Store 정식 배포
- ✅ AAB/APK 빌드 완료 (50.7MB)
- ✅ 카카오 로그인 Play Store 문제 완전 해결
- ✅ 앱 아이콘, 스플래시 화면 적용

### 🔄 Phase 2 - 고급 기능 개발

#### 🎯 현재 우선순위 작업
1. **모임 승인 시스템** 🔄 (진행중)
2. **평점 조작 방지 기본 시스템** 🚨 (보안 강화 - 긴급)
3. **즐겨찾기 식당 시스템** (중요한 사용자 경험)
4. **지도 재검색 기능** (UX 개선)
5. **모임 완료 시스템** (핵심 기능)
6. **상호 평가 시스템** (고도화 기능)

#### 🔮 Phase 3 - AI 및 고급 추천
- AI 기반 맛집 추천 시스템
- 소셜 피드 및 리뷰 시스템
- 고급 검색 및 필터
- 사용자 행동 분석 및 개인화

## 🔄 Claude Code 작업 프로세스

### 📋 세션 시작 시 체크리스트
1. **Git 상태 확인**: `git status`, `git log --oneline -5`
2. **CLAUDE.md 자동 로드**: 프로젝트 상황 파악 (이 파일이 1차 참조 문서)
3. **화면별 파일 매핑 가이드 확인**: UI 수정 전 필수 확인
4. **최근 파일 확인**: 마지막 작업 추적

### 📝 작업 관리 규칙
- **TodoWrite 사용**: 3단계 이상 복잡한 작업만
- **단계별 진행**: in_progress → completed 즉시 업데이트
- **파일 우선순위**: 기존 파일 수정 > 새 파일 생성
- **코멘트 금지**: 사용자 요청 시에만 추가

### 🔧 Git 작업 규칙  
- **커밋 타이밍**: 기능 완료 시 또는 사용자 요청 시만
- **커밋 전 체크**: git status → git diff → lint 체크 (가능하면)
- **자동 커밋 금지**: 반드시 사용자 승인 필요

### 🍽️ 앱 개발 워크플로우
1. 관련 파일 읽기 (기존 패턴 파악)
2. 화면별 파일 매핑 가이드 확인 (실수 방지)
3. TodoWrite로 작업 계획 (복잡한 작업만)
4. 단계별 구현
5. Flutter 실행 테스트 (`flutter run`)
6. 에러 로그 확인

### 📚 문서 체계 및 활용법
- **CLAUDE.md**: 1차 참조 (프로젝트 현황, 개발 프로세스, 명령어)
- **docs/PRD.md**: 제품 요구사항 및 기능 명세서
- **docs/DEVELOPMENT_STORY.md**: 개발 전체 과정 스토리
- **docs/FLUTTER_FIREBASE_GUIDE.md**: 새 프로젝트 Claude용 완전 가이드
- **docs/MARKETING_STRATEGY.md**: 체계적 마케팅 전략 가이드

## 🛠️ 개발 메모

### 작업 시 주의사항
- 에뮬레이터 실행은 가급적 사용자에게 요청할 것!
- 앱을 실행시키는거는 가급적 나한테 요청하도록 에뮬레이터이든 기기이든
- **중요**: UI 수정 전 반드시 위의 화면별 파일 매핑 가이드 확인할 것!

### 빠른 파일 찾기 가이드
```bash
# 홈 화면 관련 (모든 탭)
lib/screens/home/home_screen.dart

# 인증 관련
lib/screens/auth/

# 모임 관련
lib/screens/meeting/

# 프로필 관련 (주의: 마이페이지는 home_screen.dart에 있음)
lib/screens/profile/

# 채팅 관련 (주의: 채팅 리스트는 home_screen.dart에 있음)
lib/screens/chat/

# 설정 관련
lib/screens/settings/
```

## 🎯 개발 우선순위 TODO 리스트

### 1. 모임 승인 시스템 🔔 (진행중)
**목표**: 모임 참석 전 호스트 승인 절차 추가
- 신청 시스템 변경 ("모임 참석하기" → "모임 신청하기")
- 호스트 알림 및 신청자 관리 화면
- 수락/거절 처리 로직

### 2. 평점 조작 방지 기본 시스템 🚨 ✅ (완료 - 1대1 평가 시스템)
**목표**: 가짜 모임 및 평점 조작 방지를 위한 혁신적인 1대1 평가 시스템
- ✅ **1대1 평가 제한**: 한 사용자당 평생 1번만 평가 가능 (수정 허용)
- ✅ **기존 평가 수정 모드**: 두 번째 만남부터는 이전 평가 수정
- ✅ **완벽한 조작 방지**: 가짜 모임, 다중 계정 모두 무의미화
- ✅ **자연스러운 UX**: 복잡한 검증 없이 간단하고 효과적

### 3. 즐겨찾기 식당 시스템 ⭐
**목표**: 식당 즐겨찾기 및 관련 알림 시스템
- 식당 상세에서 하트 버튼으로 즐겨찾기 추가/해제
- 마이페이지에서 즐겨찾기 식당 목록 보기
- 즐겨찾기한 식당에서 새 모임 생성 시 알림 발송

### 3. 지도 "이 지역 재검색" 기능 🗺️
**목표**: 지도 이동 후 해당 지역 재검색 기능
- 지도에서 검색 후 리스트가 뜰 때 재검색 아이콘 표시
- 현재 지도 중심점 기준으로 재검색 실행

### 4. 모임 완료 시스템 🎉
**목표**: 자동/수동 모임 완료 및 후속 처리
- 모임 시간 + 2시간 후 자동 완료 모달
- 채팅방 상태 관리 옵션
- 완료 알림 발송

### 6. 상호 평가 시스템 ⭐
**목표**: 모임 완료 후 참여자 상호 평가
- 익명 평가 시스템
- 3가지 평가 항목별 별점 입력
- 실시간 평점 반영

### 7. 사용자 특성 뱃지 시스템 🏷️
**목표**: 회원가입/프로필에서 개성을 나타내는 뱃지 선택
- 식사 스타일, 성격/취향, 음식 취향별 뱃지
- 회원가입 시 선택적 추가
- 프로필에서 언제든 수정 가능

## 🎉 프로젝트 성과 요약

### 🏆 달성한 성과
- ✅ **Flutter 앱 개발**: 완전한 기능을 가진 네이티브 앱 완성
- ✅ **Firebase 백엔드**: 인증, 데이터베이스, 스토리지 완전 연동
- ✅ **카카오 API 통합**: 지도, 검색, 로그인 시스템 완성
- ✅ **Google Play Store**: 정식 배포까지 성공적으로 완료
- ✅ **완전한 MVP**: Phase 1의 모든 핵심 기능 100% 구현

### 🚀 기술적 성취
- **Frontend**: Flutter + Dart로 크로스 플랫폼 앱 개발
- **Backend**: Firebase Auth + Firestore + Storage 완전 연동
- **외부 API**: 카카오맵, 카카오 검색, 카카오 로그인, Google Places API 통합
- **UX/UI**: 당근마켓 스타일 + 베이지 포인트 컬러 + 완전한 UI 일관성 시스템
- **DevOps**: 키스토어, 앱 서명, Play Store 배포 파이프라인 구축

### 🎯 완성된 핵심 기능들
1. **🔐 완벽한 인증 시스템**: 카카오 로그인 + Firebase 연동
2. **🗺️ 지도 기반 매칭**: 카카오맵 + 실시간 식당 검색
3. **📱 모임 생성/관리**: 완전한 워크플로우 + 실시간 반영
4. **🎨 일관된 UI 시스템**: 8px 그리드 + 디자인 토큰 + 공통 컴포넌트
5. **🚀 배포 완료**: Google Play Store 정식 출시

**"혼여는 좋지만 맛집은 함께 🥹"** 라는 컨셉으로 시작된 이 앱이 실제로 사람들에게 도움이 되는 서비스가 되기를 기대합니다! 🚀