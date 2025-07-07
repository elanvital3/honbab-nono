/**
 * Google Places API를 사용해 기존 맛집 데이터에 실제 평점과 리뷰 추가
 * - 유튜브 크롤링으로 검증된 맛집들만 대상
 * - 카카오 좌표 기반으로 Google Place 찾기
 * - 실제 평점, 리뷰, 사진 데이터 추가
 */

const axios = require('axios');
const admin = require('firebase-admin');

// 환경변수 로드
require('dotenv').config({ path: '../flutter-app/.env' });

class GooglePlacesEnhancer {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    
    // API 키
    this.googleApiKey = process.env.GOOGLE_PLACES_API_KEY;
    
    if (!this.googleApiKey) {
      throw new Error('Google Places API 키가 설정되지 않았습니다. .env 파일에 GOOGLE_PLACES_API_KEY를 추가하세요.');
    }
  }

  /**
   * Firestore에서 모든 맛집 데이터 가져오기
   */
  async getAllRestaurants() {
    try {
      const snapshot = await this.db.collection('restaurants').get();
      const restaurants = [];
      
      snapshot.forEach(doc => {
        restaurants.push({
          id: doc.id,
          ...doc.data()
        });
      });
      
      console.log(`📊 총 ${restaurants.length}개 맛집 발견`);
      return restaurants;
    } catch (error) {
      console.error('❌ Firestore 데이터 로드 실패:', error.message);
      return [];
    }
  }

  /**
   * 좌표와 이름 기반으로 Google Place ID 찾기
   */
  async findGooglePlaceId(restaurant) {
    try {
      // 1차: Nearby Search로 좌표 기반 검색
      const nearbyUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
      
      const nearbyResponse = await axios.get(nearbyUrl, {
        params: {
          location: `${restaurant.latitude},${restaurant.longitude}`,
          radius: 100, // 100m 반경
          type: 'restaurant',
          key: this.googleApiKey,
          language: 'ko'
        }
      });

      const nearbyResults = nearbyResponse.data.results || [];
      
      // 이름 매칭으로 최적 후보 찾기
      const bestMatch = this.findBestNameMatch(restaurant.name, nearbyResults);
      
      if (bestMatch) {
        console.log(`   ✅ Google Place 매칭: ${bestMatch.name} (ID: ${bestMatch.place_id})`);
        return bestMatch.place_id;
      }

      // 2차: Text Search로 이름 기반 검색
      const textUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
      
      const textResponse = await axios.get(textUrl, {
        params: {
          query: `${restaurant.name} ${restaurant.address}`,
          location: `${restaurant.latitude},${restaurant.longitude}`,
          radius: 500,
          key: this.googleApiKey,
          language: 'ko'
        }
      });

      const textResults = textResponse.data.results || [];
      
      if (textResults.length > 0) {
        const result = textResults[0];
        console.log(`   ✅ Google Place 텍스트 매칭: ${result.name} (ID: ${result.place_id})`);
        return result.place_id;
      }

      console.log(`   ❌ Google Place 매칭 실패: ${restaurant.name}`);
      return null;

    } catch (error) {
      console.error(`❌ Google Place 검색 오류 (${restaurant.name}):`, error.message);
      return null;
    }
  }

  /**
   * 이름 유사도 기반 최적 매칭 찾기
   */
  findBestNameMatch(targetName, candidates) {
    if (!candidates || candidates.length === 0) return null;

    const targetClean = this.cleanRestaurantName(targetName);
    let bestMatch = null;
    let bestScore = 0;

    for (const candidate of candidates) {
      const candidateClean = this.cleanRestaurantName(candidate.name);
      const score = this.calculateNameSimilarity(targetClean, candidateClean);
      
      if (score > bestScore && score > 0.7) { // 70% 이상 유사도
        bestScore = score;
        bestMatch = candidate;
      }
    }

    return bestMatch;
  }

  /**
   * 식당명 정리 (비교용)
   */
  cleanRestaurantName(name) {
    return name
      .replace(/\s+/g, '') // 공백 제거
      .replace(/[()[\]{}]/g, '') // 괄호 제거
      .replace(/점$|지점$|본점$|분점$/, '') // 점포 표시 제거
      .toLowerCase();
  }

  /**
   * 문자열 유사도 계산 (Jaccard 유사도)
   */
  calculateNameSimilarity(str1, str2) {
    const set1 = new Set(str1.split(''));
    const set2 = new Set(str2.split(''));
    
    const intersection = new Set([...set1].filter(x => set2.has(x)));
    const union = new Set([...set1, ...set2]);
    
    return intersection.size / union.size;
  }

  /**
   * Google Place Details로 상세 정보 가져오기
   */
  async getPlaceDetails(placeId) {
    try {
      const detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
      
      const response = await axios.get(detailsUrl, {
        params: {
          place_id: placeId,
          fields: 'rating,user_ratings_total,reviews,photos,price_level,opening_hours,formatted_phone_number',
          reviews_sort: 'newest',
          key: this.googleApiKey,
          language: 'ko'
        }
      });

      const result = response.data.result;
      
      if (!result) {
        console.log(`   ❌ Place Details 없음: ${placeId}`);
        return null;
      }

      // 리뷰 정리
      const reviews = (result.reviews || []).slice(0, 5).map(review => ({
        author_name: review.author_name,
        rating: review.rating,
        text: review.text,
        time: review.time,
        profile_photo_url: review.profile_photo_url
      }));

      // 사진 URL 정리
      const photos = (result.photos || []).slice(0, 5).map(photo => 
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photo_reference}&key=${this.googleApiKey}`
      );

      const googleData = {
        rating: result.rating || null,
        userRatingsTotal: result.user_ratings_total || 0,
        reviews: reviews,
        photos: photos,
        priceLevel: result.price_level || null,
        isOpen: result.opening_hours?.open_now || null,
        phoneNumber: result.formatted_phone_number || null,
        updatedAt: admin.firestore.Timestamp.now()
      };

      console.log(`   ✅ Google 데이터: 평점 ${googleData.rating}/5 (${googleData.userRatingsTotal}개 리뷰)`);
      return googleData;

    } catch (error) {
      console.error(`❌ Place Details 오류 (${placeId}):`, error.message);
      return null;
    }
  }

  /**
   * 단일 맛집 처리
   */
  async enhanceRestaurant(restaurant) {
    console.log(`\n🔍 "${restaurant.name}" 처리중...`);
    
    // 이미 Google 데이터가 있으면 스킵
    if (restaurant.googlePlaces && restaurant.googlePlaces.rating) {
      console.log(`   ⏭️ 이미 Google 데이터 존재 (평점: ${restaurant.googlePlaces.rating})`);
      return false;
    }

    // 1. Google Place ID 찾기
    const placeId = await this.findGooglePlaceId(restaurant);
    if (!placeId) {
      return false;
    }

    // 지연 (API 할당량 보호)
    await new Promise(resolve => setTimeout(resolve, 1000));

    // 2. Place Details 가져오기
    const googleData = await this.getPlaceDetails(placeId);
    if (!googleData) {
      return false;
    }

    // 3. Firestore 업데이트
    try {
      await this.db.collection('restaurants').doc(restaurant.id).update({
        googlePlaces: {
          placeId: placeId,
          ...googleData
        }
      });

      console.log(`   💾 Firestore 업데이트 완료`);
      return true;
    } catch (error) {
      console.error(`   ❌ Firestore 업데이트 실패:`, error.message);
      return false;
    }
  }

  /**
   * 전체 맛집 데이터 강화
   */
  async enhanceAllRestaurants() {
    console.log('🚀 Google Places API로 맛집 데이터 강화 시작!\n');
    console.log('📋 작업 내용:');
    console.log('   - 기존 유튜브 검증 맛집들에 Google 평점/리뷰 추가');
    console.log('   - 카카오 좌표 기반 Google Place 매칭');
    console.log('   - 실제 사용자 리뷰 및 사진 수집\n');

    const restaurants = await this.getAllRestaurants();
    if (restaurants.length === 0) {
      console.log('❌ 처리할 맛집 데이터가 없습니다.');
      return;
    }

    let successCount = 0;
    let failCount = 0;

    for (const restaurant of restaurants) {
      const success = await this.enhanceRestaurant(restaurant);
      
      if (success) {
        successCount++;
      } else {
        failCount++;
      }

      // API 할당량 보호를 위한 지연
      await new Promise(resolve => setTimeout(resolve, 1500));
    }

    console.log(`\n🎉 Google Places 데이터 강화 완료!`);
    console.log(`   ✅ 성공: ${successCount}개`);
    console.log(`   ❌ 실패: ${failCount}개`);
    console.log(`   📊 성공률: ${Math.round(successCount / restaurants.length * 100)}%`);
  }
}

// 직접 실행
if (require.main === module) {
  async function run() {
    try {
      const enhancer = new GooglePlacesEnhancer();
      await enhancer.enhanceAllRestaurants();
    } catch (error) {
      console.error('❌ Google Places 강화 실패:', error.message);
      process.exit(1);
    }
  }
  
  run();
}

module.exports = GooglePlacesEnhancer;