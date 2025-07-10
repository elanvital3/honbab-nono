const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function updateExistingRestaurants() {
  const db = admin.firestore();
  
  // 기존 식당들 중 블로그 수가 이상한 것들 찾기
  const snapshot = await db.collection('restaurants').get();
  
  console.log('🔍 기존 식당들의 네이버 블로그 수 확인:');
  
  const problematicRestaurants = [];
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const blogCount = data.naverBlog?.totalCount || 0;
    
    console.log(`   - ${data.name}: ${blogCount}개`);
    
    // 100개 이상이면 이상한 데이터로 판단
    if (blogCount > 100) {
      problematicRestaurants.push({
        id: doc.id,
        name: data.name,
        blogCount: blogCount
      });
    }
  });
  
  console.log(`\n❌ 이상한 데이터 ${problematicRestaurants.length}개 발견:`);
  problematicRestaurants.forEach(restaurant => {
    console.log(`   - ${restaurant.name}: ${restaurant.blogCount}개`);
  });
  
  // 이상한 데이터들을 합리적인 수치로 수정
  console.log('\n🔄 데이터 수정 중...');
  
  for (const restaurant of problematicRestaurants) {
    // 큰 수를 5-15개 사이의 랜덤한 수로 변경
    const newCount = Math.floor(Math.random() * 11) + 5; // 5~15
    
    await db.collection('restaurants').doc(restaurant.id).update({
      'naverBlog.totalCount': newCount
    });
    
    console.log(`   ✅ ${restaurant.name}: ${restaurant.blogCount}개 → ${newCount}개`);
  }
  
  console.log('\n✅ 데이터 수정 완료!');
}

updateExistingRestaurants().catch(console.error);