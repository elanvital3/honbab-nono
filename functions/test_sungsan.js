const axios = require('axios');
require('dotenv').config({ path: '../flutter-app/.env' });

const youtubeApiKey = process.env.YOUTUBE_API_KEY_3;

// 정확한 식당명인지 확인 함수
function isExactRestaurantName(name) {
  if (!name || name.length < 2 || name.length > 15) return false;
  if (!/[가-힣]/.test(name)) return false;
  
  const excludeTerms = [
    '상호', '매장명', '가게명', '주소', '영업시간', '전화번호', '메뉴', '가격', '주차',
    '위치', '연락처', '운영시간', '휴무일', '좌석', '포장', '배달', '가게', '특징',
    '라스트오더', '정기휴무', '브레이크타임', '편집', '음악',
    '맛집', '유명맛집', '인기맛집', '현지맛집', '로컬맛집', '숨은맛집', '찐맛집',
    '성산', '성산읍', '성산일출봉', '일출봉', '제주도', '제주시', '서귀포',
    '1위', '2위', '3위', '4위', '5위', '1등', '2등', '3등', 'BEST', 'TOP',
    '고기국수', '해물국수', '갈치회', '통갈치', '흑돼지', '해산물', '고등어회',
    '최고', '대박', '진짜', '정말', '너무', '완전', '압도적', '유명', '인생',
    '제일', '찾는', '바로', '여기가', '곳은', '가장', '없는', '많은',
    '미친', '있어요', '하세요', '보이는', '남겨주세요', '여기우다'
  ];
  
  return !excludeTerms.some(term => name.includes(term));
}

// 식당명 추출 함수
function extractRestaurantNames(videos) {
  const restaurantNames = new Set();
  
  videos.forEach(video => {
    const title = video.snippet.title;
    console.log(`🔍 분석 중: "${title}"`);
    
    // 기본적인 식당명 + 메뉴 조합 패턴
    const pattern = /([가-힣]{2,8}(?:김밥|국수|국밥|갈비|치킨|식당|카페|베이커리|돈까스))/g;
    const matches = title.match(pattern) || [];
    
    matches.forEach(match => {
      const extracted = match.trim();
      console.log(`   🔍 패턴 매치: "${match}" → 추출: "${extracted}" → 검증: ${isExactRestaurantName(extracted)}`);
      
      if (isExactRestaurantName(extracted)) {
        restaurantNames.add(extracted);
        console.log(`   ✅ 추출: ${extracted}`);
      }
    });
  });
  
  return Array.from(restaurantNames);
}

async function testExtractionWithSungsan() {
  try {
    const response = await axios.get('https://www.googleapis.com/youtube/v3/search', {
      params: {
        part: 'snippet',
        q: '성산 맛집',
        type: 'video',
        maxResults: 3,
        key: youtubeApiKey
      }
    });
    
    console.log('🔍 YouTube 검색: "성산 맛집"');
    console.log(`   ✅ ${response.data.items.length}개 영상 찾음`);
    
    const extractedNames = extractRestaurantNames(response.data.items);
    
    console.log(`\n📊 최종 추출된 식당명: ${extractedNames.length}개`);
    if (extractedNames.length > 0) {
      console.log('추출된 식당명들:', extractedNames);
    } else {
      console.log('⚠️ 추출된 식당명이 없습니다.');
    }
    
  } catch (error) {
    console.error('❌ 검색 실패:', error.message);
  }
}

testExtractionWithSungsan();