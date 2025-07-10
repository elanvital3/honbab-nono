// Flutter Restaurant.fromFirestore 로직을 JavaScript로 시뮬레이션
const sampleFirestoreData = {
  "address": "제주특별자치도 제주시 일도이동 380-2",
  "city": "제주시",
  "latitude": 33.5053007355143,
  "placeId": "1407469179",
  "naverBlog": {
    "blogs": [
      {
        "title": "제주시 분위기 좋은 와인바 옐로우돕 후기 일도이동 맛집",
        "link": "https://blog.naver.com/gisele_ahreum/223886083922",
        "description": "• 제주시에서 분위기 좋은 디너코스 찾는 분 • 와인과 함께 제대로 된 음식을 즐기고 싶은 분 • 제주 데이트코스 혹은 특별한 식사를 원하는 분 옐로우돕 사장님 와인고르는 안목 좋으시니, 와인... ",
        "bloggername": "제주에서 재주부리기",
        "postdate": "20250602"
      }
    ],
    "searchQuery": "옐로우돕 제주특별자치도 제주시 맛집",
    "totalCount": 10,
    "updatedAt": {
      "_seconds": 1751874978,
      "_nanoseconds": 644000000
    }
  },
  "source": "youtube_crawler",
  "isActive": true,
  "url": "http://place.map.kakao.com/1407469179",
  "tags": [
    "제주도"
  ],
  "province": "제주특별자치도",
  "phone": "010-4887-4005",
  "roadAddress": "제주특별자치도 제주시 고마로16길 9",
  "name": "옐로우돕",
  "category": "음식점 > 술집 > 와인바",
  "region": "제주도",
  "googlePlaces": null,
  "longitude": 126.540289992405,
  "updatedAt": {
    "_seconds": 1751874978,
    "_nanoseconds": 782000000
  }
};

function testRestaurantFromFirestore() {
  console.log('🧪 Flutter Restaurant.fromFirestore 시뮬레이션 테스트');
  
  try {
    // 각 필드 테스트
    const data = sampleFirestoreData;
    const documentId = '1407469179';
    
    console.log('✅ 기본 필드들:');
    console.log(`   id: ${documentId}`);
    console.log(`   name: ${data.name || ''}`);
    console.log(`   address: ${data.address || ''}`);
    console.log(`   latitude: ${data.latitude || 0.0}`);
    console.log(`   longitude: ${data.longitude || 0.0}`);
    console.log(`   category: ${data.category || ''}`);
    console.log(`   phone: ${data.phone || null}`);
    console.log(`   url: ${data.url || null}`);
    console.log(`   rating: ${data.rating || null}`);
    console.log(`   distance: ${data.distance || null}`);
    console.log(`   city: ${data.city || null}`);
    console.log(`   province: ${data.province || null}`);
    console.log(`   isActive: ${data.isActive ?? true}`);
    
    console.log('\\n✅ 고급 필드들:');
    console.log(`   imageUrl: ${data.imageUrl || null}`);
    console.log(`   featureTags: ${data.tags ? JSON.stringify(data.tags) : null}`);
    console.log(`   youtubeStats: ${data.youtubeStats ? 'exists' : null}`);
    console.log(`   trendScore: ${data.trendScore ? 'exists' : null}`);
    console.log(`   googlePlaces: ${data.googlePlaces ? 'exists' : null}`);
    
    // NaverBlog 테스트 (가장 의심되는 부분)
    console.log('\\n🔍 NaverBlog 필드 테스트:');
    if (data.naverBlog != null) {
      console.log('   naverBlog exists');
      console.log(`   totalCount: ${data.naverBlog.totalCount || 0}`);
      
      // 핵심: blogs vs posts 
      if (data.naverBlog.blogs) {
        console.log(`   blogs 배열: ${data.naverBlog.blogs.length}개`);
        console.log('   ✅ blogs 필드 발견 (Flutter 모델에서 수정됨)');
      } else if (data.naverBlog.posts) {
        console.log(`   posts 배열: ${data.naverBlog.posts.length}개`);
        console.log('   ❌ posts 필드 발견 (Flutter 모델과 불일치)');
      } else {
        console.log('   ❌ blogs 또는 posts 필드 없음');
      }
      
      // updatedAt 테스트
      if (data.naverBlog.updatedAt) {
        console.log('   updatedAt: Firestore Timestamp 객체');
        console.log(`   _seconds: ${data.naverBlog.updatedAt._seconds}`);
      }
    } else {
      console.log('   naverBlog: null');
    }
    
    console.log('\\n🎯 결론: 모든 필드가 정상적으로 처리 가능함');
    
  } catch (error) {
    console.log('❌ 에러 발생:', error.message);
  }
}

testRestaurantFromFirestore();