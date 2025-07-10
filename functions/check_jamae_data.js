const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function checkJamaeData() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').where('name', '==', '자매국수').get();
  
  if (!snapshot.empty) {
    const doc = snapshot.docs[0];
    const data = doc.data();
    console.log('🔍 자매국수 현재 데이터:');
    console.log('   Google Places 리뷰:', data.googlePlaces?.reviews?.length || 0, '개');
    console.log('   Google Places 평점:', data.googlePlaces?.rating);
    console.log('   YouTube 언급:', data.youtubeStats?.mentionCount || 0, '회');
    console.log('   네이버 블로그:', data.naverBlog?.totalCount || 0, '개');
    
    if (data.googlePlaces?.reviews?.length > 0) {
      console.log('\n📝 첫 번째 리뷰:');
      const firstReview = data.googlePlaces.reviews[0];
      console.log('   작성자:', firstReview.author_name);
      console.log('   평점:', firstReview.rating);
      console.log('   내용:', firstReview.text.substring(0, 100) + '...');
    }
  } else {
    console.log('❌ 자매국수 데이터를 찾을 수 없습니다.');
  }
}

checkJamaeData().catch(console.error);