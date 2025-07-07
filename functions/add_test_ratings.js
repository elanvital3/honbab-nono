/**
 * 기존 맛집 데이터에 임시 평점 추가
 */

const admin = require('firebase-admin');

// Firebase Admin 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

// 임시 평점 데이터 (랜덤하지만 현실적인 범위)
const testRatings = {
  // 제주도
  '바다를본돼지 제주서귀포올레시장점': { rating: 4.2, reviewCount: 87 },
  '살아있는해물뚝배기 어마장장': { rating: 4.0, reviewCount: 45 },
  '산방산해물라면오빠네': { rating: 3.8, reviewCount: 32 },
  '어린왕자감귤밭': { rating: 4.5, reviewCount: 123 },
  '이춘옥의원조고등어쌈밥': { rating: 4.3, reviewCount: 78 },
  
  // 서울
  '명동교자 본점': { rating: 4.1, reviewCount: 1247 },
  '광장시장통큰누이네육회빈대떡': { rating: 3.9, reviewCount: 234 },
  '이태원더고깃집 본점': { rating: 4.0, reviewCount: 156 },
  '강남초밥': { rating: 3.7, reviewCount: 89 },
  '홍대치킨': { rating: 4.2, reviewCount: 98 },
  
  // 부산
  '해운대활어회센터': { rating: 4.3, reviewCount: 167 },
  '광안리1등조개구이': { rating: 4.1, reviewCount: 112 },
  '부산밀면': { rating: 3.8, reviewCount: 203 },
  '본전돼지국밥': { rating: 4.4, reviewCount: 345 },
  '속시원한대구탕': { rating: 3.9, reviewCount: 67 },
  
  // 경주
  '정화한정식': { rating: 4.0, reviewCount: 56 },
  '장터밥상': { rating: 3.6, reviewCount: 34 },
  '빛꾸리': { rating: 4.2, reviewCount: 78 },
  '원조전통떡갈비': { rating: 4.1, reviewCount: 89 },
  '정록쌈밥': { rating: 3.8, reviewCount: 45 }
};

async function addTestRatings() {
  console.log('⭐ 임시 평점 데이터 추가 시작...\n');
  
  try {
    const snapshot = await db.collection('restaurants').get();
    
    let updated = 0;
    let failed = 0;
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const restaurantName = data.name;
      
      if (testRatings[restaurantName]) {
        const { rating, reviewCount } = testRatings[restaurantName];
        
        try {
          await doc.ref.update({
            rating: rating,
            reviewCount: reviewCount,
            updatedAt: admin.firestore.Timestamp.now()
          });
          
          console.log(`✅ ${restaurantName} - ${rating}★ (${reviewCount}개)`);
          updated++;
        } catch (error) {
          console.log(`❌ ${restaurantName} - 업데이트 실패: ${error.message}`);
          failed++;
        }
      } else {
        console.log(`⚠️ ${restaurantName} - 매칭되는 평점 없음`);
        failed++;
      }
    }
    
    console.log('\n📊 평점 추가 결과:');
    console.log(`   성공: ${updated}개`);
    console.log(`   실패: ${failed}개`);
    console.log(`   전체: ${updated + failed}개`);
    
  } catch (error) {
    console.error('❌ 평점 추가 오류:', error.message);
  }
}

// 실행
addTestRatings();