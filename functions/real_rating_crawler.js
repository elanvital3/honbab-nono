/**
 * 실제 평점 크롤러 - 네이버/카카오 실제 평점 수집
 * - 네이버 지도 API 활용
 * - 카카오 지도 API 활용
 * - 실제 평점 데이터만 수집
 */

const axios = require('axios');
const cheerio = require('cheerio');

// 환경변수에서 API 키 로드
require('dotenv').config({ path: '../flutter-app/.env' });

const KAKAO_REST_API_KEY = process.env.KAKAO_REST_API_KEY;
const NAVER_CLIENT_ID = process.env.NAVER_CLIENT_ID;
const NAVER_CLIENT_SECRET = process.env.NAVER_CLIENT_SECRET;

class RealRatingCrawler {
  constructor() {
    this.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate, br',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    };
  }

  /**
   * 카카오 지도에서 실제 평점 추출
   */
  async getKakaoRealRating(restaurantName, region = '') {
    try {
      console.log(`🔍 카카오에서 "${restaurantName}" 실제 평점 검색...`);
      
      // 1단계: 카카오 로컬 API로 장소 ID 찾기
      const searchUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      const searchResponse = await axios.get(searchUrl, {
        headers: {
          'Authorization': `KakaoAK ${KAKAO_REST_API_KEY}`,
        },
        params: {
          query: `${restaurantName} ${region}`,
          category_group_code: 'FD6',
          size: 3
        }
      });

      const places = searchResponse.data.documents || [];
      if (places.length === 0) {
        console.log('   ❌ 검색 결과 없음');
        return null;
      }

      const place = places[0];
      console.log(`   ✅ 찾은 장소: ${place.place_name}`);
      console.log(`   📍 카카오맵 URL: ${place.place_url}`);

      // 2단계: 카카오맵 페이지에서 평점 스크래핑
      const mapResponse = await axios.get(place.place_url, {
        headers: this.headers,
        timeout: 10000
      });

      const $ = cheerio.load(mapResponse.data);
      
      // 카카오맵 평점 선택자들 (2024년 최신)
      let rating = null;
      let reviewCount = 0;

      // 평점 추출 시도 - 여러 선택자 패턴 시도
      const ratingSelectors = [
        '.grade_star .num_rate',
        '.score_star .num_rate', 
        '.rating_star .num_rate',
        '.grade .num_rate',
        '[class*=\"rating\"] [class*=\"num\"]',
        '[class*=\"grade\"] [class*=\"num\"]'
      ];

      for (const selector of ratingSelectors) {
        const ratingElement = $(selector);
        if (ratingElement.length > 0) {
          const ratingText = ratingElement.text().trim();
          const parsedRating = parseFloat(ratingText);
          if (!isNaN(parsedRating) && parsedRating > 0) {
            rating = parsedRating;
            console.log(`   ⭐ 평점 발견 (${selector}): ${rating}`);
            break;
          }
        }
      }

      // 리뷰 수 추출 시도
      const reviewSelectors = [
        '.link_evaluation .num_review',
        '.txt_review .num_review',
        '[class*=\"review\"] [class*=\"num\"]',
        '.evaluation_review .num_review'
      ];

      for (const selector of reviewSelectors) {
        const reviewElement = $(selector);
        if (reviewElement.length > 0) {
          const reviewText = reviewElement.text().trim();
          const match = reviewText.match(/(\d+)/);
          if (match) {
            reviewCount = parseInt(match[1]);
            console.log(`   💬 리뷰 수 발견 (${selector}): ${reviewCount}`);
            break;
          }
        }
      }

      // 페이지 전체에서 패턴 매칭으로 평점 찾기 (백업)
      if (!rating) {
        const pageText = mapResponse.data;
        const ratingPattern = /\"rating\"\\s*:\\s*([0-9.]+)/;
        const match = pageText.match(ratingPattern);
        if (match) {
          rating = parseFloat(match[1]);
          console.log(`   ⭐ 패턴 매칭으로 평점 발견: ${rating}`);
        }
      }

      if (rating && rating > 0) {
        console.log(`   ✅ 최종 결과: ${rating}★ (${reviewCount}개)`);
        return {
          name: place.place_name,
          address: place.address_name,
          latitude: parseFloat(place.y),
          longitude: parseFloat(place.x),
          rating: rating,
          reviewCount: reviewCount,
          source: 'kakao_real',
          url: place.place_url,
          category: place.category_name
        };
      } else {
        console.log('   ❌ 평점 정보 없음');
        return null;
      }

    } catch (error) {
      console.error(`   ❌ 카카오 크롤링 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 네이버 지도에서 실제 평점 추출 
   */
  async getNaverRealRating(restaurantName, region = '') {
    try {
      console.log(`🔍 네이버에서 "${restaurantName}" 실제 평점 검색...`);
      
      // 네이버 지도 검색 URL 직접 구성
      const query = encodeURIComponent(`${restaurantName} ${region}`);
      const mapSearchUrl = `https://map.naver.com/v5/search/${query}`;
      
      console.log(`   📍 네이버 지도 검색: ${mapSearchUrl}`);
      
      // 네이버 지도 페이지 접근
      const response = await axios.get(mapSearchUrl, {
        headers: this.headers,
        timeout: 10000
      });

      // 페이지에서 JSON 데이터 추출 시도
      const pageContent = response.data;
      
      // 네이버 지도의 검색 결과 JSON 파싱 시도
      const searchResultPattern = /\"searchResult\"\\s*:\\s*\\{[^}]+\"place\"\\s*:\\s*\\{([^}]+)\\}/;
      const ratingPattern = /\"totalScore\"\\s*:\\s*([0-9.]+)/;
      const reviewPattern = /\"reviewCount\"\\s*:\\s*([0-9]+)/;
      
      let rating = null;
      let reviewCount = 0;
      let placeName = restaurantName;

      // JSON에서 평점 정보 추출
      const ratingMatch = pageContent.match(ratingPattern);
      if (ratingMatch) {
        rating = parseFloat(ratingMatch[1]);
        console.log(`   ⭐ 평점 발견: ${rating}`);
      }

      const reviewMatch = pageContent.match(reviewPattern);
      if (reviewMatch) {
        reviewCount = parseInt(reviewMatch[1]);
        console.log(`   💬 리뷰 수 발견: ${reviewCount}`);
      }

      // 가게명 추출
      const namePattern = /\"name\"\\s*:\\s*\"([^\"]+)\"/;
      const nameMatch = pageContent.match(namePattern);
      if (nameMatch) {
        placeName = nameMatch[1];
        console.log(`   🏪 업체명: ${placeName}`);
      }

      if (rating && rating > 0) {
        console.log(`   ✅ 최종 결과: ${rating}★ (${reviewCount}개)`);
        return {
          name: placeName,
          rating: rating,
          reviewCount: reviewCount,
          source: 'naver_real',
          url: mapSearchUrl
        };
      } else {
        console.log('   ❌ 평점 정보 없음');
        return null;
      }

    } catch (error) {
      console.error(`   ❌ 네이버 크롤링 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 테스트: 실제 평점 수집 가능한지 확인
   */
  async testRealRatings() {
    console.log('🧪 실제 평점 크롤링 테스트 시작...\n');
    
    const testRestaurants = [
      { name: '명동교자', region: '서울 중구' },
      { name: '돈사돈', region: '제주시' },
      { name: '자갈치시장', region: '부산 중구' }
    ];

    for (const restaurant of testRestaurants) {
      console.log(`\n🍽️ "${restaurant.name}" 테스트:`);
      
      // 카카오 테스트
      const kakaoResult = await this.getKakaoRealRating(restaurant.name, restaurant.region);
      if (kakaoResult) {
        console.log(`   카카오: ${kakaoResult.rating}★ (${kakaoResult.reviewCount}개)`);
      } else {
        console.log('   카카오: 평점 없음');
      }
      
      // 딜레이
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // 네이버 테스트  
      const naverResult = await this.getNaverRealRating(restaurant.name, restaurant.region);
      if (naverResult) {
        console.log(`   네이버: ${naverResult.rating}★ (${naverResult.reviewCount}개)`);
      } else {
        console.log('   네이버: 평점 없음');
      }
      
      // 딜레이
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
}

// 직접 실행 시 테스트
if (require.main === module) {
  const crawler = new RealRatingCrawler();
  crawler.testRealRatings().catch(console.error);
}

module.exports = RealRatingCrawler;