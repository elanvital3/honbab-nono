const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function checkNaverBlogStructure() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').limit(2).get();
  
  if (snapshot.empty) {
    console.log('❌ 데이터 없음');
    return;
  }
  
  snapshot.docs.forEach((doc, index) => {
    const data = doc.data();
    console.log(`\n🔍 식당 ${index + 1}: ${data.name}`);
    
    if (data.naverBlog && data.naverBlog.blogs) {
      const firstBlog = data.naverBlog.blogs[0];
      console.log('📝 첫 번째 블로그 포스트 필드들:');
      for (const [key, value] of Object.entries(firstBlog)) {
        const valueStr = typeof value === 'string' && value.length > 100 
          ? value.substring(0, 100) + '...' 
          : value;
        console.log(`   ${key}: ${typeof value} - "${valueStr}"`);
      }
    } else {
      console.log('❌ naverBlog.blogs 없음');
    }
  });
}

checkNaverBlogStructure().catch(console.error);