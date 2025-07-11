const admin = require('firebase-admin');

// Firebase 초기화 (Application Default Credentials 사용)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

/**
 * 서울 지역 식당 데이터만 삭제
 */
async function deleteSeoulRestaurants() {
  try {
    console.log('🗑️ 서울 지역 식당 데이터 삭제 시작...');
    
    // 서울 지역 식당 조회
    const seoulQuery = db.collection('restaurants').where('region', '==', '서울');
    const seoulSnapshot = await seoulQuery.get();
    
    if (seoulSnapshot.empty) {
      console.log('✅ 삭제할 서울 지역 식당이 없습니다.');
      return;
    }
    
    console.log(`📊 발견된 서울 지역 식당: ${seoulSnapshot.size}개`);
    
    // 배치 삭제 (최대 500개씩)
    const batch = db.batch();
    let deleteCount = 0;
    
    seoulSnapshot.forEach(doc => {
      console.log(`   - 삭제 예정: ${doc.data().name} (${doc.data().address})`);
      batch.delete(doc.ref);
      deleteCount++;
    });
    
    // 배치 실행
    await batch.commit();
    
    console.log(`✅ 서울 지역 식당 ${deleteCount}개 삭제 완료!`);
    console.log('🔄 이제 크롤러를 실행하여 서울 데이터를 새로 수집할 수 있습니다.');
    
  } catch (error) {
    console.error('❌ 서울 데이터 삭제 실패:', error);
    throw error;
  }
}

/**
 * 제주도 데이터 확인 (삭제하지 않음)
 */
async function checkJejuData() {
  try {
    const jejuQuery = db.collection('restaurants').where('region', '==', '제주도');
    const jejuSnapshot = await jejuQuery.get();
    
    console.log(`📋 제주도 데이터 현황: ${jejuSnapshot.size}개 (보존됨)`);
    
    if (jejuSnapshot.size > 0) {
      console.log('   제주도 식당 예시:');
      jejuSnapshot.docs.slice(0, 3).forEach(doc => {
        const data = doc.data();
        console.log(`   - ${data.name} (${data.address})`);
      });
    }
    
  } catch (error) {
    console.error('❌ 제주도 데이터 확인 실패:', error);
  }
}

// 실행
async function main() {
  try {
    console.log('🔍 제주도 데이터 확인 중...');
    await checkJejuData();
    
    console.log('\n🗑️ 서울 데이터 삭제 시작...');
    await deleteSeoulRestaurants();
    
    console.log('\n✅ 작업 완료! 제주도는 보존, 서울은 삭제됨');
    
  } catch (error) {
    console.error('❌ 작업 실패:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { deleteSeoulRestaurants, checkJejuData };