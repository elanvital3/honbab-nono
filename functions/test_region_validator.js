/**
 * 지역 검증 시스템 테스트
 */

const RegionValidator = require('./region_validator');

// 테스트 케이스들
const testCases = [
  {
    name: '제주도해녀세자매',
    youtubeRegion: '제주도',
    kakaoResult: {
      placeName: '제주도해녀세자매',
      address: '제주특별자치도 제주시 조천읍 신촌리 1438',
      latitude: 33.2345,
      longitude: 126.5678
    },
    expected: true
  },
  {
    name: '장충동왕족발 변동점',
    youtubeRegion: '제주도',
    kakaoResult: {
      placeName: '장충동왕족발 변동점',
      address: '대전광역시 서구 도마동 84-1',
      latitude: 36.3504,
      longitude: 127.3845
    },
    expected: false
  },
  {
    name: '부산맛집',
    youtubeRegion: '부산',
    kakaoResult: {
      placeName: '부산맛집',
      address: '부산광역시 해운대구 중동 1393-3',
      latitude: 35.1595,
      longitude: 129.1603
    },
    expected: true
  },
  {
    name: '스타벅스 제주공항점',
    youtubeRegion: '제주도',
    kakaoResult: {
      placeName: '스타벅스 제주공항점',
      address: '제주특별자치도 제주시 용담2동 2002',
      latitude: 33.5067,
      longitude: 126.4930
    },
    expected: true
  },
  {
    name: '스타벅스 강남점',
    youtubeRegion: '제주도',
    kakaoResult: {
      placeName: '스타벅스 강남점',
      address: '서울특별시 강남구 역삼동 123-45',
      latitude: 37.5665,
      longitude: 127.0317
    },
    expected: true  // 체인점 예외 허용
  }
];

console.log('🧪 지역 검증 시스템 테스트 시작\n');

testCases.forEach((testCase, index) => {
  console.log(`${index + 1}. 테스트: ${testCase.name}`);
  console.log(`   유튜브 지역: ${testCase.youtubeRegion}`);
  console.log(`   카카오 주소: ${testCase.kakaoResult.address}`);
  
  // 체인점 예외 체크
  const isChain = RegionValidator.isAllowedException(testCase.kakaoResult.placeName, testCase.youtubeRegion, testCase.kakaoResult.address);
  if (isChain) {
    console.log(`   ⚡ 체인점 체크: ${testCase.kakaoResult.placeName} → ${isChain ? '예외 허용' : '일반 매장'}`);
  }
  
  const result = RegionValidator.validateRegion(testCase.youtubeRegion, testCase.kakaoResult);
  const passed = result === testCase.expected;
  
  console.log(`   결과: ${result ? '✅ 통과' : '❌ 차단'} (예상: ${testCase.expected ? '통과' : '차단'})`);
  console.log(`   ${passed ? '🟢 테스트 성공' : '🔴 테스트 실패'}\n`);
});

console.log('🎯 테스트 완료!\n');

// 추가 주소 추출 테스트
console.log('📍 주소 추출 테스트:');
const addresses = [
  '제주특별자치도 제주시 조천읍 신촌리 1438',
  '대전광역시 서구 도마동 84-1',
  '서울특별시 강남구 역삼동 123-45',
  '부산광역시 해운대구 중동 1393-3',
  '경상북도 경주시 황리단길 123'
];

addresses.forEach(address => {
  const region = RegionValidator.extractRegionFromAddress(address);
  console.log(`   ${address} → ${region || '인식 불가'}`);
});