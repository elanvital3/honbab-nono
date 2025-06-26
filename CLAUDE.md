# 혼밥노노 (HonbabNoNo) - 맛집 동행 매칭 앱

## 📋 프로젝트 개요
혼자 먹기 싫은 사람들이 **"같이 먹고 싶어~"** 니즈를 해결할 수 있는 안전하고 편리한 맛집 동행 매칭 서비스

## 🛠️ 기술 스택
- **Mobile**: Flutter + Dart
- **Backend**: Node.js + Express + TypeScript + MongoDB
- **Map**: 카카오맵 API
- **Chat**: Socket.io
- **Auth**: 소셜 로그인 + SMS 인증

## 🏗️ 프로젝트 구조
```
honbab-nono/
├── flutter-app/        # Flutter 앱
│   ├── lib/
│   │   ├── components/ # 재사용 컴포넌트
│   │   │   ├── common/ # 공통 컴포넌트  
│   │   │   ├── auth/   # 인증 관련
│   │   │   ├── meeting/# 모임 관련
│   │   │   ├── chat/   # 채팅 관련
│   │   │   ├── profile/# 프로필 관련
│   │   │   └── map/    # 지도 관련
│   │   ├── screens/    # 화면 컴포넌트
│   │   │   ├── auth/   # 로그인/회원가입
│   │   │   ├── home/   # 홈 화면 (4탭 네비게이션)
│   │   │   ├── meeting/# 모임 생성/리스트/상세
│   │   │   ├── chat/   # 채팅
│   │   │   ├── profile/# 마이페이지
│   │   │   └── map/    # 지도 화면
│   │   ├── services/   # API 서비스
│   │   ├── utils/      # 유틸리티
│   │   ├── models/     # 데이터 모델
│   │   └── assets/     # 이미지/아이콘
│   ├── android/        # 안드로이드 설정
│   ├── ios/           # iOS 설정
│   └── pubspec.yaml   # Flutter 의존성
├── server/            # Node.js 백엔드
│   ├── src/
│   │   ├── controllers/# 컨트롤러
│   │   ├── models/     # 데이터 모델
│   │   ├── routes/     # API 라우트
│   │   ├── middleware/ # 미들웨어
│   │   ├── services/   # 비즈니스 로직
│   │   ├── utils/      # 유틸리티
│   │   ├── types/      # TypeScript 타입
│   │   └── config/     # 설정
│   └── tests/          # 백엔드 테스트
├── shared/             # 공유 코드
├── docs/               # 문서 (PRD.md 포함)
├── config/             # 설정 파일
└── scripts/            # 빌드/배포 스크립트
```

## 🚀 개발 명령어
### Flutter 앱
- `flutter run` - Flutter 앱 실행 (개발 모드)
- `flutter test` - Flutter 앱 테스트 실행
- `flutter build` - Flutter 앱 빌드
- `flutter pub get` - 의존성 설치

### 백엔드 (예정)
- `npm run dev:server` - 백엔드 서버 실행
- `npm run build` - 전체 빌드
- `npm run test` - 전체 테스트 실행
- `npm run lint` - 전체 린트 실행

## 🎯 Phase 1 MVP 핵심 기능
1. **회원가입/로그인** (소셜 로그인 + 전화번호 인증)
2. **모임 생성/리스트/상세** 화면
3. **기본 매칭 시스템** (지역 기반)
4. **그룹 채팅** 기능
5. **더치페이 계산기**
6. **기본 평가 시스템** (3개 항목 별점)
7. **카카오맵 API** 연동

## 📱 개발 시작 순서
1. ✅ Flutter 프로젝트 초기 설정
2. ✅ 회원가입/로그인 화면 UI
3. ✅ 홈 화면 (4탭 네비게이션)
4. ✅ 모임 리스트 및 카드 컴포넌트 
5. 🔄 모임 생성/상세 화면 완성
6. 지도 연동 및 식당 검색
7. 채팅 시스템 구현

## 🔄 Claude Code 작업 프로세스

### 📋 세션 시작 시 체크리스트
1. **Git 상태 확인**: `git status`, `git log --oneline -5`
2. **CLAUDE.md 자동 로드**: 프로젝트 상황 파악 (이 파일이 1차 참조 문서)
3. **package.json 확인**: 의존성 및 스크립트 상태
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
2. TodoWrite로 작업 계획 (복잡한 작업만)
3. 단계별 구현
4. Flutter 실행 테스트 (`flutter run`)
5. 에러 로그 확인

### 📚 문서 우선순위
- **CLAUDE.md**: 1차 참조 (개발 현황, 프로세스, 명령어)
- **PRD.md**: 2차 참조 (기능 명세, 요구사항)
- **package.json**: 기술 스택 및 스크립트 확인

## 🎨 UI 디자인 시스템

### 📱 UI 참조 이미지 (ui-reference/)
- `ref_home.jpeg` - 당근마켓 스타일 홈 화면 (카드형 리스트)
- `ref_chat.jpeg` - 채팅 리스트 화면 (프로필 + 메시지 미리보기)
- `ref_map.jpeg` - 카카오맵 스타일 지도 화면 (검색바 + 필터 칩)
- `ref_profile.jpeg` - 마이페이지 (사용자 정보 + 그리드 메뉴)
- `ref_etc.jpeg` - 동네 모임 스타일 (카테고리 + 텍스트 리스트)

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

## 🚧 현재 개발 상태
### ✅ 완료된 작업 (Flutter 앱)
- ✅ Flutter 프로젝트 완전 구조 설정 (pubspec.yaml, lib/ 구조)
- ✅ 소셜 로그인 화면 (카카오/구글/네이버 UI)
- ✅ 홈 화면 네비게이션 시스템 (4개 탭: 홈/지도/채팅/마이페이지)
- ✅ 모임 리스트 및 검색/필터링 기능
- ✅ MeetingCard 컴포넌트 (당근마켓 스타일)
- ✅ 당근마켓 컬러 팔레트 + 베이지 포인트 적용
- ✅ Noto Sans KR 폰트 시스템
- ✅ Material 3 테마 시스템 구축
- ✅ UI 참조 이미지 기반 디자인 완성

### 🔄 진행 중인 작업
- Git 커밋 및 다음 단계 계획 수립

### 📋 다음 우선순위 (Phase 1 MVP 계속)
1. **모임 생성 화면 완성** (CreateMeetingScreen)
   - 식당 검색/선택 기능
   - 날짜/시간 선택 위젯  
   - 모임 정보 입력 폼
   
2. **모임 상세 화면 완성** (MeetingDetailScreen)
   - 참여 신청/취소 기능
   - 참여자 정보 표시
   - 채팅방 입장 버튼
   
3. **지도 탭 구현** 
   - 카카오맵 API 연동
   - 현재 위치 기반 식당 표시
   - 모임 위치 마커 표시
   
4. **채팅 탭 기본 UI**
   - 채팅방 리스트 화면
   - Socket.io 연동 준비
   
5. **마이페이지 탭 구현**
   - 사용자 프로필 정보
   - 내 모임 히스토리
   - 설정 메뉴
   
6. **로그인 화면 기능 연결**
   - 실제 소셜 로그인 API 연동
   - 전화번호 인증 시스템
   - 사용자 세션 관리

### 🔧 기술적 다음 단계
- **상태 관리**: Provider/Riverpod 도입 검토
- **API 서비스**: HTTP 클라이언트 설정 (Dio)
- **데이터 모델**: Meeting, User, Chat 모델 확장
- **라우팅**: Named 라우팅 시스템 개선
- **백엔드 연동**: Node.js API 서버 구축