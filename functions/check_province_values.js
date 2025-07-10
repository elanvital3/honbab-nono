const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function checkProvince() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').get();
  
  console.log('📊 전체 레스토랑:', snapshot.size);
  
  const provinces = new Set();
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    provinces.add(data.province);
    console.log(`   ${data.name}: province="${data.province}", city="${data.city}"`);
  });
  
  console.log('\n🗺️ 모든 province 값들:');
  provinces.forEach(p => console.log(`   "${p}"`));
}

checkProvince().catch(console.error);