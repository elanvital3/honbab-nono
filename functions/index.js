/**
 * 혼밥노노 Firebase Functions
 * 카카오 ID 기반 Custom Token 인증 및 식당 데이터 자동 업데이트 시스템
 */

const {onCall} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule: onScheduleV2} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");

// Firebase Admin 초기화 (서비스 계정 명시적 지정)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'honbab-nono'
});
const db = admin.firestore();
const messaging = admin.messaging();

// TODO: 사용자 삭제 시 관련 데이터 정리는 추후 구현
// Firebase Functions v2에서 beforeUserDeleted 지원 확인 필요

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

/**
 * 실제 크로스 디바이스 FCM 메시지 발송
 * Firebase Admin SDK를 사용해 실제 FCM 서버로 메시지 전송
 */
exports.sendFCMMessage = onCall(async (request) => {
  const data = request.data;
  
  // 입력 검증
  if (!data.targetToken || !data.title || !data.body) {
    throw new Error('targetToken, title, body are required');
  }

  try {
    const message = {
      token: data.targetToken,
      notification: {
        title: data.title,
        body: data.body,
        imageUrl: data.imageUrl || undefined,
      },
      data: {
        type: data.type || 'general',
        meetingId: data.meetingId || '',
        clickAction: data.clickAction || '',
        ...data.customData || {}
      },
      android: {
        notification: {
          icon: 'ic_launcher',
          color: '#D2B48C', // 베이지 컬러
          sound: 'default',
          channelId: data.channelId || 'default',
        },
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    
    logger.info('✅ FCM 메시지 발송 성공:', {
      targetToken: data.targetToken.substring(0, 20) + '...',
      title: data.title,
      messageId: response
    });

    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    logger.error('❌ FCM 메시지 발송 실패:', error);
    throw new Error(`FCM send failed: ${error.message}`);
  }
});

/**
 * 여러 기기에 FCM 메시지 일괄 발송 (멀티캐스트)
 */
exports.sendFCMMulticast = onCall(async (request) => {
  const data = request.data;
  
  // 입력 검증
  if (!data.tokens || !Array.isArray(data.tokens) || data.tokens.length === 0) {
    throw new Error('tokens array is required and must not be empty');
  }
  
  if (!data.title || !data.body) {
    throw new Error('title and body are required');
  }

  try {
    const message = {
      tokens: data.tokens,
      notification: {
        title: data.title,
        body: data.body,
        imageUrl: data.imageUrl || undefined,
      },
      data: {
        type: data.type || 'general',
        meetingId: data.meetingId || '',
        clickAction: data.clickAction || '',
        ...data.customData || {}
      },
      android: {
        notification: {
          icon: 'ic_launcher',
          color: '#D2B48C',
          sound: 'default',
          channelId: data.channelId || 'default',
        },
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    
    logger.info('✅ FCM 멀티캐스트 발송 완료:', {
      totalTokens: data.tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      title: data.title
    });

    // 실패한 토큰들 로깅
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.warn(`❌ 토큰 ${idx} 발송 실패:`, resp.error?.message);
        }
      });
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses,
      timestamp: new Date().toISOString()
    };

  } catch (error) {
    logger.error('❌ FCM 멀티캐스트 발송 실패:', error);
    throw new Error(`FCM multicast failed: ${error.message}`);
  }
});

/**
 * 모임 관련 FCM 알림 자동 발송
 * 모임 생성, 참여자 변경, 채팅 메시지 등
 */
exports.sendMeetingNotification = onCall(async (request) => {
  const data = request.data;
  
  // 입력 검증
  if (!data.meetingId || !data.notificationType) {
    throw new Error('meetingId and notificationType are required');
  }

  try {
    // 모임 정보 조회
    const meetingDoc = await db.collection('meetings').doc(data.meetingId).get();
    if (!meetingDoc.exists) {
      throw new Error('Meeting not found');
    }
    
    const meeting = meetingDoc.data();
    const participantIds = meeting.participantIds || [];
    
    // 참여자들의 FCM 토큰 수집 (채팅 알림 스마트 필터링 포함)
    const tokens = [];
    const userPromises = participantIds.map(async (userId) => {
      if (userId === data.excludeUserId) return; // 발송자 제외
      
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        
        // 채팅 메시지 알림의 경우: 현재 해당 채팅방에 있는 사용자는 제외
        if (data.notificationType === 'chat_message') {
          const currentChatRoom = userData.currentChatRoom;
          // 사용자가 현재 이 모임의 채팅방에 있으면 알림 발송 안 함
          if (currentChatRoom === data.meetingId) {
            logger.info(`📵 채팅방 활성 사용자 알림 제외: ${userId}`);
            return;
          }
        }
        
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      }
    });
    
    await Promise.all(userPromises);
    
    if (tokens.length === 0) {
      logger.info('📭 발송할 FCM 토큰이 없습니다');
      return { success: true, message: 'No tokens to send' };
    }

    // 알림 타입별 메시지 생성
    let title, body, notificationData;
    
    switch (data.notificationType) {
      case 'new_meeting':
        title = '🍽️ 새로운 모임이 생성되었어요!';
        body = `${meeting.restaurantName || meeting.location}에서 함께 식사하실래요?`;
        notificationData = {
          type: 'new_meeting',
          meetingId: data.meetingId,
          clickAction: 'MEETING_DETAIL',
          channelId: 'new_meeting'
        };
        break;
        
      case 'chat_message':
        title = meeting.description || '모임 채팅';
        body = `${data.senderName}: ${data.message}`;
        notificationData = {
          type: 'chat_message',
          meetingId: data.meetingId,
          clickAction: 'CHAT_ROOM',
          channelId: 'chat_message'
        };
        break;
        
      case 'participant_update':
        title = '새로운 참여자';
        body = data.message || '새로운 참여자가 모임에 참여했습니다.';
        notificationData = {
          type: 'participant_update',
          meetingId: data.meetingId,
          clickAction: 'MEETING_DETAIL',
          channelId: 'participant_update'
        };
        break;
        
      case 'participant_left':
        title = '참여자 변동';
        body = data.message || '참여자가 모임에서 나가셨습니다.';
        notificationData = {
          type: 'participant_left',
          meetingId: data.meetingId,
          clickAction: 'MEETING_DETAIL',
          channelId: 'participant_update'
        };
        break;
        
      default:
        throw new Error(`Unknown notification type: ${data.notificationType}`);
    }

    // FCM 멀티캐스트 발송
    const result = await exports.sendFCMMulticast.handler({
      data: {
        tokens: tokens,
        title: title,
        body: body,
        ...notificationData
      }
    });

    logger.info(`✅ 모임 알림 발송 완료 (${data.notificationType}):`, {
      meetingId: data.meetingId,
      recipientCount: tokens.length,
      successCount: result.successCount
    });

    return result;

  } catch (error) {
    logger.error('❌ 모임 알림 발송 실패:', error);
    throw new Error(`Meeting notification failed: ${error.message}`);
  }
});

/**
 * 모든 Firebase Auth 사용자 삭제 (개발/테스트용)
 * ⚠️ 주의: 이 함수는 모든 사용자를 삭제합니다!
 */
exports.deleteAllAuthUsers = onCall(async (request) => {
  try {
    logger.info('🧹 모든 Firebase Auth 사용자 삭제 시작');
    
    let deletedCount = 0;
    let nextPageToken;
    
    // 페이지네이션으로 모든 사용자 조회 및 삭제
    do {
      const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
      
      if (listUsersResult.users.length === 0) {
        break;
      }
      
      // 사용자 UID 목록 생성
      const uids = listUsersResult.users.map(user => user.uid);
      
      logger.info(`📝 ${uids.length}명의 사용자 삭제 중...`);
      
      // 배치로 사용자 삭제
      const deleteResult = await admin.auth().deleteUsers(uids);
      
      deletedCount += deleteResult.successCount;
      
      if (deleteResult.failureCount > 0) {
        logger.warn(`⚠️ ${deleteResult.failureCount}명 삭제 실패`);
        deleteResult.errors.forEach(error => {
          logger.error(`❌ 사용자 삭제 실패: ${error.error.code} - ${error.error.message}`);
        });
      }
      
      nextPageToken = listUsersResult.pageToken;
      
    } while (nextPageToken);
    
    logger.info(`✅ Firebase Auth 사용자 삭제 완료: ${deletedCount}명`);
    
    return {
      success: true,
      deletedCount: deletedCount,
      message: `총 ${deletedCount}명의 사용자가 삭제되었습니다.`,
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    logger.error('❌ Firebase Auth 사용자 삭제 실패:', error);
    throw new Error(`Auth 사용자 삭제 실패: ${error.message}`);
  }
});

/**
 * FCM 푸시 알림 발송 함수
 * Flutter 앱에서 직접 호출하여 다른 사용자에게 푸시 알림을 보낼 수 있음
 */
exports.sendNotification = onCall(async (request) => {
  const data = request.data;
  const auth = request.auth;
  
  // 인증 확인
  if (!auth) {
    throw new Error('인증되지 않은 요청입니다.');
  }
  
  // 필수 파라미터 검증
  if (!data.token || !data.title || !data.body) {
    throw new Error('token, title, body는 필수 항목입니다.');
  }
  
  try {
    // FCM 메시지 구성
    const message = {
      token: data.token,
      notification: {
        title: data.title,
        body: data.body,
      },
      data: data.data || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          priority: 'high',
          channelId: data.channelId || 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: data.title,
              body: data.body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };
    
    // FCM 메시지 발송
    const response = await messaging.send(message);
    
    logger.info(`✅ FCM 알림 발송 성공: ${response}`);
    logger.info(`📱 수신자 토큰: ${data.token.substring(0, 20)}...`);
    logger.info(`📝 제목: ${data.title}`);
    
    return {
      success: true,
      messageId: response,
      timestamp: new Date().toISOString(),
    };
    
  } catch (error) {
    logger.error('❌ FCM 알림 발송 실패:', error);
    
    // 에러 타입에 따른 처리
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      throw new Error('유효하지 않은 FCM 토큰입니다.');
    }
    
    throw new Error(`알림 발송 실패: ${error.message}`);
  }
});

/**
 * 모임 자동 완료 알림 스케줄러
 * 🧪 테스트용: 매 2분마다 실행 (원래: 30분)
 */
exports.checkMeetingAutoCompletion = onScheduleV2({
  schedule: 'every 2 minutes',
  timeZone: 'Asia/Seoul',
}, async (event) => {
  logger.info('🔔 모임 자동 완료 알림 체크 시작');
  
  try {
    const now = admin.firestore.Timestamp.now();
    // 🧪 테스트용: 5분 후까지 (원래: 2시간 후까지)
    const fiveMinutesAfter = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 5 * 60 * 1000)
    );
    
    // status가 active인 모든 모임 조회 후 시간 필터링 (인덱스 불필요)
    const meetingsSnapshot = await db.collection('meetings')
      .where('status', '==', 'active')
      .get();
    
    if (meetingsSnapshot.empty) {
      logger.info('📝 완료 알림이 필요한 모임이 없습니다');
      return;
    }
    
    // 시간 필터링: 5분이 지난 모임들만 필터링
    const eligibleMeetings = [];
    for (const doc of meetingsSnapshot.docs) {
      const meeting = doc.data();
      const meetingTime = meeting.dateTime.toDate();
      const autoCompleteTime = new Date(meetingTime.getTime() + 5 * 60 * 1000);
      
      if (new Date() >= autoCompleteTime) {
        eligibleMeetings.push({ doc, meeting });
      }
    }
    
    if (eligibleMeetings.length === 0) {
      logger.info('📝 5분이 지난 모임이 없습니다');
      return;
    }
    
    logger.info(`📋 총 ${eligibleMeetings.length}개 모임 자동완료 체크 중...`);
    
    let sentCount = 0;
    
    for (const { doc, meeting } of eligibleMeetings) {
      const meetingId = doc.id;
      
      // 이미 알림을 보냈는지 확인 (중복 방지)
      const notificationKey = `auto_complete_${meetingId}`;
      const existingNotification = await db.collection('meeting_notifications')
        .doc(notificationKey)
        .get();
      
      if (existingNotification.exists) {
        continue; // 이미 알림 보냄
      }
      
      // 호스트 정보 조회
      const hostSnapshot = await db.collection('users')
        .doc(meeting.hostId)
        .get();
      
      if (!hostSnapshot.exists) {
        logger.warn(`❌ 호스트 정보를 찾을 수 없습니다: ${meeting.hostId}`);
        continue;
      }
      
      const host = hostSnapshot.data();
      if (!host.fcmToken) {
        logger.warn(`❌ 호스트 FCM 토큰이 없습니다: ${meeting.hostId}`);
        continue;
      }
      
      // FCM 알림 발송
      const message = {
        token: host.fcmToken,
        notification: {
          title: '모임 완료 확인',
          body: `"${meeting.restaurantName || meeting.location}" 모임이 완료되었나요? 완료 처리를 해주세요 🍽️`,
        },
        data: {
          type: 'meeting_auto_complete',
          meetingId: meetingId,
          meetingName: meeting.restaurantName || meeting.location,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            channelId: 'meeting_notifications',
            priority: 'high',
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: '모임 완료 확인',
                body: `"${meeting.restaurantName || meeting.location}" 모임이 완료되었나요? 완료 처리를 해주세요 🍽️`,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      try {
        const response = await messaging.send(message);
        logger.info(`✅ 모임 완료 알림 발송 성공: ${meetingId} -> ${host.name}`);
        
        // 알림 발송 기록 저장 (중복 방지용)
        await db.collection('meeting_notifications').doc(notificationKey).set({
          meetingId: meetingId,
          hostId: meeting.hostId,
          type: 'auto_complete',
          sentAt: admin.firestore.Timestamp.now(),
          messageId: response,
        });
        
        sentCount++;
      } catch (error) {
        logger.error(`❌ 모임 완료 알림 발송 실패: ${meetingId}`, error);
      }
    }
    
    logger.info(`🎉 모임 자동 완료 알림 체크 완료 - 총 ${sentCount}개 알림 발송`);
    
  } catch (error) {
    logger.error('❌ 모임 자동 완료 알림 체크 실패:', error);
  }
});

/**
 * 모임 생성 시 자동 완료 알림 스케줄 등록
 * 클라이언트에서 호출하는 Callable Function
 */
exports.scheduleMeetingAutoCompletion = onCall(async (request) => {
  const data = request.data;
  
  if (!data.meetingId || !data.dateTime) {
    throw new Error('meetingId와 dateTime이 필요합니다');
  }
  
  try {
    // 이미 등록된 스케줄이 있는지 확인
    const scheduleKey = `auto_complete_schedule_${data.meetingId}`;
    const existingSchedule = await db.collection('meeting_schedules')
      .doc(scheduleKey)
      .get();
    
    if (existingSchedule.exists) {
      logger.info(`⏰ 이미 등록된 스케줄: ${data.meetingId}`);
      return { success: true, message: '이미 등록된 스케줄입니다' };
    }
    
    // 모임 시간 + 2시간 후 시간 계산
    const meetingTime = new Date(data.dateTime);
    const autoCompleteTime = new Date(meetingTime.getTime() + 2 * 60 * 60 * 1000);
    
    // 스케줄 정보 저장
    await db.collection('meeting_schedules').doc(scheduleKey).set({
      meetingId: data.meetingId,
      meetingTime: admin.firestore.Timestamp.fromDate(meetingTime),
      autoCompleteTime: admin.firestore.Timestamp.fromDate(autoCompleteTime),
      createdAt: admin.firestore.Timestamp.now(),
      processed: false,
    });
    
    logger.info(`✅ 모임 자동 완료 스케줄 등록: ${data.meetingId} -> ${autoCompleteTime.toISOString()}`);
    
    return {
      success: true,
      meetingId: data.meetingId,
      autoCompleteTime: autoCompleteTime.toISOString(),
    };
    
  } catch (error) {
    logger.error('❌ 모임 자동 완료 스케줄 등록 실패:', error);
    throw new Error(`스케줄 등록 실패: ${error.message}`);
  }
});

// 헬스체크 엔드포인트
exports.healthCheck = onRequest((request, response) => {
  response.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});
