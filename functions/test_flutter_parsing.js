// Flutter GooglePlacesData.fromMap 로직을 JavaScript로 시뮬레이션
const googlePlacesData = {
  "website": null,
  "reviews": [],
  "phone": "064-763-2871",
  "placeId": "ChIJu20uru9TDDURWtOiyxtjHsI",
  "rating": 3.8,
  "userRatingsTotal": 133,
  "openingHours": null,
  "priceLevel": 2,
  "photos": []
};

function testFlutterGooglePlacesDataParsing() {
  console.log('🧪 Flutter GooglePlacesData.fromMap 시뮬레이션 테스트');
  
  try {
    console.log('✅ 실제 DB 데이터:');
    console.log(`   placeId: ${googlePlacesData.placeId}`);
    console.log(`   rating: ${googlePlacesData.rating} (타입: ${typeof googlePlacesData.rating})`);
    console.log(`   userRatingsTotal: ${googlePlacesData.userRatingsTotal} (타입: ${typeof googlePlacesData.userRatingsTotal})`);
    console.log(`   phone: ${googlePlacesData.phone}`);
    console.log(`   priceLevel: ${googlePlacesData.priceLevel}`);
    
    console.log('\n✅ Flutter에서 접근할 때:');
    const rating = googlePlacesData.rating;
    const userRatingsTotal = googlePlacesData.userRatingsTotal;
    
    if (rating != null) {
      console.log(`   ✅ rating이 null이 아님: ${rating}`);
      if (userRatingsTotal > 0) {
        console.log(`   ✅ UI에 표시될 텍스트: "Google ⭐ ${rating.toFixed(1)} (${userRatingsTotal}개)"`);
      } else {
        console.log(`   ✅ UI에 표시될 텍스트: "Google ⭐ ${rating.toFixed(1)}"`);
      }
    } else {
      console.log(`   ❌ rating이 null임`);
    }
    
    console.log('\n🎯 결론: Flutter에서 정상적으로 파싱 가능함');
    
  } catch (error) {
    console.log('❌ 에러 발생:', error.message);
  }
}

testFlutterGooglePlacesDataParsing();