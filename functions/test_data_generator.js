/**
 * 테스트용 평점 데이터 생성기
 * Firebase 인증 없이 샘플 데이터를 생성
 */

const testRatings = [
  {
    restaurantId: 'unified_은희네해장국_서울강남구',
    name: '은희네해장국 강남점',
    address: '서울 강남구 테헤란로 123',
    latitude: 37.5012743,
    longitude: 127.0396587,
    naverRating: {
      score: 4.2,
      reviewCount: 847,
      url: 'https://map.naver.com/v5/entry/place/27184746'
    },
    kakaoRating: {
      score: 4.1,
      reviewCount: 234,
      url: 'https://place.map.kakao.com/27184746'
    },
    category: '음식점 > 한식 > 해장국',
    deepLinks: {
      naver: 'nmap://place?id=27184746',
      kakao: 'kakaomap://place?id=27184746'
    }
  },
  {
    restaurantId: 'unified_맘스터치_서울강남구',
    name: '맘스터치 강남점',
    address: '서울 강남구 역삼로 456',
    latitude: 37.5001234,
    longitude: 127.0385678,
    naverRating: {
      score: 4.0,
      reviewCount: 523,
      url: 'https://map.naver.com/v5/entry/place/12345678'
    },
    kakaoRating: {
      score: 3.9,
      reviewCount: 198,
      url: 'https://place.map.kakao.com/12345678'
    },
    category: '음식점 > 패스트푸드 > 햄버거',
    deepLinks: {
      naver: 'nmap://place?id=12345678',
      kakao: 'kakaomap://place?id=12345678'
    }
  },
  {
    restaurantId: 'unified_스타벅스_서울강남구',
    name: '스타벅스 강남역점',
    address: '서울 강남구 강남대로 789',
    latitude: 37.4979876,
    longitude: 127.0276543,
    naverRating: {
      score: 4.3,
      reviewCount: 1256,
      url: 'https://map.naver.com/v5/entry/place/87654321'
    },
    kakaoRating: {
      score: 4.2,
      reviewCount: 876,
      url: 'https://place.map.kakao.com/87654321'
    },
    category: '음식점 > 카페 > 커피전문점',
    deepLinks: {
      naver: 'nmap://place?id=87654321',
      kakao: 'kakaomap://place?id=87654321'
    }
  },
  {
    restaurantId: 'unified_김밥천국_서울강남구',
    name: '김밥천국 강남점',
    address: '서울 강남구 논현로 321',
    latitude: 37.5089876,
    longitude: 127.0198765,
    naverRating: {
      score: 3.8,
      reviewCount: 334,
      url: 'https://map.naver.com/v5/entry/place/11223344'
    },
    category: '음식점 > 분식 > 김밥',
    deepLinks: {
      naver: 'nmap://place?id=11223344'
    }
  },
  {
    restaurantId: 'unified_피자헛_서울강남구',
    name: '피자헛 강남점',
    address: '서울 강남구 봉은사로 654',
    latitude: 37.5156789,
    longitude: 127.0309876,
    kakaoRating: {
      score: 4.0,
      reviewCount: 567,
      url: 'https://place.map.kakao.com/55667788'
    },
    category: '음식점 > 양식 > 피자',
    deepLinks: {
      kakao: 'kakaomap://place?id=55667788'
    }
  }
];

console.log('📋 생성된 테스트 평점 데이터:');
console.log(JSON.stringify(testRatings, null, 2));

console.log('\n📊 데이터 요약:');
console.log(`전체 식당: ${testRatings.length}개`);
console.log(`네이버 평점: ${testRatings.filter(r => r.naverRating).length}개`);
console.log(`카카오 평점: ${testRatings.filter(r => r.kakaoRating).length}개`);
console.log(`양쪽 모두: ${testRatings.filter(r => r.naverRating && r.kakaoRating).length}개`);

// JSON 파일로 저장
const fs = require('fs');
fs.writeFileSync('test_restaurant_ratings.json', JSON.stringify(testRatings, null, 2));
console.log('\n💾 test_restaurant_ratings.json 파일로 저장 완료');

module.exports = testRatings;