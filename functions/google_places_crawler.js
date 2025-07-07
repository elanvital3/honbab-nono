/**
 * Google Places API를 사용한 안정적인 평점 수집
 * - 웹 스크래핑 대신 공식 API 사용
 * - 평점, 리뷰 수, 기본 정보 모두 제공
 */

const axios = require('axios');
const admin = require('firebase-admin');

// 환경변수에서 Google Places API 키 로드
require('dotenv').config({ path: '../flutter-app/.env' });

// Google Places API 키 (새로 발급 필요)
const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY || 'YOUR_API_KEY_HERE';

class GooglePlacesCrawler {
  constructor() {
    // Firebase Admin SDK 초기화
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
  }

  /**
   * Google Places API로 식당 검색 및 평점 정보 수집
   */
  async searchRestaurantWithRating(restaurantName, location = '서울') {
    try {
      console.log(`🔍 Google Places에서 "${restaurantName}" 검색 중...`);
      
      // 1단계: Places Text Search로 장소 찾기
      const searchUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
      const searchParams = {
        query: `${restaurantName} ${location} 맛집`,
        type: 'restaurant',
        language: 'ko',
        key: GOOGLE_PLACES_API_KEY
      };

      const searchResponse = await axios.get(searchUrl, { params: searchParams });
      const searchResults = searchResponse.data.results || [];
      
      if (searchResults.length === 0) {
        console.log(`❌ "${restaurantName}" 검색 결과 없음`);
        return null;
      }

      // 첫 번째 결과 선택
      const place = searchResults[0];
      console.log(`✅ 찾은 장소: ${place.name}`);

      // 2단계: Place Details로 상세 정보 (평점 포함) 가져오기
      const detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
      const detailsParams = {
        place_id: place.place_id,
        fields: 'name,rating,user_ratings_total,formatted_address,geometry,place_id,types,price_level',
        language: 'ko',
        key: GOOGLE_PLACES_API_KEY
      };

      const detailsResponse = await axios.get(detailsUrl, { params: detailsParams });
      const details = detailsResponse.data.result;

      if (!details) {
        console.log(`❌ "${restaurantName}" 상세 정보 없음`);
        return null;
      }

      // 평점 정보 추출
      const rating = details.rating || 0;
      const reviewCount = details.user_ratings_total || 0;
      const location_info = details.geometry?.location || {};

      console.log(`⭐ Google 평점: ${rating}/5.0 (${reviewCount}개 리뷰)`);

      return {
        name: details.name,
        address: details.formatted_address,
        latitude: location_info.lat || 0,
        longitude: location_info.lng || 0,
        googleRating: {
          score: rating,
          reviewCount: reviewCount,
          placeId: details.place_id
        },
        category: this.extractCategory(details.types),
        priceLevel: details.price_level || null
      };

    } catch (error) {
      if (error.response?.status === 403) {
        console.error('❌ Google Places API 키가 유효하지 않거나 할당량 초과');
      } else {
        console.error('❌ Google Places API 오류:', error.message);
      }
      return null;
    }
  }

  /**
   * Google Places types에서 한국어 카테고리 추출
   */
  extractCategory(types = []) {
    const categoryMap = {
      'restaurant': '음식점',
      'food': '음식점', 
      'meal_takeaway': '테이크아웃',
      'cafe': '카페',
      'bakery': '베이커리',
      'bar': '바/술집',
      'night_club': '클럽',
      'meal_delivery': '배달',
    };

    for (const type of types) {
      if (categoryMap[type]) {
        return categoryMap[type];
      }
    }
    return '음식점';
  }

  /**
   * 기존 Firestore 데이터에 Google 평점 추가
   */
  async updateExistingRestaurantsWithGoogleRatings() {
    try {
      console.log('📊 기존 맛집 데이터에 Google 평점 추가 시작...\n');
      
      const snapshot = await this.db.collection('restaurants').get();
      let updated = 0;
      let failed = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const restaurantName = data.name;
        const province = data.province;
        
        console.log(`\n🔄 [${updated + failed + 1}/${snapshot.size}] "${restaurantName}" 처리 중...`);

        try {
          // Google Places에서 평점 정보 검색
          const googleData = await this.searchRestaurantWithRating(restaurantName, province);
          
          if (googleData && googleData.googleRating.score > 0) {
            // Firestore 업데이트
            await doc.ref.update({
              rating: googleData.googleRating.score,
              reviewCount: googleData.googleRating.reviewCount,
              googlePlaceId: googleData.googleRating.placeId,
              updatedAt: admin.firestore.Timestamp.now(),
              ratingSource: 'google_places'
            });
            
            console.log(`✅ 업데이트 완료: ${googleData.googleRating.score}★ (${googleData.googleRating.reviewCount}개)`);
            updated++;
          } else {
            console.log(`❌ 평점 정보 없음`);
            failed++;
          }

          // API 호출 제한 방지 (Google Places는 QPS 제한 있음)
          await new Promise(resolve => setTimeout(resolve, 1000));

        } catch (error) {
          console.log(`❌ 처리 실패: ${error.message}`);
          failed++;
        }
      }

      console.log(`\n📈 Google 평점 업데이트 완료:`);
      console.log(`   성공: ${updated}개`);
      console.log(`   실패: ${failed}개`);
      console.log(`   전체: ${updated + failed}개`);

    } catch (error) {
      console.error('❌ 전체 업데이트 오류:', error.message);
    }
  }

  /**
   * 단일 식당 테스트
   */
  async testSingleRestaurant(name, location) {
    console.log(`🧪 단일 테스트: "${name}" in ${location}`);
    
    const result = await this.searchRestaurantWithRating(name, location);
    if (result) {
      console.log('\n📊 결과:');
      console.log(`   이름: ${result.name}`);
      console.log(`   주소: ${result.address}`);
      console.log(`   평점: ${result.googleRating.score}★`);
      console.log(`   리뷰: ${result.googleRating.reviewCount}개`);
      console.log(`   카테고리: ${result.category}`);
    } else {
      console.log('❌ 결과 없음');
    }
    
    return result;
  }
}

// 직접 실행 시 테스트
if (require.main === module) {
  async function runTest() {
    const crawler = new GooglePlacesCrawler();
    
    console.log('🔧 Google Places API 키 확인...');
    if (GOOGLE_PLACES_API_KEY === 'YOUR_API_KEY_HERE') {
      console.log('❌ Google Places API 키가 설정되지 않았습니다.');
      console.log('   1. Google Cloud Console에서 Places API 활성화');
      console.log('   2. API 키 발급');
      console.log('   3. .env 파일에 GOOGLE_PLACES_API_KEY 추가');
      return;
    }
    
    // 테스트 실행
    await crawler.testSingleRestaurant('명동교자', '서울');
  }
  
  runTest().catch(console.error);
}

module.exports = GooglePlacesCrawler;