/**
 * 🧪 Google Places API 간단 테스트
 * 크롤러에서 Google Places 상세 정보를 못 가져오는 문제 디버깅
 */

const axios = require('axios');
require('dotenv').config({ path: '../flutter-app/.env' });

class GooglePlacesTest {
  constructor() {
    this.googleApiKeys = [
      process.env.GOOGLE_PLACES_API_KEY,
      process.env.GOOGLE_PLACES_API_KEY_2,
      process.env.GOOGLE_PLACES_API_KEY_3
    ].filter(key => key);
    
    this.currentKeyIndex = 0;
    this.googleApiKey = this.googleApiKeys[0];
    
    console.log(`🔑 Google Places API 키 ${this.googleApiKeys.length}개 로드됨`);
    if (this.googleApiKey) {
      console.log(`🔑 현재 사용 중인 키: ${this.googleApiKey.substring(0, 10)}...`);
    } else {
      console.log('❌ Google Places API 키가 없습니다!');
    }
  }

  /**
   * 1단계: API 키 기본 테스트
   */
  async testApiKey() {
    console.log('\n🧪 === API 키 기본 테스트 ===');
    
    try {
      const response = await axios.get('https://maps.googleapis.com/maps/api/place/textsearch/json', {
        params: {
          query: '서울 맛집',
          key: this.googleApiKey,
          language: 'ko'
        },
        timeout: 10000
      });

      console.log(`✅ API 응답 상태: ${response.status}`);
      console.log(`📊 검색 결과: ${response.data.results?.length || 0}개`);
      console.log(`📄 API 상태: ${response.data.status}`);
      
      if (response.data.results && response.data.results.length > 0) {
        const firstPlace = response.data.results[0];
        console.log(`🍽️ 첫 번째 식당: ${firstPlace.name}`);
        console.log(`📍 주소: ${firstPlace.formatted_address}`);
        console.log(`⭐ 평점: ${firstPlace.rating || 'N/A'}`);
        console.log(`📸 사진 수: ${firstPlace.photos?.length || 0}개`);
        
        return firstPlace; // 다음 테스트용
      }
      
      return null;
    } catch (error) {
      console.log(`❌ API 키 테스트 실패: ${error.message}`);
      if (error.response) {
        console.log(`❌ 응답 상태: ${error.response.status}`);
        console.log(`❌ 응답 데이터:`, error.response.data);
      }
      return null;
    }
  }

  /**
   * 2단계: Place Details API 테스트
   */
  async testPlaceDetails(place) {
    if (!place || !place.place_id) {
      console.log('❌ 테스트할 장소가 없습니다.');
      return null;
    }

    console.log('\n🧪 === Place Details API 테스트 ===');
    console.log(`🎯 테스트 대상: ${place.name} (${place.place_id})`);
    
    try {
      console.log(`🔍 요청 파라미터:`);
      console.log(`   place_id: ${place.place_id}`);
      console.log(`   key: ${this.googleApiKey.substring(0, 10)}...`);
      
      const response = await axios.get('https://maps.googleapis.com/maps/api/place/details/json', {
        params: {
          place_id: place.place_id,
          fields: 'place_id,name,rating,user_ratings_total,photos,opening_hours,business_status,reviews,formatted_phone_number,website,price_level',
          key: this.googleApiKey,
          language: 'ko'
        },
        timeout: 15000
      });

      console.log(`✅ Details API 응답 상태: ${response.status}`);
      console.log(`📄 API 상태: ${response.data.status}`);
      
      if (response.data.status !== 'OK') {
        console.log(`❌ API 에러 세부사항:`, response.data);
      }
      
      const details = response.data.result;
      if (details) {
        console.log(`🍽️ 식당명: ${details.name}`);
        console.log(`⭐ 평점: ${details.rating || 'N/A'}`);
        console.log(`📝 리뷰 수: ${details.user_ratings_total || 'N/A'}`);
        console.log(`📸 사진 수: ${details.photos?.length || 0}개`);
        console.log(`🕒 영업 상태: ${details.business_status || 'N/A'}`);
        console.log(`📞 전화번호: ${details.formatted_phone_number || 'N/A'}`);
        console.log(`💰 가격대: ${details.price_level || 'N/A'}`);
        
        // 사진 URL 생성 테스트
        if (details.photos && details.photos.length > 0) {
          console.log('\n📸 사진 URL 생성 테스트:');
          for (let i = 0; i < Math.min(3, details.photos.length); i++) {
            const photo = details.photos[i];
            if (photo.photo_reference) {
              const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${photo.photo_reference}&key=${this.googleApiKey}`;
              console.log(`   ${i + 1}. ${photoUrl}`);
            }
          }
        }
        
        return details;
      } else {
        console.log('❌ Details 결과가 없습니다.');
        return null;
      }
      
    } catch (error) {
      console.log(`❌ Place Details 테스트 실패: ${error.message}`);
      if (error.response) {
        console.log(`❌ 응답 상태: ${error.response.status}`);
        console.log(`❌ 응답 데이터:`, error.response.data);
      }
      return null;
    }
  }

  /**
   * 3단계: 크롤러와 동일한 방식으로 테스트
   */
  async testCrawlerMethod() {
    console.log('\n🧪 === 크롤러 방식 테스트 ===');
    
    // 실제 서울 맛집 정보 (카카오 API 결과 시뮬레이션)
    const testKakaoPlace = {
      place_name: '명동교자',
      x: '126.9846632', // 경도
      y: '37.5637117'   // 위도
    };
    
    console.log(`🎯 테스트 대상: ${testKakaoPlace.place_name}`);
    console.log(`📍 좌표: ${testKakaoPlace.y}, ${testKakaoPlace.x}`);
    
    try {
      const lat = parseFloat(testKakaoPlace.y);
      const lng = parseFloat(testKakaoPlace.x);

      // 1. Nearby Search로 장소 찾기
      console.log('\n1️⃣ Nearby Search 실행...');
      const searchResponse = await axios.get('https://maps.googleapis.com/maps/api/place/nearbysearch/json', {
        params: {
          location: `${lat},${lng}`,
          radius: 50,
          name: testKakaoPlace.place_name,
          type: 'restaurant',
          key: this.googleApiKey,
          language: 'ko'
        },
        timeout: 10000
      });

      console.log(`✅ Nearby Search 응답: ${searchResponse.status}`);
      console.log(`📊 찾은 장소 수: ${searchResponse.data.results?.length || 0}개`);
      
      if (!searchResponse.data.results || searchResponse.data.results.length === 0) {
        console.log('❌ Nearby Search에서 장소를 찾지 못했습니다.');
        return null;
      }

      const googlePlace = searchResponse.data.results[0];
      console.log(`🍽️ 매칭된 장소: ${googlePlace.name}`);
      console.log(`📍 Google Place ID: ${googlePlace.place_id}`);

      // 2. Place Details로 상세 정보 가져오기
      console.log('\n2️⃣ Place Details 실행...');
      console.log(`🔍 Place Details 요청:`);
      console.log(`   place_id: ${googlePlace.place_id}`);
      console.log(`   key: ${this.googleApiKey.substring(0, 10)}...`);
      
      const detailsResponse = await axios.get('https://maps.googleapis.com/maps/api/place/details/json', {
        params: {
          place_id: googlePlace.place_id,
          fields: 'place_id,name,rating,user_ratings_total,photos,opening_hours,business_status,reviews,formatted_phone_number,website,price_level',
          key: this.googleApiKey,
          language: 'ko'
        },
        timeout: 15000
      });
      
      console.log(`📊 Details 응답 상태: ${detailsResponse.status}`);
      console.log(`📄 Details API 상태: ${detailsResponse.data.status}`);
      
      if (detailsResponse.data.status !== 'OK') {
        console.log(`❌ Details API 에러:`, detailsResponse.data);
      }

      const details = detailsResponse.data.result;
      if (details) {
        console.log('\n📊 === 상세 정보 ===');
        console.log(`🍽️ 식당명: ${details.name}`);
        console.log(`⭐ 평점: ${details.rating || 'N/A'}`);
        console.log(`📝 리뷰 수: ${details.user_ratings_total || 'N/A'}`);
        console.log(`📸 사진 수: ${details.photos?.length || 0}개`);
        console.log(`📞 전화번호: ${details.formatted_phone_number || 'N/A'}`);
        console.log(`💰 가격대: ${details.price_level || 'N/A'}`);
        
        // 사진 URL 생성
        const photoUrls = [];
        if (details.photos && details.photos.length > 0) {
          console.log('\n📸 사진 URL 생성:');
          for (const photo of details.photos.slice(0, 5)) {
            if (photo.photo_reference) {
              const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${photo.photo_reference}&key=${this.googleApiKey}`;
              photoUrls.push(photoUrl);
              console.log(`   ✅ ${photoUrl}`);
            }
          }
        }
        
        console.log(`\n🎉 크롤러 방식 테스트 성공! 사진 ${photoUrls.length}개 생성됨`);
        return {
          placeId: details.place_id,
          rating: details.rating,
          userRatingsTotal: details.user_ratings_total,
          photos: photoUrls,
          phoneNumber: details.formatted_phone_number,
          website: details.website,
          priceLevel: details.price_level
        };
        
      } else {
        console.log('❌ Place Details 결과가 없습니다.');
        return null;
      }
      
    } catch (error) {
      console.log(`❌ 크롤러 방식 테스트 실패: ${error.message}`);
      if (error.response) {
        console.log(`❌ 응답 상태: ${error.response.status}`);
        console.log(`❌ 응답 데이터:`, error.response.data);
      }
      return null;
    }
  }

  /**
   * 전체 테스트 실행
   */
  async runAllTests() {
    console.log('🧪 === Google Places API 종합 테스트 시작 ===\n');
    
    if (!this.googleApiKey) {
      console.log('❌ API 키가 설정되지 않았습니다. .env 파일을 확인하세요.');
      return;
    }

    // 1단계: API 키 기본 테스트
    const basicTestResult = await this.testApiKey();
    
    // 2단계: Place Details 테스트 (기본 테스트 결과 활용)
    if (basicTestResult) {
      await this.testPlaceDetails(basicTestResult);
    }
    
    // 3단계: 크롤러와 동일한 방식 테스트
    await this.testCrawlerMethod();
    
    console.log('\n🧪 === 모든 테스트 완료 ===');
  }
}

// 테스트 실행
const tester = new GooglePlacesTest();
tester.runAllTests()
  .then(() => {
    console.log('\n✅ 테스트 프로세스 완료');
    process.exit(0);
  })
  .catch(error => {
    console.log(`\n❌ 테스트 프로세스 오류: ${error.message}`);
    process.exit(1);
  });