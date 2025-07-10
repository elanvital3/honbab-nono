const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

async function debugGooglePlacesData() {
  const db = admin.firestore();
  const snapshot = await db.collection('restaurants').where('googlePlaces', '!=', null).limit(1).get();
  
  if (snapshot.empty) {
    console.log('❌ Google Places 데이터가 있는 식당 없음');
    return;
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  
  console.log(`🍽️ 식당: ${data.name}`);
  console.log('📊 Google Places 데이터 구조:');
  console.log(JSON.stringify(data.googlePlaces, null, 2));
}

debugGooglePlacesData().catch(console.error);