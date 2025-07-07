/**
 * 스마트 매칭 시스템 테스트
 * 실제 사례로 매칭 성능 검증
 */

const SmartMatcher = require('./smart_matcher');

// 테스트 케이스들
const testCases = [
  {
    name: '제주바다마찬씨갤러리',
    region: '제주도',
    mockKakaoResults: [
      {
        place_name: '바다는 잘 있습니다',
        address_name: '제주특별자치도 제주시 어딘가',
        category_name: '음식점 > 한식'
      },
      {
        place_name: '제주바다 마찬씨 갤러리', // 띄어쓰기 차이
        address_name: '제주특별자치도 제주시 올바른주소',
        category_name: '음식점 > 한식'
      },
      {
        place_name: '마찬씨네',
        address_name: '제주특별자치도 제주시 또다른주소',
        category_name: '음식점 > 한식'
      }
    ]
  },
  {
    name: '돈사돈',
    region: '제주도',
    mockKakaoResults: [
      {
        place_name: '돈사돈 제주공항점',
        address_name: '제주특별자치도 제주시 공항로',
        category_name: '음식점 > 한식 > 고기요리'
      },
      {
        place_name: '돈가스랑',
        address_name: '제주특별자치도 제주시 어딘가',
        category_name: '음식점 > 일식'
      },
      {
        place_name: '돈사돈',
        address_name: '제주특별자치도 제주시 중앙로',
        category_name: '음식점 > 한식'
      }
    ]
  },
  {
    name: '제주전복죽맛집',
    region: '제주도',
    mockKakaoResults: [
      {
        place_name: '전복죽 전문점',
        address_name: '제주특별자치도 서귀포시',
        category_name: '음식점 > 한식'
      },
      {
        place_name: '제주맛집',
        address_name: '제주특별자치도 제주시',
        category_name: '음식점'
      },
      {
        place_name: '바다전복',
        address_name: '제주특별자치도 제주시',
        category_name: '음식점 > 한식 > 해물요리'
      }
    ]
  }
];

function runTests() {
  console.log('🧪 스마트 매칭 시스템 테스트 시작\n');
  
  testCases.forEach((testCase, index) => {
    console.log(`\n=== 테스트 ${index + 1}: "${testCase.name}" ===`);
    console.log(`지역: ${testCase.region}`);
    console.log(`검색 결과 후보: ${testCase.mockKakaoResults.length}개`);
    
    testCase.mockKakaoResults.forEach((result, idx) => {
      console.log(`  ${idx + 1}. ${result.place_name} (${result.address_name})`);
    });
    
    console.log('\n🔍 매칭 과정:');
    const bestMatch = SmartMatcher.findBestMatch(
      testCase.name, 
      testCase.mockKakaoResults, 
      testCase.region
    );
    
    if (bestMatch) {
      console.log(`\n✅ 최종 결과: "${bestMatch.place_name}"`);
      console.log(`   매칭 점수: ${bestMatch.matchScore.toFixed(3)}`);
      console.log(`   주소: ${bestMatch.address_name}`);
      
      const isValid = SmartMatcher.validateMatch(testCase.name, bestMatch);
      console.log(`   검증 결과: ${isValid ? '✅ 통과' : '❌ 실패'}`);
    } else {
      console.log('\n❌ 적절한 매칭을 찾을 수 없음');
    }
  });
  
  console.log('\n🎯 테스트 완료!');
  console.log('\n📋 기대 결과:');
  console.log('1. "제주바다마찬씨갤러리" → "제주바다마찬씨갤러리" (정확 매칭)');
  console.log('2. "돈사돈" → "돈사돈" (정확 매칭, 지점명 제외)');
  console.log('3. "제주전복죽맛집" → "전복죽 전문점" 또는 매칭 실패 (일반명사 포함)');
}

// 개별 유사도 테스트
function testSimilarity() {
  console.log('\n🔬 유사도 알고리즘 테스트:');
  
  const similarityTests = [
    ['제주바다마찬씨갤러리', '제주바다마찬씨갤러리'], // 완전 일치
    ['제주바다마찬씨갤러리', '바다마찬씨갤러리'],     // 부분 일치
    ['제주바다마찬씨갤러리', '바다는 잘 있습니다'],    // 부분 유사
    ['돈사돈', '돈사돈 제주공항점'],               // 확장명 포함
    ['돈사돈', '돈가스랑'],                       // 유사하지만 다름
  ];
  
  similarityTests.forEach(([str1, str2]) => {
    const score = SmartMatcher.calculateSimilarity(str1, str2);
    console.log(`"${str1}" vs "${str2}": ${score.toFixed(3)}`);
  });
}

// 키워드 추출 테스트
function testKeywordExtraction() {
  console.log('\n🔤 키워드 추출 테스트:');
  
  const names = [
    '제주바다마찬씨갤러리',
    '돈사돈',
    '제주전복죽맛집',
    '서울숨은맛집카페',
    '부산밀면집'
  ];
  
  names.forEach(name => {
    const keywords = SmartMatcher.extractKeywords(name);
    console.log(`"${name}" → [${keywords.join(', ')}]`);
  });
}

// 모든 테스트 실행
if (require.main === module) {
  runTests();
  testSimilarity();
  testKeywordExtraction();
}

module.exports = { runTests, testSimilarity, testKeywordExtraction };