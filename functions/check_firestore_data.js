/**
 * Firestore restaurants 컬렉션 데이터 확인
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

async function checkFirestoreData() {
  console.log('📊 Firestore restaurants 컬렉션 확인...\n');
  
  try {
    const snapshot = await db.collection('restaurants').get();
    console.log('📍 총 문서 수:', snapshot.size);
    
    if (snapshot.size === 0) {
      console.log('❌ restaurants 컬렉션에 데이터가 없습니다');
      return;
    }
    
    const byRegion = {};
    const allRestaurants = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const restaurant = {
        id: doc.id,
        name: data.name,
        address: data.address,
        category: data.category,
        province: data.province,
        latitude: data.latitude,
        longitude: data.longitude,
        rating: data.rating,
        reviewCount: data.reviewCount
      };
      
      allRestaurants.push(restaurant);
      
      const region = data.province || '기타';
      if (!byRegion[region]) byRegion[region] = [];
      byRegion[region].push(restaurant);
    });
    
    console.log('\n🗺️ 지역별 맛집 분포:');
    for (const [region, restaurants] of Object.entries(byRegion)) {
      console.log(`\n${region} (${restaurants.length}개):`);
      restaurants.forEach((r, i) => {
        console.log(`  ${i+1}. ${r.name}`);
        console.log(`     주소: ${r.address}`);
        console.log(`     카테고리: ${r.category}`);
        console.log(`     좌표: ${r.latitude}, ${r.longitude}`);
        if (r.rating) {
          console.log(`     평점: ${r.rating}★ (${r.reviewCount || 0}개)`);
        }
      });
    }
    
    console.log('\n📈 요약:');
    console.log(`   총 맛집 수: ${allRestaurants.length}개`);
    console.log('   지역별 분포:');
    for (const [region, restaurants] of Object.entries(byRegion)) {
      console.log(`     ${region}: ${restaurants.length}개`);
    }
    
  } catch (error) {
    console.error('❌ Firestore 확인 오류:', error.message);
  }
}

// 실행
checkFirestoreData();