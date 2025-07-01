# Firestore 데이터베이스 스키마

## restaurant_ratings 컬렉션

### 목적
식당별 평점 정보 저장 (네이버/카카오 등 외부 플랫폼 평점)

### 스키마 구조
```typescript
interface RestaurantRating {
  // 기본 식별자
  restaurantId: string;           // 카카오/네이버 API의 식당 고유 ID
  name: string;                   // 식당명
  
  // 위치 정보
  address: string;                // 주소
  latitude: number;               // 위도
  longitude: number;              // 경도
  
  // 평점 정보
  naverRating?: {
    score: number;                // 평점 (0.0 ~ 5.0)
    reviewCount: number;          // 리뷰 수
    url: string;                  // 네이버 지도 URL
  };
  
  kakaoRating?: {
    score: number;                // 평점 (0.0 ~ 5.0)
    reviewCount: number;          // 리뷰 수
    url: string;                  // 카카오맵 URL
  };
  
  // 메타데이터
  category: string;               // 식당 카테고리
  lastUpdated: Timestamp;         // 마지막 업데이트 시간
  createdAt: Timestamp;           // 생성 시간
  
  // 딥링크 정보
  deepLinks: {
    naver?: string;               // 네이버 지도 앱 딥링크
    kakao?: string;               // 카카오맵 앱 딥링크
  };
}
```

### 인덱스
- `restaurantId` (Primary Key)
- `name` (검색용)
- `lastUpdated` (업데이트 순 정렬용)

### 샘플 데이터
```json
{
  "restaurantId": "kakao_27184746",
  "name": "은희네해장국 강남점",
  "address": "서울 강남구 테헤란로 123",
  "latitude": 37.5012743,
  "longitude": 127.0396587,
  "naverRating": {
    "score": 4.2,
    "reviewCount": 847,
    "url": "https://map.naver.com/v5/entry/place/27184746"
  },
  "kakaoRating": {
    "score": 4.1,
    "reviewCount": 234,
    "url": "https://place.map.kakao.com/27184746"
  },
  "category": "음식점 > 한식 > 해장국",
  "lastUpdated": "2025-06-30T12:00:00Z",
  "createdAt": "2025-06-30T10:00:00Z",
  "deepLinks": {
    "naver": "nmap://place?id=27184746",
    "kakao": "kakaomap://place?id=27184746"
  }
}
```

### 업데이트 정책
- 평점 데이터는 일주일에 한 번 자동 업데이트
- 새로운 식당 발견 시 즉시 추가
- 평점 변화율이 클 경우 우선 업데이트

### 보안 규칙
```javascript
// Firestore 보안 규칙 (restaurant_ratings 컬렉션)
match /restaurant_ratings/{ratingId} {
  allow read: if true;  // 모든 사용자 읽기 허용 (공개 정보)
  allow write: if false; // 쓰기는 관리자/크롤러만 (서버에서만)
}
```