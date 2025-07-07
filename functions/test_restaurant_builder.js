/**
 * 맛집 DB 빌더 테스트 스크립트
 * - 단일 지역 또는 전체 실행 가능
 * - Firebase 인증 문제 디버깅 포함
 */

const RestaurantDBBuilder = require('./restaurant_db_builder');

async function testSingleRegion() {
  console.log('🧪 단일 지역 테스트: 제주도\n');
  
  try {
    const builder = new RestaurantDBBuilder();
    
    // 기존 데이터 확인
    console.log('📊 기존 데이터 확인:');
    await builder.checkRestaurantsCollection();
    
    // 제주도 데이터만 수집
    console.log('\n🌍 제주도 맛집 수집 시작...');
    const results = await builder.collectAndSaveRegionRestaurants('제주도');
    
    // 결과 출력
    console.log('\n📋 제주도 수집 결과:');
    results.forEach(result => {
      if (result.success) {
        console.log(`✅ ${result.name} - ${result.rating}★ (${result.reviewCount}개)`);
      } else {
        console.log(`❌ ${result.name} (${result.reason})`);
      }
    });
    
    // 최종 데이터 확인
    console.log('\n📊 최종 데이터 상태:');
    await builder.checkRestaurantsCollection();
    
  } catch (error) {
    console.error('❌ 테스트 실패:', error.message);
    
    if (error.message.includes('credentials')) {
      console.log('\n🔧 Firebase 인증 설정이 필요합니다:');
      console.log('1. Google Cloud SDK 설치');
      console.log('2. gcloud auth application-default login');
      console.log('3. Firebase 프로젝트 설정 확인');
    }
  }
}

async function testFullBuild() {
  console.log('🚀 전체 데이터베이스 구축 테스트\n');
  
  try {
    const builder = new RestaurantDBBuilder();
    const results = await builder.buildCompleteDatabase();
    
    console.log('\n🎉 전체 구축 테스트 완료!');
    return results;
    
  } catch (error) {
    console.error('❌ 전체 구축 실패:', error.message);
  }
}

// 명령행 인자에 따라 실행
const args = process.argv.slice(2);
const command = args[0] || 'single';

if (command === 'single') {
  testSingleRegion();
} else if (command === 'full') {
  testFullBuild();
} else {
  console.log('사용법:');
  console.log('  node test_restaurant_builder.js single  # 제주도만 테스트');
  console.log('  node test_restaurant_builder.js full    # 전체 지역 구축');
}