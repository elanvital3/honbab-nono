const admin = require('firebase-admin');

// Firebase 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

async function checkAndClean() {
  console.log('🔍 현재 저장된 식당 데이터 확인...');
  const snapshot = await db.collection('restaurants').get();
  
  console.log(`\n📊 총 식당 데이터: ${snapshot.docs.length}개\n`);
  
  // YouTube 데이터가 있는 식당들 확인
  let youtubeDataCount = 0;
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    
    if (data.youtubeStats && data.youtubeStats.channels && data.youtubeStats.channels.length > 0) {
      youtubeDataCount++;
      console.log(`\n🎥 ${data.name}:`);
      console.log(`   언급 횟수: ${data.youtubeStats.mentionCount}회`);
      console.log(`   유튜버들: [${data.youtubeStats.channels.join(', ')}]`);
      
      if (data.youtubeStats.representativeVideo) {
        console.log(`   대표 영상: "${data.youtubeStats.representativeVideo.title}"`);
        console.log(`   채널명: ${data.youtubeStats.representativeVideo.channelName}`);
      }
    }
  }
  
  console.log(`\n📊 YouTube 데이터가 있는 식당: ${youtubeDataCount}개 / 전체: ${snapshot.docs.length}개`);
  console.log('\n✅ 확인 완료!');
}

checkAndClean().catch(console.error);