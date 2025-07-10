const admin = require('firebase-admin');

// Firebase 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

async function deleteAllRestaurants() {
  console.log('🗑️ 모든 식당 데이터 삭제 시작...');
  
  const snapshot = await db.collection('restaurants').get();
  console.log(`📊 삭제할 문서 수: ${snapshot.size}개`);
  
  // 배치 삭제
  const batch = db.batch();
  let count = 0;
  
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
    count++;
    
    // Firestore 배치는 최대 500개까지
    if (count === 500) {
      batch.commit();
      batch = db.batch();
      count = 0;
    }
  });
  
  // 남은 것들 삭제
  if (count > 0) {
    await batch.commit();
  }
  
  console.log('✅ 모든 식당 데이터가 삭제되었습니다!');
}

deleteAllRestaurants().catch(console.error);