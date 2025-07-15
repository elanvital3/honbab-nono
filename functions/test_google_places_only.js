/**
 * 🧪 Google Places만 직접 테스트
 * - 카카오 단계 건너뛰고 Google Places만 테스트
 * - 실제 카카오 장소 데이터 시뮬레이션
 */

const UltimateRestaurantCrawler = require('./ultimate_restaurant_crawler');

async function testGooglePlacesOnly() {
  console.log('🧪 === Google Places 직접 테스트 ===\n');
  
  try {
    const crawler = new UltimateRestaurantCrawler();
    
    console.log(`🔑 Google API 키: ${crawler.googleApiKey ? 'OK' : 'MISSING'}`);
    console.log();

    // 실제 카카오 API 결과 시뮬레이션 (알려진 서울 맛집들)
    const testPlaces = [
      {
        place_name: '명동교자 본점',
        x: '126.9846632', // 경도
        y: '37.5637117',  // 위도
        road_address_name: '서울 중구 명동2가 25-1',
        address_name: '서울 중구 명동2가 25-1'
      },
      {
        place_name: '광장시장',
        x: '126.9997702',
        y: '37.5705931',
        road_address_name: '서울 종로구 창경궁로 88',
        address_name: '서울 종로구 종로5가 6-1'
      },
      {
        place_name: '이화수전통육개장',
        x: '126.9769156',
        y: '37.5683023',
        road_address_name: '서울 중구 신당동 370-12',
        address_name: '서울 중구 신당동 370-12'
      }
    ];
    
    console.log(`📍 테스트 대상: ${testPlaces.length}개 카카오 장소`);
    testPlaces.forEach((p, i) => {
      console.log(`   ${i + 1}. ${p.place_name} (${p.y}, ${p.x})`);
    });
    console.log();

    let googleSuccessCount = 0;
    let totalPhotos = 0;
    
    for (const kakaoPlace of testPlaces) {
      console.log(`\n🍽️ === ${kakaoPlace.place_name} Google Places 테스트 ===`);
      console.log(`📍 좌표: ${kakaoPlace.y}, ${kakaoPlace.x}`);
      
      try {
        const googleDetails = await crawler.getGooglePlacesDetails(kakaoPlace);
        
        if (googleDetails) {
          console.log(`✅ Google Places 성공!`);
          console.log(`   📊 평점: ${googleDetails.rating || 'N/A'}`);
          console.log(`   📝 리뷰 수: ${googleDetails.user_ratings_total || 'N/A'}`);
          console.log(`   📸 사진 수: ${googleDetails.photos?.length || 0}개`);
          console.log(`   📞 전화번호: ${googleDetails.formatted_phone_number || 'N/A'}`);
          console.log(`   🏢 영업 상태: ${googleDetails.business_status || 'N/A'}`);
          console.log(`   💰 가격대: ${googleDetails.price_level || 'N/A'}`);
          console.log(`   🌐 웹사이트: ${googleDetails.website || 'N/A'}`);
          
          googleSuccessCount++;
          totalPhotos += googleDetails.photos?.length || 0;
          
          // 크롤러에서 생성하는 방식대로 사진 URL 생성 테스트
          const photoUrls = [];
          if (googleDetails.photos && googleDetails.photos.length > 0) {
            console.log(`\n📸 사진 URL 생성 테스트:`);
            for (const photo of googleDetails.photos.slice(0, 3)) { // 처음 3개만 표시
              if (photo.photo_reference) {
                const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${photo.photo_reference}&key=${crawler.googleApiKey}`;
                photoUrls.push(photoUrl);
                console.log(`   ✅ ${photoUrl.substring(0, 100)}...`);
              }
            }
            
            // 크롤러에서 사용할 데이터 구조 생성
            const googleData = {
              placeId: googleDetails.place_id || null,
              rating: googleDetails.rating || null,
              userRatingsTotal: googleDetails.user_ratings_total || null,
              photos: photoUrls,
              regularOpeningHours: googleDetails.opening_hours || null,
              businessStatus: googleDetails.business_status || null,
              reviews: googleDetails.reviews || [],
              phoneNumber: googleDetails.formatted_phone_number || null,
              website: googleDetails.website || null,
              priceLevel: googleDetails.price_level || null
            };
            
            console.log(`\n🔥 크롤러용 데이터 구조 생성 완료:`);
            console.log(`   - Place ID: ${googleData.placeId ? 'OK' : 'MISSING'}`);
            console.log(`   - 평점: ${googleData.rating ? 'OK' : 'MISSING'}`);
            console.log(`   - 사진 URL: ${googleData.photos.length}개`);
            console.log(`   - 영업시간: ${googleData.regularOpeningHours ? 'OK' : 'MISSING'}`);
          }
          
        } else {
          console.log(`❌ Google Places 실패`);
        }
        
      } catch (error) {
        console.log(`❌ ${kakaoPlace.place_name} Google Places 테스트 실패: ${error.message}`);
      }
      
      // API 호출 간격
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // 최종 통계
    console.log('\n🎯 === Google Places 테스트 결과 ===');
    console.log(`🍽️ 총 테스트 장소: ${testPlaces.length}개`);
    console.log(`✅ Google Places 성공: ${googleSuccessCount}개`);
    console.log(`📸 총 수집된 사진: ${totalPhotos}개`);
    console.log(`💯 성공률: ${Math.round((googleSuccessCount / testPlaces.length) * 100)}%`);
    
    if (googleSuccessCount > 0) {
      const avgPhotos = Math.round(totalPhotos / googleSuccessCount);
      console.log(`📊 평균 사진 수: ${avgPhotos}개/식당`);
      console.log(`\n🎉 Google Places 기능이 정상적으로 작동합니다!`);
      console.log(`🔧 크롤러에서 "📊 Google Places 상세 정보 보강: 0개" 문제가 해결될 것입니다.`);
    } else {
      console.log(`\n❌ Google Places 기능에 여전히 문제가 있습니다.`);
    }
    
  } catch (error) {
    console.error(`❌ 테스트 실행 중 오류: ${error.message}`);
    console.error(error);
  }
}

// 테스트 실행
testGooglePlacesOnly()
  .then(() => {
    console.log('\n✅ Google Places 테스트 완료');
    process.exit(0);
  })
  .catch(error => {
    console.error(`\n❌ 테스트 오류: ${error.message}`);
    process.exit(1);
  });