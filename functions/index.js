/**
 * 혼밥노노 Firebase Functions
 * 식당 데이터 자동 업데이트 시스템
 */

const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule: onScheduleV2} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");

// Firebase Admin 초기화
admin.initializeApp();
const db = admin.firestore();

// 네이버 API 설정
const NAVER_CLIENT_ID = "Hf3AWGaBRFz0FTSb9hCg";
const NAVER_CLIENT_SECRET = "aW3TG3ZpPg";
const NAVER_API_URL = "https://openapi.naver.com/v1/search/local.json";

// 주요 도시 좌표 (Flutter 앱과 동일)
const MAJOR_CITIES = {
  "서울시": {lat: 37.5665, lng: 126.9780},
  "부산시": {lat: 35.1796, lng: 129.0756},
  "대구시": {lat: 35.8714, lng: 128.6014},
  "인천시": {lat: 37.4563, lng: 126.7052},
  "광주시": {lat: 35.1595, lng: 126.8526},
  "대전시": {lat: 36.3504, lng: 127.3845},
  "울산시": {lat: 35.5384, lng: 129.3114},
  "세종시": {lat: 36.4800, lng: 127.2890},
  "수원시": {lat: 37.2636, lng: 127.0286},
  "성남시": {lat: 37.4201, lng: 127.1262},
  "천안시": {lat: 36.8151, lng: 127.1139},
  "전주시": {lat: 35.8242, lng: 127.1480},
  "청주시": {lat: 36.6424, lng: 127.4890},
  "춘천시": {lat: 37.8813, lng: 127.7298},
  "제주시": {lat: 33.4996, lng: 126.5312},
  "서귀포시": {lat: 33.2544, lng: 126.5600},
};

// 주기적 식당 데이터 업데이트 (매주 일요일 새벽 2시)
exports.updateRestaurantsWeekly = onScheduleV2("0 2 * * 0", async (event) => {
  logger.info("🍽️ 주간 식당 데이터 업데이트 시작");

  try {
    let totalUpdated = 0;

    // 각 주요 도시별로 식당 데이터 수집
    for (const [cityName, coords] of Object.entries(MAJOR_CITIES)) {
      logger.info(`📍 ${cityName} 식당 데이터 수집 중...`);

      const restaurants = await fetchRestaurantsForCity(cityName, coords);
      const updatedCount = await saveRestaurantsToFirestore(restaurants);

      totalUpdated += updatedCount;
      logger.info(`✅ ${cityName}: ${updatedCount}개 식당 업데이트 완료`);

      // API 호출 제한을 위해 1초 대기
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    logger.info(`🎉 전체 업데이트 완료: ${totalUpdated}개 식당`);
    return {success: true, totalUpdated};
  } catch (error) {
    logger.error("❌ 식당 데이터 업데이트 실패:", error);
    throw error;
  }
});

// 수동 식당 데이터 업데이트 (테스트용)
exports.updateRestaurantsManual = onRequest(async (request, response) => {
  logger.info("🔧 수동 식당 데이터 업데이트 시작");

  try {
    let totalUpdated = 0;
    const results = {};

    // 요청에서 특정 도시만 업데이트할지 확인
    const targetCity = request.query.city;
    const citiesToUpdate = targetCity ?
      {[targetCity]: MAJOR_CITIES[targetCity]} :
      MAJOR_CITIES;

    if (targetCity && !MAJOR_CITIES[targetCity]) {
      response.status(400).json({
        error: `지원하지 않는 도시: ${targetCity}`,
        availableCities: Object.keys(MAJOR_CITIES),
      });
      return;
    }

    for (const [cityName, coords] of Object.entries(citiesToUpdate)) {
      logger.info(`📍 ${cityName} 식당 데이터 수집 중...`);

      const restaurants = await fetchRestaurantsForCity(cityName, coords);
      const updatedCount = await saveRestaurantsToFirestore(restaurants);

      results[cityName] = updatedCount;
      totalUpdated += updatedCount;

      // API 호출 제한을 위해 1초 대기
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    logger.info(`🎉 수동 업데이트 완료: ${totalUpdated}개 식당`);

    response.json({
      success: true,
      totalUpdated,
      results,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error("❌ 수동 업데이트 실패:", error);
    response.status(500).json({
      error: "식당 데이터 업데이트 실패",
      message: error.message,
    });
  }
});

/**
 * 특정 도시의 식당 데이터 수집
 * @param {string} cityName 도시명
 * @param {object} coords 좌표 {lat, lng}
 * @return {Promise<Array>} 식당 데이터 배열
 */
async function fetchRestaurantsForCity(cityName, coords) {
  const restaurants = [];
  const categories = ["맛집", "한식", "중식", "일식", "양식", "카페"];

  try {
    for (const category of categories) {
      const categoryRestaurants = await fetchRestaurantsFromNaver(
          cityName, category);
      restaurants.push(...categoryRestaurants);

      // 카테고리별 API 호출 간격
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    // 중복 제거 (전화번호 기준)
    const uniqueRestaurants = removeDuplicateRestaurants(restaurants);

    logger.info(`📊 ${cityName}: ${uniqueRestaurants.length}개 고유 식당 발견`);
    return uniqueRestaurants;
  } catch (error) {
    logger.error(`❌ ${cityName} 식당 데이터 수집 실패:`, error);
    return [];
  }
}

/**
 * 네이버 API로 식당 검색 (페이지네이션 포함)
 * @param {string} cityName 도시명
 * @param {string} category 카테고리
 * @return {Promise<Array>} 식당 데이터 배열
 */
async function fetchRestaurantsFromNaver(cityName, category) {
  const allRestaurants = [];
  const maxPages = 50; // 네이버 API 페이지당 5개 x 50페이지 = 250개
  const pageSize = 5; // 네이버 API 실제 최대 display 값

  try {
    for (let page = 1; page <= maxPages; page++) {
      const start = (page - 1) * pageSize + 1;
      const query = `${cityName} ${category}`;

      const response = await axios.get(NAVER_API_URL, {
        params: {
          query: query,
          display: pageSize,
          start: start,
          sort: "random",
        },
        headers: {
          "X-Naver-Client-Id": NAVER_CLIENT_ID,
          "X-Naver-Client-Secret": NAVER_CLIENT_SECRET,
        },
      });

      if (response.status === 200 && response.data.items) {
        const restaurants = response.data.items
            .filter((item) => isRestaurantFromNaver(item.category))
            .map((item) => ({
              id: generateNaverRestaurantId(item.title, item.address),
              name: removeHtmlTags(item.title),
              address: item.address,
              roadAddress: item.roadAddress || "",
              latitude: parseInt(item.mapy) / 10000000, // 네이버 좌표 변환
              longitude: parseInt(item.mapx) / 10000000,
              category: item.category,
              phone: item.telephone || "",
              naverLink: item.link,
              city: cityName,
              province: findProvinceByCity(cityName),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              isActive: true,
              source: "naver_api",
            }));

        allRestaurants.push(...restaurants);

        logger.info(`🔍 ${cityName} ${category} 페이지 ${page}: ` +
            `${restaurants.length}개 식당 (누적: ${allRestaurants.length}개)`);

        // 결과가 pageSize보다 적으면 마지막 페이지
        if (response.data.items.length < pageSize) {
          break;
        }

        // API 호출 간격 (초당 10건 제한)
        await new Promise((resolve) => setTimeout(resolve, 100));
      } else {
        break;
      }
    }
  } catch (error) {
    if (error.response && error.response.status === 429) {
      logger.warn(`⏳ 네이버 API 호출 제한, 5초 대기 후 재시도...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
      return fetchRestaurantsFromNaver(cityName, category);
    }

    logger.error(`❌ ${cityName} ${category} 검색 실패:`, error.message);
    if (error.response && error.response.data) {
      logger.error("네이버 API 에러 상세:", JSON.stringify(error.response.data));
    }
  }

  logger.info(`✅ ${cityName} ${category}: ` +
      `총 ${allRestaurants.length}개 식당 수집 완료`);
  return allRestaurants;
}

/**
 * 식당 카테고리 필터링 (카카오 API용 - 사용 안함)
 * @param {string} category 카테고리명
 * @return {boolean} 식당 여부
 */
// eslint-disable-next-line no-unused-vars, require-jsdoc
function isRestaurant(category) {
  const restaurantKeywords = [
    "음식점", "카페", "디저트", "베이커리", "술집", "바", "맛집",
    "치킨", "피자", "햄버거", "분식", "한식", "중식", "일식", "양식",
    "패스트푸드", "레스토랑", "뷔페", "고기", "해산물", "아이스크림",
    "커피", "차",
  ];

  return restaurantKeywords.some((keyword) =>
    category.toLowerCase().includes(keyword.toLowerCase()));
}

/**
 * 네이버 API 식당 카테고리 필터링
 * @param {string} category 카테고리명
 * @return {boolean} 식당 여부
 */
function isRestaurantFromNaver(category) {
  // 네이버는 이미 "음식점", "카페" 등으로 분류되어 있음
  return category.includes("음식점") || category.includes("카페");
}

/**
 * HTML 태그 제거
 * @param {string} text HTML이 포함된 텍스트
 * @return {string} 태그가 제거된 텍스트
 */
function removeHtmlTags(text) {
  return text.replace(/<[^>]*>/g, "");
}

/**
 * 네이버 식당 고유 ID 생성
 * @param {string} title 식당명
 * @param {string} address 주소
 * @return {string} 고유 ID
 */
function generateNaverRestaurantId(title, address) {
  const cleanTitle = removeHtmlTags(title);
  const combined = `${cleanTitle}_${address}`.replace(/\s/g, "");
  return Buffer.from(combined).toString("base64")
      .replace(/[+/=]/g, "")
      .substring(0, 20);
}

/**
 * 중복 식당 제거 (전화번호 기준)
 * @param {Array} restaurants 식당 배열
 * @return {Array} 중복 제거된 식당 배열
 */
function removeDuplicateRestaurants(restaurants) {
  const seen = new Set();
  return restaurants.filter((restaurant) => {
    // 전화번호가 있으면 전화번호로, 없으면 이름+주소로 중복 체크
    const key = restaurant.phone ||
        `${restaurant.name}_${restaurant.address}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
}

/**
 * 도시명으로 도/특별시 찾기
 * @param {string} cityName 도시명
 * @return {string} 도/특별시명
 */
function findProvinceByCity(cityName) {
  const provinceMap = {
    "서울시": "서울특별시",
    "부산시": "부산광역시",
    "대구시": "대구광역시",
    "인천시": "인천광역시",
    "광주시": "광주광역시",
    "대전시": "대전광역시",
    "울산시": "울산광역시",
    "세종시": "세종특별자치시",
    "수원시": "경기도",
    "성남시": "경기도",
    "천안시": "충청남도",
    "전주시": "전라북도",
    "청주시": "충청북도",
    "춘천시": "강원특별자치도",
    "제주시": "제주특별자치도",
    "서귀포시": "제주특별자치도",
  };

  return provinceMap[cityName] || "기타";
}

/**
 * Firestore에 식당 데이터 저장
 * @param {Array} restaurants 식당 데이터 배열
 * @return {Promise<number>} 저장된 식당 수
 */
async function saveRestaurantsToFirestore(restaurants) {
  if (restaurants.length === 0) return 0;

  let savedCount = 0;
  const batch = db.batch();

  try {
    for (const restaurant of restaurants) {
      // 고유 ID 생성 (이름 + 주소 해시)
      const uniqueId = generateRestaurantId(
          restaurant.name, restaurant.address);
      const docRef = db.collection("restaurants").doc(uniqueId);

      batch.set(docRef, restaurant, {merge: true});
      savedCount++;

      // 배치 크기 제한 (500개)
      if (savedCount % 500 === 0) {
        await batch.commit();
        logger.info(`💾 ${savedCount}개 식당 저장 완료`);
      }
    }

    // 남은 데이터 커밋
    if (savedCount % 500 !== 0) {
      await batch.commit();
    }

    logger.info(`✅ 총 ${savedCount}개 식당 Firestore 저장 완료`);
    return savedCount;
  } catch (error) {
    logger.error("❌ Firestore 저장 실패:", error);
    throw error;
  }
}

/**
 * 식당 고유 ID 생성
 * @param {string} name 식당명
 * @param {string} address 주소
 * @return {string} 고유 ID
 */
function generateRestaurantId(name, address) {
  const combined = `${name}_${address}`.replace(/\s/g, "");
  return Buffer.from(combined).toString("base64")
      .replace(/[+/=]/g, "")
      .substring(0, 20);
}

// 헬스체크 엔드포인트
exports.healthCheck = onRequest((request, response) => {
  response.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});
