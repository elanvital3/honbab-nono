/**
 * 맛집 DB 구축 스크립트
 * - 기존 크롤링 시스템 활용
 * - 4개 지역별 5개씩 총 20개 맛집 수집
 * - restaurants 컬렉션에 Flutter 호환 형태로 저장
 */

const RestaurantRatingCrawler = require('./restaurant_rating_crawler');
const admin = require('firebase-admin');

class RestaurantDBBuilder {
  constructor() {
    this.crawler = new RestaurantRatingCrawler();
    
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
   * 지역별 타겟 맛집 리스트
   */
  getTargetRestaurants() {
    return {
      '제주도': [
        '돈사돈 제주공항점',
        '올레국수 제주본점', 
        '제주흑돼지 명진전문점',
        '동문시장 회센터',
        '제주도 해물라면'
      ],
      '서울': [
        '명동칼국수',
        '광장시장',
        '백반집',
        '홍대맛집',
        '강남맛집'
      ],
      '부산': [
        '자갈치시장',
        '해운대맛집',
        '광안리맛집',
        '부산돼지국밥',
        '밀면집'
      ],
      '경주': [
        '경주맛집',
        '불국사맛집',
        '첨성대맛집',
        '경주한식',
        '보문단지맛집'
      ]
    };
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
   * restaurant_ratings 데이터를 restaurants 모델로 변환
   */
  convertToRestaurantModel(ratingData, region) {
    const locationFields = this.getLocationFields(region);
    
    // 평점 계산 (네이버 우선, 없으면 카카오, 둘 다 있으면 평균)
    let avgRating = null;
    let totalReviews = 0;
    
    if (ratingData.naverRating && ratingData.kakaoRating) {
      avgRating = (ratingData.naverRating.score + ratingData.kakaoRating.score) / 2;
      totalReviews = ratingData.naverRating.reviewCount + ratingData.kakaoRating.reviewCount;
    } else if (ratingData.naverRating) {
      avgRating = ratingData.naverRating.score;
      totalReviews = ratingData.naverRating.reviewCount;
    } else if (ratingData.kakaoRating) {
      avgRating = ratingData.kakaoRating.score;
      totalReviews = ratingData.kakaoRating.reviewCount;
    }

    return {
      name: ratingData.name,
      address: ratingData.address,
      latitude: ratingData.latitude,
      longitude: ratingData.longitude,
      province: locationFields.province,
      city: locationFields.city,
      category: this.simplifyCategory(ratingData.category),
      rating: avgRating ? Number(avgRating.toFixed(1)) : null,
      reviewCount: totalReviews,
      imageUrl: null, // 나중에 추가
      phone: null, // 크롤링 데이터에 없음
      url: ratingData.naverRating?.url || ratingData.kakaoRating?.url || null,
      distance: '0', // 기본값
      isActive: true,
      updatedAt: admin.firestore.Timestamp.now(),
      // Flutter Restaurant 모델에는 없지만 유용한 추가 데이터
      tags: this.generateTags(ratingData.category),
      createdAt: admin.firestore.Timestamp.now(),
      // 원본 평점 데이터 보존
      originalRatings: {
        naver: ratingData.naverRating || null,
        kakao: ratingData.kakaoRating || null
      }
    };
  }

  /**
   * 카테고리 간소화
   */
  simplifyCategory(fullCategory) {
    if (!fullCategory) return '음식점';
    
    const parts = fullCategory.split(' > ');
    if (parts.length >= 2) {
      return parts[1]; // "음식점 > 한식 > 해장국" → "한식"
    }
    return fullCategory;
  }

  /**
   * 카테고리 기반 태그 생성
   */
  generateTags(category) {
    if (!category) return [];
    
    const tagMapping = {
      '한식': ['한식', '전통'],
      '중식': ['중식', '중국음식'],
      '일식': ['일식', '일본음식'],
      '양식': ['양식', '서양음식'],
      '패스트푸드': ['패스트푸드', '간편식'],
      '카페': ['카페', '커피'],
      '치킨': ['치킨', '튀김'],
      '피자': ['피자', '이탈리안'],
      '해장국': ['해장국', '국물'],
      '해물': ['해물', '바다']
    };

    for (const [key, tags] of Object.entries(tagMapping)) {
      if (category.includes(key)) {
        return tags;
      }
    }
    
    return ['맛집'];
  }

  /**
   * 단일 지역의 맛집 수집 및 저장
   */
  async collectAndSaveRegionRestaurants(region) {
    console.log(`\n🌍 ${region} 지역 맛집 수집 시작...`);
    
    const targetRestaurants = this.getTargetRestaurants()[region];
    const results = [];
    
    for (let i = 0; i < targetRestaurants.length; i++) {
      const restaurantName = targetRestaurants[i];
      console.log(`\n[${i + 1}/${targetRestaurants.length}] "${restaurantName}" 수집 중...`);
      
      try {
        // 기존 크롤러로 평점 데이터 수집
        const ratingResult = await this.crawler.crawlRestaurantAllPlatforms(restaurantName, region);
        
        if (ratingResult.success) {
          // 네이버 또는 카카오 데이터가 있으면 변환
          const baseData = ratingResult.kakao || ratingResult.naver;
          if (baseData) {
            const restaurantData = this.convertToRestaurantModel(baseData, region);
            
            // Firestore에 저장
            const docId = this.generateRestaurantId(restaurantData.name, restaurantData.address);
            await this.db.collection('restaurants').doc(docId).set(restaurantData);
            
            results.push({
              success: true,
              name: restaurantData.name,
              rating: restaurantData.rating,
              reviewCount: restaurantData.reviewCount
            });
            
            console.log(`✅ "${restaurantName}" 저장 완료 - ${restaurantData.rating}★ (${restaurantData.reviewCount}개)`);
          } else {
            console.log(`❌ "${restaurantName}" 데이터 없음`);
            results.push({ success: false, name: restaurantName, reason: 'no_data' });
          }
        } else {
          console.log(`❌ "${restaurantName}" 크롤링 실패`);
          results.push({ success: false, name: restaurantName, reason: 'crawl_failed' });
        }
        
        // API 제한 방지 딜레이
        if (i < targetRestaurants.length - 1) {
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
        
      } catch (error) {
        console.error(`❌ "${restaurantName}" 처리 오류:`, error.message);
        results.push({ success: false, name: restaurantName, reason: 'error' });
      }
    }
    
    return results;
  }

  /**
   * 모든 지역 맛집 수집
   */
  async buildCompleteDatabase() {
    console.log('🚀 맛집 데이터베이스 구축 시작...\n');
    
    const regions = Object.keys(this.getTargetRestaurants());
    const allResults = {};
    
    for (const region of regions) {
      allResults[region] = await this.collectAndSaveRegionRestaurants(region);
      
      // 지역 간 딜레이
      if (region !== regions[regions.length - 1]) {
        console.log(`\n⏳ 다음 지역으로 이동 전 5초 대기...`);
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
    
    this.printFinalSummary(allResults);
    return allResults;
  }

  /**
   * 최종 결과 요약
   */
  printFinalSummary(allResults) {
    console.log('\n🎉 맛집 데이터베이스 구축 완료!\n');
    console.log('📊 지역별 수집 결과:');
    
    let totalTarget = 0;
    let totalSuccess = 0;
    
    for (const [region, results] of Object.entries(allResults)) {
      const successCount = results.filter(r => r.success).length;
      totalTarget += results.length;
      totalSuccess += successCount;
      
      console.log(`\n🌍 ${region}:`);
      console.log(`   목표: ${results.length}개, 성공: ${successCount}개`);
      
      results.forEach(result => {
        if (result.success) {
          console.log(`   ✅ ${result.name} - ${result.rating}★ (${result.reviewCount}개)`);
        } else {
          console.log(`   ❌ ${result.name} (${result.reason})`);
        }
      });
    }
    
    console.log(`\n📈 전체 요약:`);
    console.log(`   목표 맛집: ${totalTarget}개`);
    console.log(`   수집 성공: ${totalSuccess}개`);
    console.log(`   성공률: ${((totalSuccess/totalTarget)*100).toFixed(1)}%`);
  }

  /**
   * 식당 ID 생성
   */
  generateRestaurantId(name, address) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    const cleanAddress = address.replace(/[^가-힣a-zA-Z0-9]/g, '').substring(0, 10);
    return `restaurant_${cleanName}_${cleanAddress}`.toLowerCase();
  }

  /**
   * Firestore restaurants 컬렉션 확인
   */
  async checkRestaurantsCollection() {
    try {
      const snapshot = await this.db.collection('restaurants').get();
      console.log(`📊 restaurants 컬렉션: ${snapshot.size}개 문서`);
      
      const byRegion = {};
      snapshot.forEach(doc => {
        const data = doc.data();
        const region = data.province || '기타';
        if (!byRegion[region]) byRegion[region] = 0;
        byRegion[region]++;
      });
      
      console.log('🌍 지역별 분포:');
      for (const [region, count] of Object.entries(byRegion)) {
        console.log(`   ${region}: ${count}개`);
      }
      
      return snapshot.size;
    } catch (error) {
      console.error('❌ Firestore 확인 오류:', error.message);
      return 0;
    }
  }
}

// 스크립트 직접 실행
if (require.main === module) {
  const builder = new RestaurantDBBuilder();
  
  async function runBuilder() {
    console.log('🍽️ 맛집 데이터베이스 빌더 시작...\n');
    
    // 기존 데이터 확인
    await builder.checkRestaurantsCollection();
    
    // 전체 데이터베이스 구축
    const results = await builder.buildCompleteDatabase();
    
    // 최종 확인
    console.log('\n📋 최종 데이터베이스 상태:');
    await builder.checkRestaurantsCollection();
    
    console.log('\n🎊 맛집 데이터베이스 구축 완료!');
  }

  runBuilder().catch(console.error);
}

module.exports = RestaurantDBBuilder;