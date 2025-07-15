/**
 * 부산 음식점 데이터 삭제 스크립트
 * 
 * 사용법: node delete_busan_restaurants.js
 */

const admin = require('firebase-admin');

// Firebase 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

async function deleteBusanRestaurants() {
  try {
    console.log('🔍 부산 음식점 데이터 조회 중...');
    
    // province가 '부산광역시'인 음식점 조회
    const busanQuery = db.collection('restaurants')
      .where('province', '==', '부산광역시');
    
    const busanSnapshot = await busanQuery.get();
    
    if (busanSnapshot.empty) {
      console.log('❌ 부산 음식점 데이터가 없습니다.');
      return;
    }
    
    console.log(`📊 총 ${busanSnapshot.size}개의 부산 음식점 발견`);
    
    // 배치 삭제 (500개씩)
    const batchSize = 500;
    const docs = busanSnapshot.docs;
    
    for (let i = 0; i < docs.length; i += batchSize) {
      const batch = db.batch();
      const batchDocs = docs.slice(i, i + batchSize);
      
      batchDocs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`✅ ${i + batchDocs.length}/${docs.length} 삭제 완료`);
    }
    
    console.log('🎉 부산 음식점 데이터 삭제 완료!');
    
  } catch (error) {
    console.error('❌ 삭제 중 오류 발생:', error);
  }
}

// 실행
deleteBusanRestaurants()
  .then(() => {
    console.log('작업 완료');
    process.exit(0);
  })
  .catch(error => {
    console.error('오류:', error);
    process.exit(1);
  });