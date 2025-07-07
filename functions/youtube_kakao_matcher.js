/**
 * 유튜브 맛집 데이터와 카카오 API 매칭
 * - 기존 DB 맛집들을 카카오 API로 상세 정보 보완
 * - 평점 제거하고 특징 태그 시스템 도입
 */

const axios = require('axios');
const admin = require('firebase-admin');
const SmartMatcher = require('./smart_matcher');

// 환경변수 로드
require('dotenv').config({ path: '../flutter-app/.env' });

class YouTubeKakaoMatcher {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    this.kakaoApiKey = process.env.KAKAO_REST_API_KEY;
  }

  /**
   * 기존 DB에서 모든 맛집 데이터 가져오기
   */
  async getAllRestaurants() {
    try {
      console.log('📋 기존 DB에서 맛집 데이터 로드 중...');
      
      const snapshot = await this.db.collection('restaurants').get();
      const restaurants = [];
      
      snapshot.forEach(doc => {
        const data = doc.data();
        restaurants.push({
          id: doc.id,
          ...data
        });
      });
      
      console.log(`✅ ${restaurants.length}개 맛집 로드 완료`);
      return restaurants;
      
    } catch (error) {
      console.error('❌ DB 로드 오류:', error.message);
      return [];
    }
  }

  /**
   * 카카오 API로 상세 정보 재검색
   */
  async getDetailedKakaoInfo(restaurantName, region) {
    try {
      console.log(`🔍 카카오에서 "${restaurantName}" 상세 검색...`);
      
      const apiUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      
      // 개선된 검색어 전략 (맛집, 식당 같은 일반명사 제거)
      const searchQueries = [
        `${restaurantName}`,
        `${restaurantName} ${region}`,
        `${region} ${restaurantName}` // 지역을 앞에 두는 경우도 시도
      ];
      
      for (const query of searchQueries) {
        try {
          const response = await axios.get(apiUrl, {
            headers: {
              'Authorization': `KakaoAK ${this.kakaoApiKey}`,
            },
            params: {
              query: query,
              category_group_code: 'FD6',
              size: 5,
              sort: 'accuracy'
            }
          });

          const results = response.data.documents || [];
          
          if (results.length > 0) {
            console.log(`   🔍 검색어 "${query}"로 ${results.length}개 결과 발견`);
            
            // 스마트 매칭 알고리즘 적용
            const bestMatch = SmartMatcher.findBestMatch(restaurantName, results, region);
            
            if (bestMatch && SmartMatcher.validateMatch(restaurantName, bestMatch)) {
              console.log(`   ✅ 스마트 매칭 성공: ${bestMatch.place_name} (점수: ${bestMatch.matchScore.toFixed(3)})`);
              
              return {
                placeId: bestMatch.id,
                name: bestMatch.place_name,
                address: bestMatch.address_name,
                roadAddress: bestMatch.road_address_name,
                latitude: parseFloat(bestMatch.y),
                longitude: parseFloat(bestMatch.x),
                phone: bestMatch.phone,
                category: bestMatch.category_name,
                url: bestMatch.place_url,
                searchQuery: query,
                matchScore: bestMatch.matchScore // 매칭 점수 포함
              };
            } else {
              console.log(`   ⚠️ 검색어 "${query}": 적절한 매칭 없음`);
            }
          }
        } catch (searchError) {
          // 다음 검색어 시도
        }
        
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      
      console.log(`   ❌ 카카오에서 찾을 수 없음: ${restaurantName}`);
      return null;
      
    } catch (error) {
      console.error(`❌ 카카오 검색 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 카카오 이미지 검색으로 대표 이미지 찾기
   */
  async getRestaurantImage(restaurantName) {
    try {
      const imageApiUrl = 'https://dapi.kakao.com/v2/search/image';
      
      const searchQueries = [
        `${restaurantName} 음식점`,
        `${restaurantName} 맛집`,
        `${restaurantName} 음식`,
        restaurantName
      ];
      
      for (const searchQuery of searchQueries) {
        try {
          const response = await axios.get(imageApiUrl, {
            headers: {
              'Authorization': `KakaoAK ${this.kakaoApiKey}`,
            },
            params: {
              query: searchQuery,
              sort: 'accuracy',
              size: 5
            }
          });

          const documents = response.data.documents || [];
          if (documents.length > 0) {
            // 가장 적절한 이미지 선택 (음식점/음식 관련)
            const foodImage = documents.find(doc => 
              doc.display_sitename.includes('음식') ||
              doc.display_sitename.includes('맛집') ||
              doc.display_sitename.includes('레스토랑')
            );
            
            const selectedImage = foodImage || documents[0];
            console.log(`   📸 이미지 발견: ${searchQuery}`);
            return selectedImage.thumbnail_url;
          }
        } catch (searchError) {
          // 다음 검색어 시도
        }
        
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      
      return null;
    } catch (error) {
      return null;
    }
  }

  /**
   * 맛집 이름/지역으로 특징 태그 생성
   */
  generateFeatureTags(restaurantName, region, kakaoCategory) {
    const tags = [];
    
    // 지역 기반 태그
    if (region === '제주도') {
      tags.push('#제주특산', '#관광맛집');
      if (restaurantName.includes('해녀') || restaurantName.includes('전복')) {
        tags.push('#제주전통', '#해산물');
      }
      if (restaurantName.includes('흑돼지')) {
        tags.push('#제주흑돼지', '#현지특색');
      }
    } else if (region === '서울') {
      tags.push('#서울맛집');
      if (restaurantName.includes('숨은')) {
        tags.push('#숨은맛집', '#로컬추천');
      }
    } else if (region === '부산') {
      tags.push('#부산맛집', '#바다맛집');
      if (restaurantName.includes('밀면') || restaurantName.includes('돼지국밥')) {
        tags.push('#부산향토음식');
      }
    } else if (region === '경주') {
      tags.push('#경주맛집', '#전통맛집');
      if (restaurantName.includes('황리단길')) {
        tags.push('#핫플레이스', '#요즘핫한');
      }
    }
    
    // 음식 종류 기반 태그
    if (kakaoCategory) {
      if (kakaoCategory.includes('한식')) {
        tags.push('#한식', '#전통음식');
      } else if (kakaoCategory.includes('일식')) {
        tags.push('#일식', '#스시');
      } else if (kakaoCategory.includes('중식')) {
        tags.push('#중식');
      } else if (kakaoCategory.includes('양식')) {
        tags.push('#양식');
      } else if (kakaoCategory.includes('카페')) {
        tags.push('#카페', '#디저트');
      }
    }
    
    // 식당명 기반 태그
    if (restaurantName.includes('본점') || restaurantName.includes('원조')) {
      tags.push('#원조맛집', '#오래된맛집');
    }
    if (restaurantName.includes('여행')) {
      tags.push('#여행맛집', '#관광추천');
    }
    if (restaurantName.includes('현지인') || restaurantName.includes('도민')) {
      tags.push('#현지인추천', '#로컬맛집');
    }
    
    // 기본 태그 추가
    tags.push('#유튜버추천', '#SNS맛집');
    
    // 중복 제거 및 최대 6개로 제한
    const uniqueTags = [...new Set(tags)].slice(0, 6);
    
    return uniqueTags;
  }

  /**
   * 카테고리 간소화
   */
  simplifyCategory(category) {
    if (!category) return '음식점';
    
    if (category.includes('한식')) return '한식';
    if (category.includes('중식')) return '중식';
    if (category.includes('일식')) return '일식';
    if (category.includes('양식')) return '양식';
    if (category.includes('카페')) return '카페';
    if (category.includes('치킨')) return '치킨';
    if (category.includes('피자')) return '피자';
    if (category.includes('분식')) return '분식';
    if (category.includes('회')) return '회/해산물';
    if (category.includes('구이')) return '구이';
    
    return '음식점';
  }

  /**
   * 모든 맛집 데이터 카카오 API와 매칭하여 업데이트
   */
  async matchAllRestaurantsWithKakao() {
    try {
      console.log('🚀 유튜브 맛집 데이터 카카오 API 매칭 시작...\n');
      
      // 1. 기존 맛집 데이터 로드
      const restaurants = await this.getAllRestaurants();
      
      if (restaurants.length === 0) {
        console.log('❌ 매칭할 맛집 데이터가 없습니다.');
        return;
      }
      
      let updatedCount = 0;
      let failedCount = 0;
      
      // 2. 각 맛집별로 카카오 API 매칭
      for (let i = 0; i < restaurants.length; i++) {
        const restaurant = restaurants[i];
        console.log(`\n[${i + 1}/${restaurants.length}] "${restaurant.name}" 매칭 중...`);
        
        try {
          // 카카오에서 상세 정보 재검색
          const kakaoInfo = await this.getDetailedKakaoInfo(restaurant.name, restaurant.region);
          
          if (kakaoInfo) {
            // 이미지 검색
            const imageUrl = await this.getRestaurantImage(kakaoInfo.name);
            
            // 특징 태그 생성
            const featureTags = this.generateFeatureTags(
              kakaoInfo.name, 
              restaurant.region, 
              kakaoInfo.category
            );
            
            // 업데이트할 데이터 구성 (평점 제거, 매칭 점수 추가)
            const updatedData = {
              // 기존 데이터 유지
              youtubeExtracted: restaurant.youtubeExtracted || true,
              source: restaurant.source,
              region: restaurant.region,
              province: restaurant.province,
              city: restaurant.city,
              isActive: true,
              isFeatured: true,
              
              // 카카오 API 최신 정보
              name: kakaoInfo.name,
              address: kakaoInfo.address,
              roadAddress: kakaoInfo.roadAddress,
              latitude: kakaoInfo.latitude,
              longitude: kakaoInfo.longitude,
              phone: kakaoInfo.phone,
              category: this.simplifyCategory(kakaoInfo.category),
              kakaoCategory: kakaoInfo.category,
              url: kakaoInfo.url,
              placeId: kakaoInfo.placeId,
              
              // 이미지 및 특징
              imageUrl: imageUrl,
              featureTags: featureTags,
              
              // 매칭 품질 정보
              matchScore: kakaoInfo.matchScore || 0,
              originalYoutubeName: restaurant.name, // 원래 YouTube에서 추출한 이름 보존
              
              // 메타데이터
              lastKakaoMatched: admin.firestore.Timestamp.now(),
              updatedAt: admin.firestore.Timestamp.now()
            };
            
            // Firestore 업데이트
            await this.db.collection('restaurants').doc(restaurant.id).set(updatedData, { merge: true });
            
            console.log(`   ✅ 업데이트 완료: ${kakaoInfo.name}`);
            console.log(`      원본명: ${restaurant.name} → 매칭명: ${kakaoInfo.name}`);
            console.log(`      매칭점수: ${(kakaoInfo.matchScore || 0).toFixed(3)}`);
            console.log(`      주소: ${kakaoInfo.address}`);
            console.log(`      카테고리: ${this.simplifyCategory(kakaoInfo.category)}`);
            console.log(`      이미지: ${imageUrl ? '✅' : '❌'}`);
            console.log(`      특징: ${featureTags.join(', ')}`);
            
            updatedCount++;
          } else {
            console.log(`   ❌ 카카오 매칭 실패: ${restaurant.name}`);
            failedCount++;
          }
          
          // API 제한 방지
          await new Promise(resolve => setTimeout(resolve, 2000));
          
        } catch (error) {
          console.error(`❌ "${restaurant.name}" 처리 오류:`, error.message);
          failedCount++;
        }
      }
      
      console.log(`\n🎉 카카오 API 매칭 완료!`);
      console.log(`   📊 업데이트 성공: ${updatedCount}개`);
      console.log(`   ❌ 매칭 실패: ${failedCount}개`);
      console.log(`   🏷️ 평점 시스템 → 특징 태그 시스템 전환`);
      console.log(`   📸 이미지 재검색 완료`);
      console.log(`   📍 위치 정보 최신화 완료`);
      
    } catch (error) {
      console.error('❌ 전체 매칭 오류:', error.message);
    }
  }
}

// 직접 실행
if (require.main === module) {
  async function runMatcher() {
    console.log('🚀 유튜브-카카오 맛집 데이터 매칭 시작...\n');
    console.log('📝 작업 내용:');
    console.log('   - 기존 17개 맛집 데이터 로드');
    console.log('   - 카카오 API로 상세 정보 재검색');
    console.log('   - 평점 시스템 제거');
    console.log('   - 특징 태그 시스템 도입');
    console.log('   - 이미지 재검색 및 위치 정보 최신화\n');
    
    const matcher = new YouTubeKakaoMatcher();
    await matcher.matchAllRestaurantsWithKakao();
  }
  
  runMatcher().catch(console.error);
}

module.exports = YouTubeKakaoMatcher;