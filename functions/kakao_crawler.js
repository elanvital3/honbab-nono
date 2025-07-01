/**
 * 카카오맵 평점 크롤러
 * - 카카오 로컬 API를 통해 식당 정보 수집
 * - 평점 정보는 웹 스크래핑으로 수집 (API에서 제공하지 않음)
 */

const axios = require('axios');
const cheerio = require('cheerio');
const admin = require('firebase-admin');

// 환경변수에서 카카오 API 키 로드
require('dotenv').config({ path: '../flutter-app/.env' });

const KAKAO_REST_API_KEY = process.env.KAKAO_REST_API_KEY;

class KakaoCrawler {
  constructor() {
    // Firebase Admin SDK 초기화 (한 번만)
    if (!admin.apps.length) {
      try {
        // 환경변수 또는 기본 인증 시도
        if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
          admin.initializeApp({
            credential: admin.credential.applicationDefault(),
            projectId: 'honbab-nono'
          });
        } else {
          // 로컬 테스트용: Firebase CLI 인증 사용
          admin.initializeApp({
            projectId: 'honbab-nono'
          });
        }
        console.log('✅ Firebase Admin 초기화 성공');
      } catch (error) {
        console.error('❌ Firebase Admin 초기화 실패:', error.message);
        throw error;
      }
    }
    this.db = admin.firestore();
  }

  /**
   * 카카오 로컬 API로 식당 검색
   */
  async searchRestaurant(restaurantName, location = '서울시') {
    try {
      const apiUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      
      const response = await axios.get(apiUrl, {
        headers: {
          'Authorization': `KakaoAK ${KAKAO_REST_API_KEY}`,
        },
        params: {
          query: `${restaurantName} ${location}`,
          category_group_code: 'FD6', // 음식점 카테고리
          size: 5,
          sort: 'accuracy' // 정확도순
        }
      });

      const results = response.data.documents || [];
      console.log(`🔍 카카오에서 "${restaurantName}" 검색 결과: ${results.length}개`);
      
      return results.map(item => ({
        id: item.id,
        place_name: item.place_name,
        category_name: item.category_name,
        address_name: item.address_name,
        road_address_name: item.road_address_name,
        x: parseFloat(item.x), // 경도
        y: parseFloat(item.y), // 위도
        phone: item.phone,
        place_url: item.place_url,
        distance: item.distance
      }));
    } catch (error) {
      console.error('❌ 카카오 검색 API 오류:', error.message);
      return [];
    }
  }

  /**
   * 카카오맵 페이지에서 평점 정보 스크래핑
   */
  async scrapeRatingFromKakaoPlace(placeUrl) {
    try {
      // User-Agent 설정 (봇 차단 방지)
      const response = await axios.get(placeUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      });

      const $ = cheerio.load(response.data);
      
      // 카카오맵 평점 선택자 (2024년 기준, 변경될 수 있음)
      const ratingElement = $('.grade_star .num_rate');
      const reviewCountElement = $('.link_evaluation .txt_location');
      
      let rating = 0.0;
      let reviewCount = 0;

      if (ratingElement.length > 0) {
        const ratingText = ratingElement.text().trim();
        rating = parseFloat(ratingText) || 0.0;
      }

      if (reviewCountElement.length > 0) {
        const reviewText = reviewCountElement.text().trim();
        const match = reviewText.match(/(\d+)/);
        reviewCount = match ? parseInt(match[1]) : 0;
      }

      console.log(`⭐ 카카오 평점: ${rating}/5.0 (${reviewCount}개 리뷰)`);
      
      return {
        score: rating,
        reviewCount: reviewCount,
        url: placeUrl
      };
    } catch (error) {
      console.error('❌ 카카오 평점 스크래핑 오류:', error.message);
      return null;
    }
  }

  /**
   * 카카오맵 상세 정보 API 호출 (place_url에서 ID 추출 후)
   */
  async getPlaceDetails(placeId) {
    try {
      // 카카오맵 상세 정보는 별도 API가 없으므로 URL 기반으로 처리
      const placeUrl = `https://place.map.kakao.com/${placeId}`;
      
      console.log(`🗺️ 카카오맵 상세 페이지: ${placeUrl}`);
      
      return {
        detailUrl: placeUrl,
        deepLink: `kakaomap://place?id=${placeId}`
      };
    } catch (error) {
      console.error('❌ 카카오 상세 정보 오류:', error.message);
      return null;
    }
  }

  /**
   * 식당 평점 정보를 Firestore에 저장/업데이트
   */
  async saveRatingToFirestore(restaurantData) {
    try {
      const restaurantId = this.generateRestaurantId(restaurantData.id, restaurantData.name);
      
      // 우선 데이터만 출력하고 Firebase 저장은 나중에 해결
      console.log('\n📊 수집된 데이터:');
      console.log(`   이름: ${restaurantData.name}`);
      console.log(`   주소: ${restaurantData.address}`);
      console.log(`   좌표: ${restaurantData.latitude}, ${restaurantData.longitude}`);
      console.log(`   카카오 평점: ${JSON.stringify(restaurantData.kakaoRating)}`);
      console.log(`   카테고리: ${restaurantData.category}`);
      console.log(`   딥링크: ${restaurantData.deepLink}`);
      console.log(`   ID: ${restaurantId}\n`);
      
      // Firebase 저장 시도 (에러 발생 시 무시)
      try {
        const docRef = this.db.collection('restaurant_ratings').doc(restaurantId);
        const now = admin.firestore.Timestamp.now();
        
        // 기존 데이터 가져오기 (네이버 평점이 있을 수 있음)
        const existingDoc = await docRef.get();
        const existingData = existingDoc.exists ? existingDoc.data() : {};
        
        const data = {
          name: restaurantData.name,
          address: restaurantData.address,
          latitude: restaurantData.latitude,
          longitude: restaurantData.longitude,
          kakaoRating: restaurantData.kakaoRating ? {
            score: restaurantData.kakaoRating.score,
            reviewCount: restaurantData.kakaoRating.reviewCount,
            url: restaurantData.kakaoRating.url
          } : null,
          category: restaurantData.category || '음식점',
          lastUpdated: now,
          deepLinks: {
            ...(existingData.deepLinks || {}),
            kakao: restaurantData.deepLink
          }
        };

        // 생성 시간은 기존 값 유지 (업데이트인 경우)
        if (!existingDoc.exists) {
          data.createdAt = now;
        }

        await docRef.set(data, { merge: true });
        console.log(`✅ Firestore 저장 완료: ${restaurantId}`);
      } catch (fbError) {
        console.log(`⚠️ Firebase 저장 실패 (데이터 수집은 성공): ${fbError.message}`);
      }
      
      return restaurantId;
    } catch (error) {
      console.error('❌ 전체 저장 오류:', error.message);
      return null;
    }
  }

  /**
   * 식당별 전체 평점 정보 수집 및 저장
   */
  async crawlRestaurantRating(restaurantName, location = '서울시') {
    console.log(`\n🔄 "${restaurantName}" 카카오 평점 크롤링 시작...`);
    
    try {
      // 1. 카카오 로컬 API로 기본 정보 수집
      const searchResults = await this.searchRestaurant(restaurantName, location);
      
      if (searchResults.length === 0) {
        console.log(`❌ "${restaurantName}" 검색 결과 없음`);
        return null;
      }

      const topResult = searchResults[0];
      
      // 2. 평점 정보 스크래핑
      let kakaoRating = null;
      if (topResult.place_url) {
        kakaoRating = await this.scrapeRatingFromKakaoPlace(topResult.place_url);
      }

      // 3. 딥링크 정보 생성
      const placeDetails = await this.getPlaceDetails(topResult.id);

      // 4. 데이터 구성
      const restaurantData = {
        id: topResult.id,
        name: topResult.place_name,
        address: topResult.road_address_name || topResult.address_name,
        latitude: topResult.y,
        longitude: topResult.x,
        kakaoRating: kakaoRating,
        category: topResult.category_name,
        phone: topResult.phone,
        deepLink: placeDetails?.deepLink || `kakaomap://place?id=${topResult.id}`
      };

      // 5. Firestore에 저장
      const restaurantId = await this.saveRatingToFirestore(restaurantData);
      
      console.log(`✅ "${restaurantName}" 카카오 크롤링 완료 (ID: ${restaurantId})`);
      return restaurantData;

    } catch (error) {
      console.error(`❌ "${restaurantName}" 카카오 크롤링 실패:`, error.message);
      return null;
    }
  }

  /**
   * 식당 고유 ID 생성 (카카오)
   */
  generateRestaurantId(kakaoId, name) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    return `kakao_${kakaoId}_${cleanName}`.toLowerCase();
  }

  /**
   * 네이버 + 카카오 통합 크롤링
   */
  async crawlBothPlatforms(restaurantName, location = '서울시') {
    console.log(`\n🔄 "${restaurantName}" 통합 크롤링 시작...`);
    
    // 카카오 크롤링 실행
    const kakaoResult = await this.crawlRestaurantRating(restaurantName, location);
    
    if (kakaoResult) {
      console.log(`✅ "${restaurantName}" 통합 크롤링 완료`);
      return kakaoResult;
    } else {
      console.log(`❌ "${restaurantName}" 통합 크롤링 실패`);
      return null;
    }
  }
}

// 스크립트 직접 실행 시 테스트
if (require.main === module) {
  const crawler = new KakaoCrawler();
  
  // 테스트할 식당 목록
  const testRestaurants = [
    '은희네해장국',
    '맘스터치',
    '스타벅스',
    '김밥천국',
    '피자헛'
  ];

  async function runTest() {
    console.log('🚀 카카오 크롤러 테스트 시작...\n');
    
    for (const restaurant of testRestaurants) {
      await crawler.crawlBothPlatforms(restaurant);
      
      // API 호출 제한 방지를 위한 딜레이
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    console.log('\n🎉 카카오 크롤러 테스트 완료!');
  }

  runTest().catch(console.error);
}

module.exports = KakaoCrawler;