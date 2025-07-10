const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function checkGooglePlacesData() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').limit(3).get();
  
  snapshot.docs.forEach((doc, index) => {
    const data = doc.data();
    console.log(`\n🍽️ 식당 ${index + 1}: ${data.name}`);
    
    if (data.googlePlaces) {
      console.log('✅ googlePlaces 있음:');
      console.log(`   키들: [${Object.keys(data.googlePlaces).join(', ')}]`);
      if (data.googlePlaces.rating) console.log(`   평점: ${data.googlePlaces.rating}`);
      if (data.googlePlaces.userRatingsTotal) console.log(`   리뷰수: ${data.googlePlaces.userRatingsTotal}`);
      if (data.googlePlaces.isOpen !== undefined) console.log(`   영업상태: ${data.googlePlaces.isOpen ? '영업중' : '마감'}`);
    } else {
      console.log('❌ googlePlaces 없음 (null)');
    }
    
    if (data.youtubeStats) {
      console.log('✅ youtubeStats 있음:');
      console.log(`   언급수: ${data.youtubeStats.mentionCount || 0}`);
    } else {
      console.log('❌ youtubeStats 없음');
    }
    
    console.log(`📊 전체 필드: [${Object.keys(data).join(', ')}]`);
  });
}

checkGooglePlacesData().catch(console.error);