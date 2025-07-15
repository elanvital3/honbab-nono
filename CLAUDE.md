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

## 🚀 개발 명령어

### Flutter 앱
- `flutter run` - Flutter 앱 실행 (개발 모드)
- `flutter test` - Flutter 앱 테스트 실행
- `flutter build` - Flutter 앱 빌드
- `flutter pub get` - 의존성 설치

### Firebase Functions (선택적)
- `firebase deploy --only functions` - Firebase Functions 배포
- `firebase functions:log` - Functions 로그 확인

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
2. **즐겨찾기 식당 시스템** (중요한 사용자 경험)
3. **지도 재검색 기능** (UX 개선)
4. **모임 완료 시스템** (핵심 기능)
5. **상호 평가 시스템** (고도화 기능)

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

### 2. 즐겨찾기 식당 시스템 ⭐
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

### 5. 상호 평가 시스템 ⭐
**목표**: 모임 완료 후 참여자 상호 평가
- 익명 평가 시스템
- 3가지 평가 항목별 별점 입력
- 실시간 평점 반영

### 6. 사용자 특성 뱃지 시스템 🏷️
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