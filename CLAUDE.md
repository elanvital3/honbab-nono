# 혼밥노노 (HonbabNoNo) - 맛집 동행 매칭 앱

## 📋 프로젝트 개요
혼자 먹기 싫은 사람들이 **"같이 먹고 싶어~"** 니즈를 해결할 수 있는 안전하고 편리한 맛집 동행 매칭 서비스

## 🛠️ 기술 스택
- **Mobile**: React Native + TypeScript
- **Backend**: Node.js + Express + TypeScript + MongoDB
- **Map**: 카카오맵 API
- **Chat**: Socket.io
- **Auth**: 소셜 로그인 + SMS 인증

## 🏗️ 프로젝트 구조
```
honbab-nono/
├── mobile-app/         # React Native 앱
│   ├── src/
│   │   ├── components/ # 재사용 컴포넌트
│   │   │   ├── common/ # 공통 컴포넌트
│   │   │   ├── auth/   # 인증 관련
│   │   │   ├── meeting/# 모임 관련
│   │   │   ├── chat/   # 채팅 관련
│   │   │   ├── profile/# 프로필 관련
│   │   │   └── map/    # 지도 관련
│   │   ├── screens/    # 화면 컴포넌트
│   │   │   ├── auth/   # 로그인/회원가입
│   │   │   ├── meeting/# 모임 생성/리스트/상세
│   │   │   ├── chat/   # 채팅
│   │   │   ├── profile/# 마이페이지
│   │   │   └── map/    # 지도 화면
│   │   ├── navigation/ # 네비게이션
│   │   ├── services/   # API 서비스
│   │   ├── utils/      # 유틸리티
│   │   ├── types/      # TypeScript 타입
│   │   ├── assets/     # 이미지/아이콘
│   │   └── styles/     # 스타일
│   ├── android/        # 안드로이드 설정
│   └── ios/           # iOS 설정
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
- `npm run dev` - 전체 개발 서버 실행
- `npm run dev:mobile` - React Native 앱 실행
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
1. React Native 프로젝트 초기 설정
2. 회원가입/로그인 화면부터 시작
3. 모임 리스트 및 상세 화면
4. 지도 연동 및 식당 검색
5. 채팅 시스템 구현

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
4. Expo 실행 테스트 (`npm start`)
5. 에러 로그 확인

### 📚 문서 우선순위
- **CLAUDE.md**: 1차 참조 (개발 현황, 프로세스, 명령어)
- **PRD.md**: 2차 참조 (기능 명세, 요구사항)
- **package.json**: 기술 스택 및 스크립트 확인

## 🚧 현재 개발 상태
### ✅ 완료된 작업
- React Native 프로젝트 기본 구조 설정
- 네비게이션 시스템 (AppNavigator.tsx)
- 기본 화면들 (HomeScreen, LoginScreen 등)
- 소셜 로그인 UI (App.tsx)

### 🔄 진행 중인 작업
- GitHub 레포지토리 설정
- 프로젝트 문서화 및 프로세스 정형화

### 📋 다음 우선순위
1. 네비게이션 연결 (App.tsx ↔ AppNavigator.tsx)
2. 로그인 화면 분리 및 상태 관리
3. Expo 실행 환경 안정화
4. 기본 화면들 기능 구현