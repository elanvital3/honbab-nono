/**
 * 🧪 수정된 크롤러 Google Places 기능 테스트
 * - 소규모 테스트 (3-5개 식당만)
 * - Google Places 데이터 및 사진 수집 확인
 */

const UltimateRestaurantCrawler = require('./ultimate_restaurant_crawler');

async function testCrawlerFix() {
  console.log('🧪 === 수정된 크롤러 Google Places 테스트 ===\n');
  
  try {
    const crawler = new UltimateRestaurantCrawler();
    
    console.log(`🔑 카카오 API 키: ${crawler.kakaoApiKey ? 'OK' : 'MISSING'}`);
    console.log(`🔑 Google API 키: ${crawler.googleApiKey ? 'OK' : 'MISSING'}`);
    console.log();
    
    // 테스트용 설정: 아주 작은 규모로
    crawler.stats = {
      youtubeVideos: 0,
      extractedRestaurants: 0,
      googlePlacesRestaurants: 0,
      mergedRestaurants: 0,
      kakaoMatched: 0,
      googleEnhanced: 0,
      naverBlogAdded: 0,
      saved: 0,
      errors: 0
    };

    // 테스트할 식당 데이터 (실제 서울 맛집들)
    const testRestaurants = [
      { name: '명동교자', query: '명동교자 서울' },
      { name: '광장시장 마약김밥', query: '광장시장 마약김밥' },
      { name: '이화수전통육개장', query: '이화수전통육개장 서울' }
    ];
    
    console.log(`📍 테스트 대상: ${testRestaurants.length}개 식당`);
    console.log('테스트 식당 목록:');
    testRestaurants.forEach((r, i) => {
      console.log(`   ${i + 1}. ${r.name}`);
    });
    console.log();

    let successCount = 0;
    let googleSuccessCount = 0;
    let photoCount = 0;
    
    for (const testRestaurant of testRestaurants) {
      console.log(`\n🍽️ === ${testRestaurant.name} 테스트 ===`);
      
      try {
        // 1단계: 카카오 API 검색
        console.log(`1️⃣ 카카오 검색: "${testRestaurant.query}"`);
        console.log(`   검색어: ${testRestaurant.name}`);
        console.log(`   지역: 서울`);
        
        const kakaoPlace = await crawler.searchKakaoPlace(testRestaurant.name, '서울');
        
        if (!kakaoPlace) {
          console.log(`   ❌ 카카오에서 찾지 못함`);
          continue;
        }
        console.log(`   ✅ 카카오 매칭: ${kakaoPlace.place_name}`);
        console.log(`   📍 주소: ${kakaoPlace.road_address_name || kakaoPlace.address_name}`);
        successCount++;
        
        // 2단계: Google Places 상세 정보
        console.log(`2️⃣ Google Places 상세 정보 수집...`);
        const googleDetails = await crawler.getGooglePlacesDetails(kakaoPlace);
        
        if (googleDetails) {
          console.log(`   ✅ Google Places 성공!`);
          console.log(`   📊 평점: ${googleDetails.rating || 'N/A'}`);
          console.log(`   📝 리뷰 수: ${googleDetails.user_ratings_total || 'N/A'}`);
          console.log(`   📸 사진 수: ${googleDetails.photos?.length || 0}개`);
          console.log(`   📞 전화번호: ${googleDetails.formatted_phone_number || 'N/A'}`);
          console.log(`   🏢 영업 상태: ${googleDetails.business_status || 'N/A'}`);
          console.log(`   💰 가격대: ${googleDetails.price_level || 'N/A'}`);
          
          googleSuccessCount++;
          photoCount += googleDetails.photos?.length || 0;
          
          // 사진 URL 미리보기 (첫 번째만)
          if (googleDetails.photos && googleDetails.photos.length > 0) {
            const firstPhoto = googleDetails.photos[0];
            if (firstPhoto.photo_reference) {
              const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${firstPhoto.photo_reference}&key=${crawler.googleApiKey}`;
              console.log(`   🔗 첫 번째 사진 URL: ${photoUrl.substring(0, 100)}...`);
            }
          }
        } else {
          console.log(`   ❌ Google Places 실패`);
        }
        
      } catch (error) {
        console.log(`   ❌ ${testRestaurant.name} 테스트 실패: ${error.message}`);
      }
      
      // API 호출 간격 (Rate Limiting 방지)
      await new Promise(resolve => setTimeout(resolve, 500));
    }
    
    // 최종 통계
    console.log('\n🎯 === 테스트 결과 요약 ===');
    console.log(`🍽️ 총 테스트 식당: ${testRestaurants.length}개`);
    console.log(`✅ 카카오 매칭 성공: ${successCount}개`);
    console.log(`📊 Google Places 성공: ${googleSuccessCount}개`);
    console.log(`📸 총 수집된 사진: ${photoCount}개`);
    console.log(`💯 Google Places 성공률: ${Math.round((googleSuccessCount / successCount) * 100)}%`);
    
    if (googleSuccessCount > 0) {
      console.log(`\n🎉 Google Places 기능이 정상적으로 작동합니다!`);
    } else {
      console.log(`\n❌ Google Places 기능에 여전히 문제가 있습니다.`);
    }
    
  } catch (error) {
    console.error(`❌ 테스트 실행 중 오류: ${error.message}`);
    console.error(error);
  }
}

// 테스트 실행
testCrawlerFix()
  .then(() => {
    console.log('\n✅ 테스트 완료');
    process.exit(0);
  })
  .catch(error => {
    console.error(`\n❌ 테스트 오류: ${error.message}`);
    process.exit(1);
  });