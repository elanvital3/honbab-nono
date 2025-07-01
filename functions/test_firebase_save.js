/**
 * Firebase 저장 테스트 스크립트
 * 크롤링한 데이터를 실제로 Firestore에 저장해보는 테스트
 */

const admin = require('firebase-admin');

// Firebase Admin 초기화
function initializeFirebase() {
  try {
    if (!admin.apps.length) {
      // Firebase 프로젝트 설정 사용
      admin.initializeApp({
        projectId: 'honbab-nono'
      });
      console.log('✅ Firebase Admin 초기화 성공');
    }
    return admin.firestore();
  } catch (error) {
    console.error('❌ Firebase 초기화 실패:', error.message);
    throw error;
  }
}

// 테스트 데이터 저장
async function saveTestData() {
  try {
    const db = initializeFirebase();
    
    // 크롤링으로 수집한 실제 데이터들
    const realCrawledData = [
      {
        id: 'naver_제주은희네해장국증산점_서울특별시은평구증산',
        name: '제주은희네해장국 증산점',
        address: '서울특별시 은평구 증산로 335 1층',
        latitude: 37.5864244,
        longitude: 126.9119519,
        naverRating: null, // 평점 스크래핑 필요
        category: '음식점 > 한식 > 해장국',
        source: 'naver_crawler',
        deepLinks: {
          naver: 'https://map.naver.com/search/제주은희네해장국 증산점'
        }
      },
      {
        id: 'kakao_130546853_제주은희네해장국잠실직영점',
        name: '제주은희네해장국 잠실직영점',
        address: '서울 송파구 송파대로49길 10',
        latitude: 37.507835571037,
        longitude: 127.103465183397,
        kakaoRating: {
          score: 0.0, // 실제로는 스크래핑 필요
          reviewCount: 0,
          url: 'http://place.map.kakao.com/130546853'
        },
        category: '음식점 > 한식 > 해장국 > 제주은희네해장국',
        source: 'kakao_crawler',
        deepLinks: {
          kakao: 'kakaomap://place?id=130546853'
        }
      },
      {
        id: 'kakao_794775769_맘스터치강남역점',
        name: '맘스터치 강남역점', 
        address: '서울 강남구 강남대로100길 10',
        latitude: 37.50163205822193,
        longitude: 127.02687067863272,
        kakaoRating: {
          score: 0.0,
          reviewCount: 0,
          url: 'http://place.map.kakao.com/794775769'
        },
        category: '음식점 > 패스트푸드 > 맘스터치',
        source: 'kakao_crawler',
        deepLinks: {
          kakao: 'kakaomap://place?id=794775769'
        }
      }
    ];

    console.log('🔄 실제 크롤링 데이터 Firebase 저장 시작...\n');
    
    for (const data of realCrawledData) {
      try {
        const docRef = db.collection('restaurant_ratings').doc(data.id);
        const now = admin.firestore.Timestamp.now();
        
        const saveData = {
          name: data.name,
          address: data.address,
          latitude: data.latitude,
          longitude: data.longitude,
          category: data.category,
          source: data.source,
          lastUpdated: now,
          createdAt: now,
          deepLinks: data.deepLinks || {}
        };
        
        // 네이버 평점이 있으면 추가
        if (data.naverRating) {
          saveData.naverRating = data.naverRating;
        }
        
        // 카카오 평점이 있으면 추가
        if (data.kakaoRating) {
          saveData.kakaoRating = data.kakaoRating;
        }
        
        await docRef.set(saveData, { merge: true });
        
        console.log(`✅ 저장 성공: ${data.name}`);
        console.log(`   ID: ${data.id}`);
        console.log(`   주소: ${data.address}`);
        console.log(`   좌표: ${data.latitude}, ${data.longitude}`);
        console.log(`   소스: ${data.source}\n`);
        
      } catch (docError) {
        console.error(`❌ ${data.name} 저장 실패:`, docError.message);
      }
    }
    
    console.log('🎉 실제 크롤링 데이터 저장 완료!');
    console.log('\n📋 Firebase Console에서 확인:');
    console.log('   https://console.firebase.google.com/project/honbab-nono/firestore/data');
    
  } catch (error) {
    console.error('❌ 전체 저장 실패:', error.message);
    console.log('\n💡 해결 방법:');
    console.log('   1. Firebase CLI 로그인: firebase login');
    console.log('   2. 또는 서비스 계정 키 설정');
    console.log('   3. 또는 GOOGLE_APPLICATION_CREDENTIALS 환경변수 설정');
  }
}

// 스크립트 실행
if (require.main === module) {
  saveTestData();
}

module.exports = { saveTestData };