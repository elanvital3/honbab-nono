/**
 * 다이닝코드 실제 평점 크롤러
 * - 실제 사용자 평점과 리뷰 수 제공
 * - JSON 구조로 크롤링 용이
 * - 지역별 맛집 TOP 20 수집 가능
 */

const axios = require('axios');
const cheerio = require('cheerio');
const admin = require('firebase-admin');

class DiningCodeCrawler {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    
    this.headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
      'Referer': 'https://www.diningcode.com',
    };
  }

  /**
   * 다이닝코드에서 지역별 맛집 TOP 리스트 수집
   */
  async getDiningCodeRestaurants(region) {
    try {
      console.log(`🔍 다이닝코드에서 "${region}" 맛집 검색...`);
      
      const searchUrl = `https://www.diningcode.com/list.dc?query=${encodeURIComponent(region)}`;
      
      const response = await axios.get(searchUrl, {
        headers: this.headers,
        timeout: 15000
      });

      const $ = cheerio.load(response.data);
      const restaurants = [];
      
      // JSON 데이터 추출 시도
      $('script').each((i, elem) => {
        const scriptContent = $(elem).html();
        if (scriptContent && scriptContent.includes('"restaurant_list"')) {
          try {
            // JSON 데이터 파싱
            const jsonMatch = scriptContent.match(/var\s+listData\s*=\s*({.*?});/s);
            if (jsonMatch) {
              const listData = JSON.parse(jsonMatch[1]);
              if (listData.restaurant_list) {
                restaurants.push(...listData.restaurant_list);
              }
            }
          } catch (parseError) {
            console.log('JSON 파싱 실패, HTML 파싱 시도...');
          }
        }
      });

      if (restaurants.length > 0) {
        console.log(`✅ ${restaurants.length}개 맛집 발견 (JSON 데이터)`);
        return restaurants.slice(0, 5); // 상위 5개만 선택
      }

      // JSON 실패 시 HTML 파싱 시도
      console.log('HTML 구조 분석 중...');
      const htmlRestaurants = [];
      
      $('.restaurant-item, .list-item, .restaurant').each((i, elem) => {
        const $elem = $(elem);
        const name = $elem.find('.name, .title, h3, .restaurant-name').first().text().trim();
        const ratingText = $elem.find('.rating, .score, .stars').first().text().trim();
        const reviewText = $elem.find('.review-count, .reviews').first().text().trim();
        
        if (name) {
          const rating = parseFloat(ratingText.match(/[0-9.]+/)?.[0]) || 0;
          const reviewCount = parseInt(reviewText.match(/[0-9]+/)?.[0]) || 0;
          
          htmlRestaurants.push({
            nm: name,
            user_score: rating,
            review_cnt: reviewCount,
            source: 'diningcode_html'
          });
        }
      });

      if (htmlRestaurants.length > 0) {
        console.log(`✅ ${htmlRestaurants.length}개 맛집 발견 (HTML 파싱)`);
        return htmlRestaurants.slice(0, 5);
      }

      console.log('❌ 맛집 데이터를 찾을 수 없음');
      return [];

    } catch (error) {
      console.error(`❌ 다이닝코드 크롤링 오류: ${error.message}`);
      return [];
    }
  }

  /**
   * 카카오 API로 위치 정보 보완
   */
  async getLocationFromKakao(restaurantName, region) {
    try {
      const KAKAO_REST_API_KEY = process.env.KAKAO_REST_API_KEY || 'c73d308c736b033acf2208469891f0e0';
      
      const apiUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      
      const response = await axios.get(apiUrl, {
        headers: {
          'Authorization': `KakaoAK ${KAKAO_REST_API_KEY}`,
        },
        params: {
          query: `${restaurantName} ${region}`,
          category_group_code: 'FD6',
          size: 1
        }
      });

      const results = response.data.documents || [];
      if (results.length > 0) {
        const place = results[0];
        return {
          address: place.address_name,
          roadAddress: place.road_address_name,
          latitude: parseFloat(place.y),
          longitude: parseFloat(place.x),
          phone: place.phone,
          category: place.category_name
        };
      }
      
      return null;
    } catch (error) {
      console.log(`⚠️ 카카오 위치 검색 실패: ${restaurantName}`);
      return null;
    }
  }

  /**
   * 다이닝코드 데이터를 Firebase 형식으로 변환
   */
  async convertToFirebaseFormat(diningCodeData, region) {
    const restaurants = [];
    
    for (let i = 0; i < diningCodeData.length; i++) {
      const item = diningCodeData[i];
      console.log(`\n[${i + 1}/${diningCodeData.length}] "${item.nm}" 처리 중...`);
      
      // 카카오에서 위치 정보 가져오기
      const locationData = await this.getLocationFromKakao(item.nm, region);
      
      const restaurant = {
        name: item.nm,
        rating: item.user_score || 0,
        reviewCount: item.review_cnt || 0,
        category: this.getCategoryFromName(item.nm),
        source: 'diningcode_real',
        isActive: true,
        isFeatured: true,
        region: region,
        ...this.getLocationFields(region),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      };

      // 위치 정보 추가
      if (locationData) {
        restaurant.address = locationData.address;
        restaurant.roadAddress = locationData.roadAddress;
        restaurant.latitude = locationData.latitude;
        restaurant.longitude = locationData.longitude;
        restaurant.phone = locationData.phone;
        restaurant.kakaoCategory = locationData.category;
        console.log(`   ✅ ${item.nm}: ${item.user_score}★ (${item.review_cnt}개) + 위치정보`);
      } else {
        restaurant.address = `${region} 지역`;
        restaurant.latitude = this.getDefaultLatitude(region);
        restaurant.longitude = this.getDefaultLongitude(region);
        console.log(`   ✅ ${item.nm}: ${item.user_score}★ (${item.review_cnt}개) - 기본위치`);
      }

      restaurants.push(restaurant);
      
      // API 제한 방지
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    return restaurants;
  }

  /**
   * 식당명에서 카테고리 추측
   */
  getCategoryFromName(name) {
    if (name.includes('해장국') || name.includes('국밥')) return '한식';
    if (name.includes('회') || name.includes('횟집')) return '회/해산물';
    if (name.includes('카페') || name.includes('커피')) return '카페';
    if (name.includes('피자')) return '피자';
    if (name.includes('치킨')) return '치킨';
    if (name.includes('중국') || name.includes('짜장')) return '중식';
    if (name.includes('초밥') || name.includes('스시')) return '일식';
    if (name.includes('스테이크') || name.includes('파스타')) return '양식';
    return '음식점';
  }

  /**
   * 지역별 기본 좌표
   */
  getDefaultLatitude(region) {
    const coords = {
      '제주도': 33.4996,
      '서울': 37.5665,
      '부산': 35.1796,
      '경주': 35.8414
    };
    return coords[region] || 37.5665;
  }

  getDefaultLongitude(region) {
    const coords = {
      '제주도': 126.5312,
      '서울': 126.9780,
      '부산': 129.0756,
      '경주': 129.2128
    };
    return coords[region] || 126.9780;
  }

  /**
   * 지역명을 Firebase 필드로 변환
   */
  getLocationFields(region) {
    const mapping = {
      '제주도': { province: '제주특별자치도', city: null },
      '서울': { province: '서울특별시', city: null },
      '부산': { province: '부산광역시', city: null },
      '경주': { province: '경상북도', city: '경주시' }
    };
    return mapping[region] || { province: null, city: null };
  }

  /**
   * 모든 지역의 다이닝코드 데이터 수집
   */
  async collectAllDiningCodeData() {
    try {
      console.log('🚀 다이닝코드에서 실제 평점 데이터 수집 시작...\n');
      
      const regions = ['제주도', '서울', '부산', '경주'];
      let totalSaved = 0;
      
      // 기존 데이터 삭제
      console.log('🗑️ 기존 restaurants 컬렉션 데이터 삭제...');
      const existingSnapshot = await this.db.collection('restaurants').get();
      const deletePromises = existingSnapshot.docs.map(doc => doc.ref.delete());
      await Promise.all(deletePromises);
      console.log(`✅ ${existingSnapshot.size}개 기존 데이터 삭제 완료\n`);
      
      // 지역별 데이터 수집
      for (const region of regions) {
        console.log(`🌍 ${region} 지역 처리 중...`);
        
        try {
          // 다이닝코드에서 데이터 수집
          const diningCodeData = await this.getDiningCodeRestaurants(region);
          
          if (diningCodeData.length > 0) {
            // Firebase 형식으로 변환
            const restaurants = await this.convertToFirebaseFormat(diningCodeData, region);
            
            // Firestore에 저장
            for (const restaurant of restaurants) {
              const docId = this.generateRestaurantId(restaurant.name, restaurant.address);
              await this.db.collection('restaurants').doc(docId).set(restaurant);
              totalSaved++;
            }
            
            console.log(`✅ ${region} 완료: ${restaurants.length}개 저장\n`);
          } else {
            console.log(`❌ ${region} 데이터 없음\n`);
          }
          
          // 지역 간 딜레이
          await new Promise(resolve => setTimeout(resolve, 3000));
          
        } catch (error) {
          console.error(`❌ ${region} 처리 오류:`, error.message);
        }
      }
      
      console.log(`🎉 다이닝코드 데이터 수집 완료!`);
      console.log(`   저장된 맛집: ${totalSaved}개`);
      console.log(`   ⭐ 실제 사용자 평점 포함`);
      console.log(`   💬 실제 리뷰 수 포함`);
      console.log(`   📍 카카오 API 위치 정보 보완`);
      
    } catch (error) {
      console.error('❌ 전체 수집 오류:', error.message);
    }
  }

  /**
   * 식당 ID 생성
   */
  generateRestaurantId(name, address) {
    const cleanName = name.replace(/[^가-힣a-zA-Z0-9]/g, '');
    const cleanAddress = address.replace(/[^가-힣a-zA-Z0-9]/g, '').substring(0, 8);
    const timestamp = Date.now().toString().slice(-3);
    return `dining_${cleanName}_${cleanAddress}_${timestamp}`.toLowerCase();
  }
}

// 직접 실행
if (require.main === module) {
  // 환경변수 로드
  require('dotenv').config({ path: '../flutter-app/.env' });
  
  async function runDiningCodeCrawler() {
    console.log('🚀 다이닝코드 실제 평점 크롤러 시작...\n');
    console.log('📝 특징:');
    console.log('   - 실제 사용자 평점 수집 (다이닝코드)');
    console.log('   - 실제 리뷰 수 수집');
    console.log('   - 카카오 API로 정확한 위치 정보 보완');
    console.log('   - 지역별 TOP 5 맛집 선별\n');
    
    const crawler = new DiningCodeCrawler();
    await crawler.collectAllDiningCodeData();
  }
  
  runDiningCodeCrawler().catch(console.error);
}

module.exports = DiningCodeCrawler;