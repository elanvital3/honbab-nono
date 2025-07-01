/**
 * 통합 식당 평점 크롤러
 * - 네이버 + 카카오 평점을 모두 수집
 * - Firebase에 통합 저장
 * - 라즈베리파이 n8n에서 호출할 메인 스크립트
 */

const NaverCrawler = require('./naver_crawler');
const KakaoCrawler = require('./kakao_crawler');
const admin = require('firebase-admin');

class RestaurantRatingCrawler {
  constructor() {
    this.naverCrawler = new NaverCrawler();
    this.kakaoCrawler = new KakaoCrawler();
    
    // Firebase Admin SDK 초기화 (한 번만)
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
  }

  /**
   * 단일 식당의 네이버 + 카카오 평점 모두 수집
   */
  async crawlRestaurantAllPlatforms(restaurantName, location = '서울시') {
    console.log(`\n🚀 "${restaurantName}" 전체 플랫폼 크롤링 시작...`);
    
    const results = {
      restaurant: restaurantName,
      location: location,
      naver: null,
      kakao: null,
      success: false
    };

    try {
      // 1. 네이버 크롤링
      console.log(`📍 네이버 크롤링 중...`);
      results.naver = await this.naverCrawler.crawlRestaurantRating(restaurantName, location);
      
      // 딜레이 (API 제한 방지)
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // 2. 카카오 크롤링
      console.log(`📍 카카오 크롤링 중...`);
      results.kakao = await this.kakaoCrawler.crawlRestaurantRating(restaurantName, location);
      
      // 3. 통합 결과 저장
      if (results.naver || results.kakao) {
        await this.mergeAndSaveRatings(results);
        results.success = true;
        console.log(`✅ "${restaurantName}" 전체 플랫폼 크롤링 성공`);
      } else {
        console.log(`❌ "${restaurantName}" 모든 플랫폼에서 결과 없음`);
      }

    } catch (error) {
      console.error(`❌ "${restaurantName}" 크롤링 오류:`, error.message);
    }

    return results;
  }

  /**
   * 네이버와 카카오 데이터를 통합하여 Firestore에 저장
   */
  async mergeAndSaveRatings(results) {
    try {
      const { naver, kakao } = results;
      
      // 기준 데이터 결정 (카카오 우선, 없으면 네이버)
      const baseData = kakao || naver;
      const restaurantId = this.generateUnifiedRestaurantId(baseData.name, baseData.address);
      
      const docRef = this.db.collection('restaurant_ratings').doc(restaurantId);
      const now = admin.firestore.Timestamp.now();
      
      // 통합 데이터 구성
      const mergedData = {
        name: baseData.name,
        address: baseData.address,
        latitude: baseData.latitude,
        longitude: baseData.longitude,
        category: baseData.category || '음식점',
        lastUpdated: now,
        deepLinks: {}
      };

      // 네이버 평점 추가
      if (naver && naver.naverRating) {
        mergedData.naverRating = {
          score: naver.naverRating.score,
          reviewCount: naver.naverRating.reviewCount,
          url: naver.naverRating.url
        };
        mergedData.deepLinks.naver = naver.naverRating.url;
      }

      // 카카오 평점 추가
      if (kakao && kakao.kakaoRating) {
        mergedData.kakaoRating = {
          score: kakao.kakaoRating.score,
          reviewCount: kakao.kakaoRating.reviewCount,
          url: kakao.kakaoRating.url
        };
        mergedData.deepLinks.kakao = kakao.deepLink || kakao.kakaoRating.url;
      }

      // 기존 문서 확인 (생성 시간 유지)
      const existingDoc = await docRef.get();
      if (!existingDoc.exists) {
        mergedData.createdAt = now;
      }

      await docRef.set(mergedData, { merge: true });
      console.log(`💾 통합 데이터 Firestore 저장 완료: ${restaurantId}`);
      
      return restaurantId;
    } catch (error) {
      console.error('❌ 통합 데이터 저장 오류:', error.message);
      return null;
    }
  }

  /**
   * 여러 식당을 배치로 크롤링
   */
  async crawlRestaurantsBatch(restaurantList, location = '서울시') {
    console.log(`🔄 ${restaurantList.length}개 식당 배치 크롤링 시작...\n`);
    
    const results = [];
    const delayBetweenRequests = 3000; // 3초 딜레이
    
    for (let i = 0; i < restaurantList.length; i++) {
      const restaurant = restaurantList[i];
      console.log(`\n[${i + 1}/${restaurantList.length}] 처리 중: ${restaurant}`);
      
      const result = await this.crawlRestaurantAllPlatforms(restaurant, location);
      results.push(result);
      
      // 마지막이 아니면 딜레이
      if (i < restaurantList.length - 1) {
        console.log(`⏳ ${delayBetweenRequests/1000}초 대기 중...`);
        await new Promise(resolve => setTimeout(resolve, delayBetweenRequests));
      }
    }
    
    console.log(`\n🎉 배치 크롤링 완료!`);
    this.printBatchSummary(results);
    
    return results;
  }

  /**
   * 배치 크롤링 결과 요약 출력
   */
  printBatchSummary(results) {
    const total = results.length;
    const successful = results.filter(r => r.success).length;
    const withNaver = results.filter(r => r.naver).length;
    const withKakao = results.filter(r => r.kakao).length;
    
    console.log('\n📊 크롤링 결과 요약:');
    console.log(`   전체: ${total}개`);
    console.log(`   성공: ${successful}개`);
    console.log(`   네이버 평점: ${withNaver}개`);
    console.log(`   카카오 평점: ${withKakao}개`);
    console.log(`   성공률: ${((successful/total)*100).toFixed(1)}%`);
  }

  /**
   * 통합 식당 ID 생성
   */
  generateUnifiedRestaurantId(name, address) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    const cleanAddress = address.replace(/[^가-힣a-zA-Z0-9]/g, '').substring(0, 10);
    return `unified_${cleanName}_${cleanAddress}`.toLowerCase();
  }

  /**
   * Firestore에서 기존 평점 데이터 조회
   */
  async getRatingsFromFirestore(limit = 10) {
    try {
      const snapshot = await this.db
        .collection('restaurant_ratings')
        .orderBy('lastUpdated', 'desc')
        .limit(limit)
        .get();
      
      const ratings = [];
      snapshot.forEach(doc => {
        ratings.push({
          id: doc.id,
          ...doc.data()
        });
      });
      
      console.log(`📖 Firestore에서 ${ratings.length}개 평점 데이터 조회`);
      return ratings;
    } catch (error) {
      console.error('❌ Firestore 조회 오류:', error.message);
      return [];
    }
  }
}

// 스크립트 직접 실행 시 테스트
if (require.main === module) {
  const crawler = new RestaurantRatingCrawler();
  
  // 테스트할 식당 목록 (인기 체인점 위주)
  const testRestaurants = [
    '은희네해장국',
    '맘스터치',
    '스타벅스',
    '김밥천국',
    '피자헛',
    '맥도날드',
    '롯데리아',
    '이디야커피'
  ];

  async function runTest() {
    console.log('🚀 통합 식당 평점 크롤러 테스트 시작...\n');
    
    // 배치 크롤링 실행
    const results = await crawler.crawlRestaurantsBatch(testRestaurants);
    
    // 저장된 데이터 확인
    console.log('\n📋 저장된 평점 데이터 확인:');
    const savedRatings = await crawler.getRatingsFromFirestore(10);
    
    savedRatings.forEach((rating, index) => {
      console.log(`\n${index + 1}. ${rating.name}`);
      console.log(`   주소: ${rating.address}`);
      if (rating.naverRating) {
        console.log(`   네이버: ${rating.naverRating.score}★ (${rating.naverRating.reviewCount}개)`);
      }
      if (rating.kakaoRating) {
        console.log(`   카카오: ${rating.kakaoRating.score}★ (${rating.kakaoRating.reviewCount}개)`);
      }
    });
    
    console.log('\n🎉 통합 크롤러 테스트 완료!');
  }

  runTest().catch(console.error);
}

module.exports = RestaurantRatingCrawler;