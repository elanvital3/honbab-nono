# Google Places API 설정 가이드

## 🔑 API 키 설정

### 1. Google Cloud Console 설정
1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 선택 또는 새 프로젝트 생성
3. **API 및 서비스** → **라이브러리** 이동
4. **Places API** 검색 후 활성화
5. **사용자 인증 정보** → **사용자 인증 정보 만들기** → **API 키**

### 2. 환경변수 설정
```bash
# flutter-app/.env 파일에 추가
GOOGLE_PLACES_API_KEY=YOUR_API_KEY_HERE
```

### 3. 사용량 제한 설정 (권장)
- **Places API (SKU: Place Details)**: 일 1,000회
- **Places API (SKU: Nearby Search)**: 일 1,000회
- **Places API (SKU: Text Search)**: 일 1,000회

## 📊 예상 사용량
- **현재 맛집 수**: 66개
- **API 호출**: 맛집당 2-3회 (검색 + 상세정보)
- **총 호출 예상**: ~200회 (무료 할당량 내)

## 🚀 실행 방법
```bash
cd functions
node google_places_enhancer.js
```

## 📋 수집 데이터
- ⭐ **Google 평점** (1-5점)
- 📊 **리뷰 수** (총 평가 수)
- 📝 **최신 리뷰 5개**
- 📸 **Google 사진 5장**
- 💰 **가격 수준** (1-4단계)
- ⏰ **영업 상태** (현재 영업 중/마감)
- 📞 **전화번호**

## 🎯 결과
유튜브에서 검증된 맛집 + Google의 실제 평점/리뷰 = **완벽한 맛집 데이터**! 🎉