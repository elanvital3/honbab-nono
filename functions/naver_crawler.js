/**
 * 네이버 지도 평점 크롤러
 * - 네이버 검색 API를 통해 식당 정보 수집
 * - 평점 정보는 웹 스크래핑으로 수집 (API에서 제공하지 않음)
 */

const axios = require('axios');
const cheerio = require('cheerio');
const admin = require('firebase-admin');

// 환경변수에서 네이버 API 키 로드
require('dotenv').config({ path: '../flutter-app/.env' });

const NAVER_CLIENT_ID = process.env.NAVER_CLIENT_ID;
const NAVER_CLIENT_SECRET = process.env.NAVER_CLIENT_SECRET;

class NaverCrawler {
  constructor() {
    // Firebase Admin SDK 초기화 (한 번만)
    if (!admin.apps.length) {
      try {
        // 환경변수 또는 기본 인증 시도
        if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
          admin.initializeApp({
            credential: admin.credential.applicationDefault(),
            projectId: 'honbab-nono'
          });
        } else {
          // 로컬 테스트용: Firebase CLI 인증 사용
          admin.initializeApp({
            projectId: 'honbab-nono'
          });
        }
        console.log('✅ Firebase Admin 초기화 성공');
      } catch (error) {
        console.error('❌ Firebase Admin 초기화 실패:', error.message);
        throw error;
      }
    }
    this.db = admin.firestore();
  }

  /**
   * 네이버 검색 API로 식당 기본 정보 검색
   */
  async searchRestaurant(restaurantName, location = '서울') {
    try {
      const query = `${restaurantName} ${location}`;
      const apiUrl = 'https://openapi.naver.com/v1/search/local.json';
      
      const response = await axios.get(apiUrl, {
        headers: {
          'X-Naver-Client-Id': NAVER_CLIENT_ID,
          'X-Naver-Client-Secret': NAVER_CLIENT_SECRET,
        },
        params: {
          query: query,
          display: 5,
          start: 1,
          sort: 'comment' // 리뷰 많은 순
        }
      });

      const results = response.data.items || [];
      console.log(`🔍 네이버에서 "${restaurantName}" 검색 결과: ${results.length}개`);
      
      return results.map(item => ({
        title: this.cleanHtmlTags(item.title),
        link: item.link,
        description: this.cleanHtmlTags(item.description),
        address: item.address,
        roadAddress: item.roadAddress,
        mapx: item.mapx, // 네이버 지도 X 좌표
        mapy: item.mapy  // 네이버 지도 Y 좌표
      }));
    } catch (error) {
      console.error('❌ 네이버 검색 API 오류:', error.message);
      return [];
    }
  }

  /**
   * 네이버 지도 페이지에서 평점 정보 스크래핑
   */
  async scrapeRatingFromNaverPlace(placeUrl) {
    try {
      // User-Agent 설정 (봇 차단 방지)
      const response = await axios.get(placeUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        timeout: 10000
      });

      const $ = cheerio.load(response.data);
      
      // 네이버 지도 평점 선택자 (2024년 기준, 변경될 수 있음)
      const ratingElement = $('.PXMot.LXIwF');
      const reviewCountElement = $('.place_section_count');
      
      let rating = 0.0;
      let reviewCount = 0;

      if (ratingElement.length > 0) {
        const ratingText = ratingElement.text().trim();
        rating = parseFloat(ratingText) || 0.0;
      }

      if (reviewCountElement.length > 0) {
        const reviewText = reviewCountElement.text().trim();
        const match = reviewText.match(/(\d+)/);
        reviewCount = match ? parseInt(match[1]) : 0;
      }

      console.log(`⭐ 네이버 평점: ${rating}/5.0 (${reviewCount}개 리뷰)`);
      
      return {
        score: rating,
        reviewCount: reviewCount,
        url: placeUrl
      };
    } catch (error) {
      console.error('❌ 네이버 평점 스크래핑 오류:', error.message);
      return null;
    }
  }

  /**
   * 네이버 지도 검색으로 더 정확한 정보 수집
   */
  async searchNaverMap(restaurantName, address) {
    try {
      const query = encodeURIComponent(`${restaurantName} ${address}`);
      const mapSearchUrl = `https://map.naver.com/v5/search/${query}`;
      
      // 실제로는 Selenium이나 Puppeteer가 필요할 수 있음
      // 여기서는 기본적인 구조만 제공
      console.log(`🗺️ 네이버 지도 검색: ${mapSearchUrl}`);
      
      return {
        mapUrl: mapSearchUrl,
        // 실제 구현에서는 더 정교한 데이터 추출 필요
      };
    } catch (error) {
      console.error('❌ 네이버 지도 검색 오류:', error.message);
      return null;
    }
  }

  /**
   * 식당 평점 정보를 Firestore에 저장
   */
  async saveRatingToFirestore(restaurantData) {
    try {
      const restaurantId = this.generateRestaurantId(restaurantData.name, restaurantData.address);
      
      // 우선 데이터만 출력하고 Firebase 저장은 나중에 해결
      console.log('\n📊 수집된 데이터:');
      console.log(`   이름: ${restaurantData.name}`);
      console.log(`   주소: ${restaurantData.address}`);
      console.log(`   좌표: ${restaurantData.latitude}, ${restaurantData.longitude}`);
      console.log(`   네이버 평점: ${JSON.stringify(restaurantData.naverRating)}`);
      console.log(`   카테고리: ${restaurantData.category}`);
      console.log(`   ID: ${restaurantId}\n`);
      
      // Firebase 저장 시도 (에러 발생 시 무시)
      try {
        const docRef = this.db.collection('restaurant_ratings').doc(restaurantId);
        const now = admin.firestore.Timestamp.now();
        
        const data = {
          name: restaurantData.name,
          address: restaurantData.address,
          latitude: restaurantData.latitude || 0,
          longitude: restaurantData.longitude || 0,
          naverRating: restaurantData.naverRating ? {
            score: restaurantData.naverRating.score,
            reviewCount: restaurantData.naverRating.reviewCount,
            url: restaurantData.naverRating.url
          } : null,
          category: restaurantData.category || '음식점',
          lastUpdated: now,
          createdAt: now,
          deepLinks: restaurantData.naverRating?.url ? {
            naver: restaurantData.naverRating.url
          } : {}
        };

        await docRef.set(data, { merge: true });
        console.log(`✅ Firestore 저장 완료: ${restaurantId}`);
      } catch (fbError) {
        console.log(`⚠️ Firebase 저장 실패 (데이터 수집은 성공): ${fbError.message}`);
      }
      
      return restaurantId;
    } catch (error) {
      console.error('❌ 전체 저장 오류:', error.message);
      return null;
    }
  }

  /**
   * 식당별 전체 평점 정보 수집 및 저장
   */
  async crawlRestaurantRating(restaurantName, location = '서울') {
    console.log(`\n🔄 "${restaurantName}" 평점 크롤링 시작...`);
    
    try {
      // 1. 네이버 검색 API로 기본 정보 수집
      const searchResults = await this.searchRestaurant(restaurantName, location);
      
      if (searchResults.length === 0) {
        console.log(`❌ "${restaurantName}" 검색 결과 없음`);
        return null;
      }

      const topResult = searchResults[0];
      
      // 2. 평점 정보 스크래핑 (네이버 지도 링크가 있는 경우)
      let naverRating = null;
      if (topResult.link && topResult.link.includes('map.naver.com')) {
        naverRating = await this.scrapeRatingFromNaverPlace(topResult.link);
      }

      // 3. 좌표 변환 (네이버 좌표 → WGS84)
      const coordinates = this.convertNaverCoordinates(topResult.mapx, topResult.mapy);

      // 4. 데이터 구성
      const restaurantData = {
        name: topResult.title,
        address: topResult.roadAddress || topResult.address,
        latitude: coordinates.lat,
        longitude: coordinates.lng,
        naverRating: naverRating,
        category: topResult.description || '음식점'
      };

      // 5. Firestore에 저장
      const restaurantId = await this.saveRatingToFirestore(restaurantData);
      
      console.log(`✅ "${restaurantName}" 크롤링 완료 (ID: ${restaurantId})`);
      return restaurantData;

    } catch (error) {
      console.error(`❌ "${restaurantName}" 크롤링 실패:`, error.message);
      return null;
    }
  }

  /**
   * 네이버 좌표를 WGS84로 변환
   */
  convertNaverCoordinates(mapx, mapy) {
    // 네이버 좌표는 이미 WGS84 형태의 소수점 좌표로 제공됨
    let lng = parseFloat(mapx) || 0;
    let lat = parseFloat(mapy) || 0;
    
    // 좌표가 0인 경우 기본값 사용 (서울 시청)
    if (lng === 0 || lat === 0) {
      console.warn('⚠️ 네이버 좌표가 0입니다. 기본값 사용.');
      return { lat: 37.5665, lng: 126.9780 };
    }
    
    // 네이버 좌표가 정수 형태로 온 경우만 변환 (1270000000 -> 127.0)
    if (lng > 1000) {
      lng = lng / 10000000;
    }
    if (lat > 1000) {
      lat = lat / 10000000;
    }
    
    // 좌표 유효성 검증 (대한민국 범위)
    if (lat < 33 || lat > 39 || lng < 124 || lng > 132) {
      console.warn(`⚠️ 좌표가 한국 범위를 벗어남: ${lat}, ${lng}. 기본값 사용.`);
      return { lat: 37.5665, lng: 126.9780 };
    }
    
    console.log(`📍 변환된 좌표: ${lat}, ${lng}`);
    return { lat, lng };
  }

  /**
   * 식당 고유 ID 생성
   */
  generateRestaurantId(name, address) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    const cleanAddress = address.replace(/[^가-힣a-zA-Z0-9]/g, '').substring(0, 10);
    return `naver_${cleanName}_${cleanAddress}`.toLowerCase();
  }

  /**
   * HTML 태그 제거
   */
  cleanHtmlTags(text) {
    return text ? text.replace(/<[^>]*>/g, '') : '';
  }
}

// 스크립트 직접 실행 시 테스트
if (require.main === module) {
  const crawler = new NaverCrawler();
  
  // 테스트할 식당 목록
  const testRestaurants = [
    '은희네해장국',
    '맘스터치',
    '스타벅스',
    '김밥천국',
    '피자헛'
  ];

  async function runTest() {
    console.log('🚀 네이버 크롤러 테스트 시작...\n');
    
    for (const restaurant of testRestaurants) {
      await crawler.crawlRestaurantRating(restaurant);
      
      // API 호출 제한 방지를 위한 딜레이
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    console.log('\n🎉 네이버 크롤러 테스트 완료!');
  }

  runTest().catch(console.error);
}

module.exports = NaverCrawler;