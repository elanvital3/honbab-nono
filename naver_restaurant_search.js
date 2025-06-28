const axios = require('axios');
const fs = require('fs');
require('dotenv').config({ path: '.env.naver' });

// 네이버 API 설정
const NAVER_CLIENT_ID = process.env.NAVER_CLIENT_ID;
const NAVER_CLIENT_SECRET = process.env.NAVER_CLIENT_SECRET;

// 검색할 지역들 (서울 주요 지역)
const SEARCH_AREAS = [
  '강남역 맛집',
  '홍대 맛집', 
  '명동 맛집',
  '이태원 맛집',
  '종로 맛집',
  '신촌 맛집',
  '압구정 맛집',
  '서울역 맛집',
  '건대 맛집',
  '성수 맛집'
];

// 음식 카테고리
const FOOD_CATEGORIES = [
  '한식',
  '중식',
  '일식', 
  '양식',
  '치킨',
  '피자',
  '카페',
  '분식',
  '바베큐',
  '해산물'
];

class NaverRestaurantCollector {
  constructor() {
    this.restaurants = [];
    this.duplicateCheck = new Set();
  }

  // 네이버 검색 API 호출
  async searchRestaurants(query, start = 1, display = 20) {
    try {
      const response = await axios.get('https://openapi.naver.com/v1/search/local.json', {
        params: {
          query: query,
          display: display,
          start: start,
          sort: 'random'
        },
        headers: {
          'X-Naver-Client-Id': NAVER_CLIENT_ID,
          'X-Naver-Client-Secret': NAVER_CLIENT_SECRET
        }
      });

      return response.data;
    } catch (error) {
      console.error(`검색 실패 - ${query}:`, error.message);
      return null;
    }
  }

  // HTML 태그 제거
  removeHtmlTags(text) {
    return text.replace(/<[^>]*>/g, '');
  }

  // 중복 체크 (전화번호 기준)
  isDuplicate(telephone) {
    if (!telephone || this.duplicateCheck.has(telephone)) {
      return true;
    }
    this.duplicateCheck.add(telephone);
    return false;
  }

  // 식당 데이터 파싱 및 정제
  parseRestaurantData(item) {
    // 음식점이나 카페가 아닌 경우 제외
    if (!item.category.includes('음식점') && !item.category.includes('카페')) {
      return null;
    }

    const restaurant = {
      name: this.removeHtmlTags(item.title),
      category: item.category,
      description: this.removeHtmlTags(item.description || ''),
      telephone: item.telephone || '',
      address: item.address,
      roadAddress: item.roadAddress,
      mapx: parseInt(item.mapx) / 10000000, // 네이버는 좌표를 10^7배 해서 제공
      mapy: parseInt(item.mapy) / 10000000,
      link: item.link,
      source: 'naver',
      createdAt: new Date().toISOString()
    };

    // 중복 체크
    if (this.isDuplicate(restaurant.telephone)) {
      return null;
    }

    return restaurant;
  }

  // 전체 데이터 수집
  async collectAllRestaurants() {
    console.log('🍽️ 네이버 식당 데이터 수집 시작...');
    
    let totalCollected = 0;
    
    for (const area of SEARCH_AREAS) {
      console.log(`\n📍 ${area} 검색 중...`);
      
      // 기본 지역 검색
      await this.collectFromQuery(area);
      
      // 카테고리별 검색
      for (const category of FOOD_CATEGORIES) {
        const query = `${area} ${category}`;
        await this.collectFromQuery(query);
        
        // API 호출 제한 고려 (0.1초 대기)
        await this.sleep(100);
      }
      
      console.log(`✅ ${area} 완료 - 현재 총 ${this.restaurants.length}개`);
    }
    
    console.log(`\n🎉 수집 완료! 총 ${this.restaurants.length}개 식당 데이터 수집`);
    return this.restaurants;
  }

  // 특정 쿼리로 데이터 수집
  async collectFromQuery(query, maxPages = 2) {
    for (let page = 1; page <= maxPages; page++) {
      const start = (page - 1) * 20 + 1;
      const result = await this.searchRestaurants(query, start, 20);
      
      if (!result || !result.items || result.items.length === 0) {
        break;
      }
      
      for (const item of result.items) {
        const restaurant = this.parseRestaurantData(item);
        if (restaurant) {
          this.restaurants.push(restaurant);
        }
      }
      
      // 마지막 페이지인 경우 중단
      if (result.items.length < 20) {
        break;
      }
    }
  }

  // 데이터를 JSON 파일로 저장
  async saveToFile(filename = 'naver_restaurants.json') {
    try {
      const data = {
        totalCount: this.restaurants.length,
        collectedAt: new Date().toISOString(),
        source: 'naver_search_api',
        restaurants: this.restaurants
      };
      
      fs.writeFileSync(filename, JSON.stringify(data, null, 2), 'utf8');
      console.log(`💾 데이터 저장 완료: ${filename}`);
      console.log(`📊 총 ${this.restaurants.length}개 식당 정보 저장`);
    } catch (error) {
      console.error('파일 저장 실패:', error);
    }
  }

  // 수집 결과 통계
  printStatistics() {
    const categories = {};
    const areas = {};
    
    this.restaurants.forEach(restaurant => {
      // 카테고리 통계
      if (categories[restaurant.category]) {
        categories[restaurant.category]++;
      } else {
        categories[restaurant.category] = 1;
      }
      
      // 지역 통계 (주소 기준)
      const area = restaurant.address.split(' ')[0];
      if (areas[area]) {
        areas[area]++;
      } else {
        areas[area] = 1;
      }
    });
    
    console.log('\n📈 수집 통계:');
    console.log('카테고리별:', categories);
    console.log('지역별:', areas);
  }

  // 대기 함수
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // 간단한 테스트 함수
  async testAPI() {
    console.log('🧪 네이버 API 테스트 중...');
    
    const result = await this.searchRestaurants('강남역 맛집', 1, 5);
    
    if (result && result.items) {
      console.log('✅ API 연결 성공!');
      console.log(`📊 검색 결과: ${result.items.length}개`);
      
      // 첫 번째 결과의 전체 데이터 구조 출력
      if (result.items.length > 0) {
        console.log('\n📋 첫 번째 결과의 전체 데이터 구조:');
        console.log(JSON.stringify(result.items[0], null, 2));
      }
      
      result.items.forEach((item, index) => {
        console.log(`${index + 1}. ${this.removeHtmlTags(item.title)} - ${item.category}`);
      });
    } else {
      console.log('❌ API 연결 실패');
    }
  }
}

// 실행 함수
async function main() {
  // API 키 확인
  if (!NAVER_CLIENT_ID || !NAVER_CLIENT_SECRET) {
    console.error('❌ 네이버 API 키가 설정되지 않았습니다!');
    console.log('.env.naver 파일을 확인해주세요.');
    return;
  }
  
  const collector = new NaverRestaurantCollector();
  
  try {
    // API 테스트 실행 (데이터 구조 확인용)
    await collector.testAPI();
    
  } catch (error) {
    console.error('수집 중 오류 발생:', error);
  }
}

// 스크립트 실행
if (require.main === module) {
  main();
}

module.exports = NaverRestaurantCollector;