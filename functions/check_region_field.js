const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function checkRegionField() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').limit(10).get();
  
  console.log('🔍 지역 필드 확인:');
  snapshot.docs.forEach((doc, index) => {
    const data = doc.data();
    console.log(`${index + 1}. ${data.name}`);
    console.log(`   region: "${data.region}"`);
    console.log(`   province: "${data.province}"`);
    console.log(`   city: "${data.city}"`);
    console.log(`   address: "${data.address}"`);
    console.log('');
  });
}

checkRegionField().catch(console.error);