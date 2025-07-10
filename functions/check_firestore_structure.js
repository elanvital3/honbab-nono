const admin = require('firebase-admin');

// Firebase 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'honbab-nono'
  });
}

const db = admin.firestore();

async function checkCurrentData() {
  console.log('🔍 현재 Firestore 데이터 구조 확인...');
  const snapshot = await db.collection('restaurants').limit(1).get();
  
  if (snapshot.empty) {
    console.log('❌ 데이터 없음');
    return;
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  
  console.log('\n📋 문서 ID:', doc.id);
  console.log('📋 데이터 키들:', Object.keys(data));
  
  // 각 필드의 타입 확인
  for (const [key, value] of Object.entries(data)) {
    const type = typeof value;
    const isArray = Array.isArray(value);
    const isObject = type === 'object' && !isArray && value !== null;
    
    console.log(`   ${key}: ${type}${isArray ? ' (array)' : ''}${isObject ? ' (object)' : ''}`);
    
    // 중첩 객체인 경우 키들도 표시
    if (isObject && !value.toDate) {
      console.log(`      keys: [${Object.keys(value).join(', ')}]`);
    }
  }
  
  // 전체 데이터 출력 (JSON 형태)
  console.log('\n📄 전체 데이터:');
  console.log(JSON.stringify(data, null, 2));
}

checkCurrentData().catch(console.error);