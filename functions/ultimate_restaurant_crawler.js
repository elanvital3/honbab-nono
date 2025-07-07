/**
 * 궁극의 맛집 크롤러
 * - 수동 선별된 유명 맛집 리스트
 * - 카카오 로컬 API로 위치/정보 확보
 * - 카카오 이미지 검색 API로 식당 사진 확보
 * - 현실적인 평점 생성
 */

const axios = require('axios');
const admin = require('firebase-admin');

// 환경변수 로드
require('dotenv').config({ path: '../flutter-app/.env' });

class UltimateRestaurantCrawler {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    this.kakaoApiKey = process.env.KAKAO_REST_API_KEY;
  }

  /**
   * 수동 선별된 실제 유명 맛집 리스트
   */
  getCuratedRestaurants() {
    return {
      '제주도': [
        { name: '돈사돈', searchTerm: '돈사돈 제주', location: '제주시' },
        { name: '명진전복', searchTerm: '명진전복', location: '제주시' },
        { name: '올레국수', searchTerm: '올레국수', location: '제주시' },
        { name: '흑돼지거리', searchTerm: '제주 흑돼지', location: '제주시' },
        { name: '해녀의집', searchTerm: '해녀의집 제주', location: '서귀포시' }
      ],
      '서울': [
        { name: '명동교자', searchTerm: '명동교자 본점', location: '중구 명동' },
        { name: '광장시장', searchTerm: '광장시장 빈대떡', location: '종로구' },
        { name: '이태원 갈비', searchTerm: '이태원 갈비', location: '용산구' },
        { name: '강남 초밥', searchTerm: '강남 초밥', location: '강남구' },
        { name: '홍대 치킨', searchTerm: '홍대 치킨', location: '마포구' }
      ],
      '부산': [
        { name: '자갈치시장', searchTerm: '자갈치시장 횟집', location: '중구' },
        { name: '해운대 회센터', searchTerm: '해운대 회', location: '해운대구' },
        { name: '광안리 조개구이', searchTerm: '광안리 조개구이', location: '수영구' },
        { name: '부산밀면', searchTerm: '부산 밀면', location: '동구' },
        { name: '돼지국밥', searchTerm: '부산 돼지국밥', location: '부산진구' }
      ],
      '경주': [
        { name: '경주한정식', searchTerm: '경주 한정식', location: '경주시' },
        { name: '불국사 맛집', searchTerm: '불국사 맛집', location: '경주시' },
        { name: '첨성대 카페', searchTerm: '첨성대 카페', location: '경주시' },
        { name: '경주떡갈비', searchTerm: '경주 떡갈비', location: '경주시' },
        { name: '보문단지 맛집', searchTerm: '보문단지 맛집', location: '경주시' }
      ]
    };
  }

  /**
   * 카카오 로컬 API로 식당 정보 검색
   */
  async getKakaoRestaurantInfo(restaurant, region) {
    try {
      console.log(`🔍 카카오에서 "${restaurant.searchTerm}" 검색...`);
      
      const apiUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      
      const response = await axios.get(apiUrl, {
        headers: {
          'Authorization': `KakaoAK ${this.kakaoApiKey}`,
        },
        params: {
          query: `${restaurant.searchTerm} ${region}`,
          category_group_code: 'FD6',
          size: 1,
          sort: 'accuracy'
        }
      });

      const results = response.data.documents || [];
      if (results.length > 0) {
        const place = results[0];
        console.log(`   ✅ 발견: ${place.place_name}`);
        return place;
      }
      
      console.log(`   ❌ 검색 결과 없음`);
      return null;
    } catch (error) {
      console.error(`❌ 카카오 검색 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 카카오 이미지 검색 API로 식당 사진 검색
   */
  async getRestaurantImage(restaurantName) {
    try {
      console.log(`📸 이미지 검색: "${restaurantName}"`);
      
      const imageApiUrl = 'https://dapi.kakao.com/v2/search/image';
      
      // 여러 검색어로 시도
      const searchQueries = [
        `${restaurantName} 음식점`,
        `${restaurantName} 맛집`,
        `${restaurantName} 식당`,
        restaurantName
      ];
      
      for (const searchQuery of searchQueries) {
        try {
          const response = await axios.get(imageApiUrl, {
            headers: {
              'Authorization': `KakaoAK ${this.kakaoApiKey}`,
            },
            params: {
              query: searchQuery,
              sort: 'accuracy',
              size: 5
            }
          });

          const documents = response.data.documents || [];
          if (documents.length > 0) {
            const imageUrl = documents[0].thumbnail_url;
            console.log(`   ✅ 이미지 발견: ${searchQuery}`);
            return imageUrl;
          }
        } catch (searchError) {
          console.log(`   ⚠️ 검색어 "${searchQuery}" 실패`);
        }
        
        // API 제한 방지
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      
      console.log(`   ❌ 이미지 없음`);
      return null;
    } catch (error) {
      console.error(`❌ 이미지 검색 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 지역/식당 특성 기반 고품질 평점 생성
   */
  generatePremiumRating(restaurantName, region) {
    // 기본 평점 (유명 맛집이므로 높은 기준)
    let baseRating = 4.1;
    
    // 지역별 보정
    if (region === '제주도') {
      baseRating = 4.2; // 관광지 맛집
    } else if (region === '서울' && restaurantName.includes('명동')) {
      baseRating = 4.4; // 서울 대표 맛집
    } else if (region === '부산' && restaurantName.includes('자갈치')) {
      baseRating = 4.3; // 부산 명소 맛집
    } else if (region === '경주') {
      baseRating = 4.0; // 경주 전통 맛집
    }
    
    // 음식 종류별 보정
    if (restaurantName.includes('한정식') || restaurantName.includes('전복')) {
      baseRating += 0.2; // 고급 한식
    } else if (restaurantName.includes('해장국') || restaurantName.includes('국밥')) {
      baseRating += 0.1; // 전통 서민 음식
    } else if (restaurantName.includes('시장')) {
      baseRating += 0.1; // 전통 시장 맛집
    }
    
    // 약간의 랜덤 변동 (-0.1 ~ +0.2)
    const variation = Math.random() * 0.3 - 0.1;
    const finalRating = Math.max(3.9, Math.min(4.8, baseRating + variation));
    
    return Math.round(finalRating * 10) / 10;
  }

  /**
   * 평점 기반 리뷰 수 생성
   */
  generateReviewCount(rating) {
    let baseCount = 0;
    
    if (rating >= 4.5) {
      baseCount = 300 + Math.floor(Math.random() * 300); // 300-600개
    } else if (rating >= 4.2) {
      baseCount = 200 + Math.floor(Math.random() * 200); // 200-400개
    } else if (rating >= 4.0) {
      baseCount = 120 + Math.floor(Math.random() * 180); // 120-300개
    } else {
      baseCount = 80 + Math.floor(Math.random() * 120);  // 80-200개
    }
    
    return baseCount;
  }

  /**
   * 카테고리 간소화
   */
  simplifyCategory(category) {
    if (!category) return '음식점';
    
    if (category.includes('한식')) return '한식';
    if (category.includes('중식')) return '중식';
    if (category.includes('일식')) return '일식';
    if (category.includes('양식')) return '양식';
    if (category.includes('카페')) return '카페';
    if (category.includes('치킨')) return '치킨';
    if (category.includes('피자')) return '피자';
    if (category.includes('분식')) return '분식';
    if (category.includes('회')) return '회/해산물';
    if (category.includes('구이')) return '구이';
    
    return '음식점';
  }

  /**
   * 모든 지역의 엄선된 맛집 데이터 구축
   */
  async buildUltimateRestaurantDB() {
    try {
      console.log('🚀 궁극의 맛집 DB 구축 시작...\n');
      console.log('📝 특징:');
      console.log('   - 수동 선별된 지역 대표 맛집');
      console.log('   - 카카오 로컬 API 정확한 위치');
      console.log('   - 카카오 이미지 API 실제 사진');
      console.log('   - 프리미엄 평점 (3.9~4.8★)');
      console.log('   - 지역당 5개 최고 맛집\n');
      
      const curatedRestaurants = this.getCuratedRestaurants();
      let totalSaved = 0;
      
      // 기존 데이터 삭제
      console.log('🗑️ 기존 restaurants 컬렉션 데이터 삭제...');
      const existingSnapshot = await this.db.collection('restaurants').get();
      const deletePromises = existingSnapshot.docs.map(doc => doc.ref.delete());
      await Promise.all(deletePromises);
      console.log(`✅ ${existingSnapshot.size}개 기존 데이터 삭제 완료\n`);
      
      // 지역별 처리
      for (const [region, restaurants] of Object.entries(curatedRestaurants)) {
        console.log(`🌍 ${region} 지역 처리 중...`);
        
        for (let i = 0; i < restaurants.length; i++) {
          const restaurant = restaurants[i];
          console.log(`\n[${i + 1}/${restaurants.length}] "${restaurant.name}" 처리 중...`);
          
          try {
            // 1. 카카오에서 식당 정보 검색
            const kakaoPlace = await this.getKakaoRestaurantInfo(restaurant, region);
            
            if (!kakaoPlace) {
              console.log(`   ❌ 카카오에서 찾을 수 없음: ${restaurant.name}`);
              continue;
            }
            
            // 2. 이미지 검색
            const imageUrl = await this.getRestaurantImage(restaurant.name);
            
            // 3. 프리미엄 평점 생성
            const rating = this.generatePremiumRating(restaurant.name, region);
            const reviewCount = this.generateReviewCount(rating);
            
            // 4. 최종 데이터 구성
            const restaurantData = {
              name: kakaoPlace.place_name,
              address: kakaoPlace.address_name,
              roadAddress: kakaoPlace.road_address_name,
              latitude: parseFloat(kakaoPlace.y),
              longitude: parseFloat(kakaoPlace.x),
              category: this.simplifyCategory(kakaoPlace.category_name),
              rating: rating,
              reviewCount: reviewCount,
              phone: kakaoPlace.phone || null,
              url: kakaoPlace.place_url,
              imageUrl: imageUrl,
              source: 'ultimate_curated',
              isActive: true,
              isFeatured: true, // 최고 등급 맛집
              isPremium: true, // 프리미엄 맛집
              region: region,
              ...this.getLocationFields(region),
              originalSearchTerm: restaurant.searchTerm,
              placeId: kakaoPlace.id,
              createdAt: admin.firestore.Timestamp.now(),
              updatedAt: admin.firestore.Timestamp.now()
            };
            
            // 5. Firestore에 저장
            const docId = this.generateRestaurantId(restaurantData.name, restaurantData.address);
            await this.db.collection('restaurants').doc(docId).set(restaurantData);
            
            console.log(`   ✅ 저장 완료: ${restaurantData.name}`);
            console.log(`      평점: ${rating}★ (${reviewCount}개)`);
            console.log(`      이미지: ${imageUrl ? '✅' : '❌'}`);
            console.log(`      위치: ${restaurantData.latitude}, ${restaurantData.longitude}`);
            
            totalSaved++;
            
            // API 제한 방지
            await new Promise(resolve => setTimeout(resolve, 2000));
            
          } catch (error) {
            console.error(`❌ "${restaurant.name}" 처리 오류:`, error.message);
          }
        }
        
        console.log(`✅ ${region} 완료\n`);
        
        // 지역 간 딜레이
        await new Promise(resolve => setTimeout(resolve, 3000));
      }
      
      console.log(`🎉 궁극의 맛집 DB 구축 완료!`);
      console.log(`   📊 저장된 맛집: ${totalSaved}개`);
      console.log(`   🏆 수동 선별 프리미엄 맛집`);
      console.log(`   ⭐ 평점 범위: 3.9★ ~ 4.8★`);
      console.log(`   💬 리뷰 수: 80 ~ 600개`);
      console.log(`   📸 카카오 이미지 API 실제 사진`);
      console.log(`   📍 카카오 로컬 API 정확한 위치`);
      console.log(`   🔥 Flutter 앱에서 바로 사용 가능!`);
      
    } catch (error) {
      console.error('❌ 전체 구축 오류:', error.message);
    }
  }

  /**
   * 지역명을 Firebase 필드로 변환
   */
  getLocationFields(region) {
    const mapping = {
      '제주도': { province: '제주특별자치도', city: null },
      '서울': { province: '서울특별시', city: null },
      '부산': { province: '부산광역시', city: null },
      '경주': { province: '경상북도', city: '경주시' }
    };
    return mapping[region] || { province: null, city: null };
  }

  /**
   * 식당 ID 생성
   */
  generateRestaurantId(name, address) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    const cleanAddress = address.replace(/[^가-힣a-zA-Z0-9]/g, '').substring(0, 8);
    const timestamp = Date.now().toString().slice(-3);
    return `ultimate_${cleanName}_${cleanAddress}_${timestamp}`.toLowerCase();
  }
}

// 직접 실행
if (require.main === module) {
  async function runUltimateCrawler() {
    console.log('🚀 궁극의 맛집 크롤러 시작...\n');
    
    const crawler = new UltimateRestaurantCrawler();
    await crawler.buildUltimateRestaurantDB();
  }
  
  runUltimateCrawler().catch(console.error);
}

module.exports = UltimateRestaurantCrawler;