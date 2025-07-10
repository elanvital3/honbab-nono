/**
 * 🔄 Restaurant 컬렉션 백업 스크립트
 * 현재 상태: 제주도 109개, 서울/부산 크롤링 완료했지만 province 누락으로 검색 안됨
 */

const admin = require('firebase-admin');
const fs = require('fs');

// Firebase 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

async function backupRestaurants() {
  try {
    console.log('🔄 Restaurant 컬렉션 백업 시작...');
    
    // 현재 시간으로 파일명 생성
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const backupFileName = `restaurants_backup_${timestamp}.json`;
    
    // 전체 restaurant 컬렉션 조회
    const snapshot = await db.collection('restaurants').get();
    console.log(`📊 총 ${snapshot.size}개 식당 데이터 백업 중...`);
    
    const backupData = {
      timestamp: new Date().toISOString(),
      totalCount: snapshot.size,
      restaurants: []
    };
    
    // 각 문서를 배열에 추가
    snapshot.docs.forEach(doc => {
      backupData.restaurants.push({
        id: doc.id,
        data: doc.data()
      });
    });
    
    // 지역별 통계
    const stats = {
      제주특별자치도: 0,
      서울구별: {},
      부산구별: {},
      기타: 0
    };
    
    backupData.restaurants.forEach(item => {
      const data = item.data;
      if (data.province === '제주특별자치도') {
        stats.제주특별자치도++;
      } else if (data.city && ['강남구', '강동구', '동대문구', '마포구', '서초구', '용산구', '종로구', '영등포구', '중구'].includes(data.city)) {
        stats.서울구별[data.city] = (stats.서울구별[data.city] || 0) + 1;
      } else if (data.city && ['기장군', '부산진구', '사상구', '수영구', '연제구', '영도구', '해운대구'].includes(data.city)) {
        stats.부산구별[data.city] = (stats.부산구별[data.city] || 0) + 1;
      } else {
        stats.기타++;
      }
    });
    
    // 파일로 저장
    fs.writeFileSync(backupFileName, JSON.stringify(backupData, null, 2));
    
    console.log(`✅ 백업 완료: ${backupFileName}`);
    console.log('\n📊 백업 통계:');
    console.log(`   제주도: ${stats.제주특별자치도}개`);
    console.log(`   서울 구별:`);
    Object.entries(stats.서울구별).forEach(([city, count]) => {
      console.log(`     ${city}: ${count}개`);
    });
    console.log(`   부산 구별:`);
    Object.entries(stats.부산구별).forEach(([city, count]) => {
      console.log(`     ${city}: ${count}개`);
    });
    console.log(`   기타: ${stats.기타}개`);
    
    const 서울총합 = Object.values(stats.서울구별).reduce((a, b) => a + b, 0);
    const 부산총합 = Object.values(stats.부산구별).reduce((a, b) => a + b, 0);
    
    console.log(`\n🎯 총합: 제주 ${stats.제주특별자치도} + 서울 ${서울총합} + 부산 ${부산총합} = ${stats.제주특별자치도 + 서울총합 + 부산총합}개`);
    
    return backupFileName;
    
  } catch (error) {
    console.error('❌ 백업 실패:', error);
    throw error;
  }
}

backupRestaurants().then((fileName) => {
  console.log(`\n🎉 백업 성공: ${fileName}`);
  console.log('🔄 이제 안전하게 크롤링을 다시 실행할 수 있습니다.');
  process.exit(0);
}).catch(error => {
  console.error('💥 백업 에러:', error);
  process.exit(1);
});