/**
 * 카카오 Place ID 기반 유튜브 맛집 크롤러
 * - 유튜브 언급 횟수 카운팅
 * - 시간 기반 트렌드 분석
 * - 대표 영상 저장
 * - 찐로컬맛집 태그 시스템
 */

const axios = require('axios');
const admin = require('firebase-admin');
const RegionValidator = require('./region_validator');

// 환경변수 로드
require('dotenv').config({ path: '../flutter-app/.env' });

class YouTubePlaceIdCrawler {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    
    // API 키들
    this.youtubeApiKey = process.env.YOUTUBE_API_KEY;
    this.kakaoApiKey = process.env.KAKAO_REST_API_KEY;
    
    if (!this.youtubeApiKey) {
      throw new Error('YouTube API 키가 설정되지 않았습니다. .env 파일을 확인하세요.');
    }
    
    // 현재 날짜
    this.now = new Date();
  }

  /**
   * 지역별 강화된 검색 쿼리
   */
  getEnhancedSearchQueries() {
    return {
      '제주도': [
        '제주도 맛집 추천',
        '제주 현지인 맛집',
        '제주도 꼭가야할 맛집',
        '제주 맛집 투어',
        '제주 찐로컬맛집',
        '제주 현지인만 아는 맛집',
        '제주 숨은맛집',
        '제주 택시기사 추천 맛집',
        '제주 요즘 핫한 맛집',
        '제주도 유명 맛집',
        '제주 흑돼지 맛집',
        '제주 해산물 맛집',
        '제주 갈치조림 맛집',
        '제주 고기국수 맛집',
        '제주시 맛집',
        '서귀포 맛집',
        '제주 애월 맛집',
        '제주 성산 맛집',
        '제주 중문 맛집',
        '제주 한림 맛집'
      ],
      '서울': [
        '서울 맛집 추천', 
        '서울 현지인 맛집',
        '서울 숨은 맛집',
        '서울 찐로컬맛집',
        '서울 동네 맛집',
        '서울 현지인만 아는',
        '서울 2024 신상맛집',
        '서울 요즘 핫플'
      ],
      '부산': [
        '부산 맛집 추천',
        '부산 현지인 맛집', 
        '부산 꼭가야할 맛집',
        '부산 찐로컬맛집',
        '부산 택시기사 추천',
        '부산 2024 신상맛집',
        '부산 요즘 핫한'
      ],
      '경주': [
        '경주 맛집 추천',
        '경주 현지인 맛집',
        '경주 숨은 맛집',
        '경주 찐로컬맛집',
        '경주 황리단길 맛집',
        '경주 2024 신상맛집'
      ]
    };
  }

  /**
   * YouTube API로 영상 검색 (시간 정보 포함)
   */
  async searchYouTubeVideos(searchQuery, maxResults = 20) {
    try {
      console.log(`🔍 YouTube 검색: "${searchQuery}"`);
      
      const apiUrl = 'https://www.googleapis.com/youtube/v3/search';
      
      const response = await axios.get(apiUrl, {
        params: {
          part: 'snippet',
          q: searchQuery,
          type: 'video',
          order: 'relevance',
          maxResults: maxResults,
          key: this.youtubeApiKey,
          regionCode: 'KR',
          relevanceLanguage: 'ko',
          publishedAfter: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000).toISOString() // 최근 1년
        }
      });

      const videos = response.data.items || [];
      console.log(`   ✅ ${videos.length}개 영상 발견`);
      
      // 조회수 정보도 가져오기 위해 추가 API 호출
      const videoIds = videos.map(v => v.id.videoId).join(',');
      const statsResponse = await axios.get('https://www.googleapis.com/youtube/v3/videos', {
        params: {
          part: 'statistics',
          id: videoIds,
          key: this.youtubeApiKey
        }
      });
      
      const statsMap = {};
      statsResponse.data.items.forEach(item => {
        statsMap[item.id] = item.statistics;
      });
      
      return videos.map(video => ({
        videoId: video.id.videoId,
        title: video.snippet.title,
        description: video.snippet.description,
        channelTitle: video.snippet.channelTitle,
        publishedAt: video.snippet.publishedAt,
        thumbnails: video.snippet.thumbnails,
        viewCount: parseInt(statsMap[video.id.videoId]?.viewCount || 0)
      }));
      
    } catch (error) {
      console.error(`❌ 유튜브 검색 오류: ${error.message}`);
      return [];
    }
  }

  /**
   * 영상들에서 식당 정보 추출 및 분석
   */
  analyzeRestaurantMentions(videos, region) {
    const restaurantData = new Map(); // 식당명 -> 데이터
    
    videos.forEach(video => {
      const text = `${video.title} ${video.description}`.toLowerCase();
      
      // 식당 이름 패턴들
      const patterns = [
        /([가-힣]{2,}(?:식당|맛집|횟집|갈비|국밥|해장국|치킨|피자|카페|베이커리))/g,
        /([가-힣]{2,}(?:\s)?(?:본점|지점|분점))/g,
        /([가-힣]{2,}(?:\s)?[가-힣]{1,3}(?:점|관|집))/g,
        /([가-힣]{3,10})/g // 일반 한글 이름
      ];
      
      const foundNames = new Set();
      
      patterns.forEach(pattern => {
        const matches = text.match(pattern) || [];
        matches.forEach(match => {
          const cleaned = match.trim();
          if (this.isValidRestaurantName(cleaned)) {
            foundNames.add(cleaned);
          }
        });
      });
      
      // 발견된 식당들 기록
      foundNames.forEach(name => {
        if (!restaurantData.has(name)) {
          restaurantData.set(name, {
            name: name,
            region: region,
            mentions: [],
            channels: new Set(),
            firstMentionDate: video.publishedAt,
            lastMentionDate: video.publishedAt
          });
        }
        
        const data = restaurantData.get(name);
        data.mentions.push({
          videoId: video.videoId,
          title: video.title,
          channelTitle: video.channelTitle,
          publishedAt: video.publishedAt,
          viewCount: video.viewCount,
          thumbnails: video.thumbnails
        });
        data.channels.add(video.channelTitle);
        
        // 날짜 업데이트
        if (new Date(video.publishedAt) < new Date(data.firstMentionDate)) {
          data.firstMentionDate = video.publishedAt;
        }
        if (new Date(video.publishedAt) > new Date(data.lastMentionDate)) {
          data.lastMentionDate = video.publishedAt;
        }
      });
    });
    
    return restaurantData;
  }

  /**
   * 식당명 유효성 검사
   */
  isValidRestaurantName(name) {
    // 필터링 조건
    if (name.length < 2 || name.length > 15) return false;
    if (!(/[가-힣]/.test(name))) return false;
    
    // 제외 키워드 (더 엄격하게)
    const excludeWords = [
      '추천', '리뷰', '영상', '채널', '맛집', '음식점',
      '식당', '카페', '여행', '관광', '투어', '코스',
      '제주맛집', '서귀포맛집', '제주도맛집', '제주시맛집',
      '서울맛집', '부산맛집', '경주맛집',
      '현지인맛집', '로컬맛집', '숨은맛집',
      '베스트', '탑텐', '순위', '랭킹'
    ];
    
    for (const word of excludeWords) {
      if (name === word || name.includes(word)) return false;
    }
    
    // 지역명 + 맛집 패턴 제외
    const locationTerms = ['제주', '서귀포', '제주시', '애월', '성산', '중문', '한림', '서울', '부산', '경주'];
    for (const location of locationTerms) {
      if (name === `${location}맛집` || name === `${location} 맛집`) {
        return false;
      }
    }
    
    // 일반적인 형용사 + 맛집 패턴 제외
    const adjectives = ['유명', '인기', '핫한', '대박', '찐', '진짜', '최고', '꼭가야할', '가성비'];
    for (const adj of adjectives) {
      if (name.includes(adj) && name.includes('맛집')) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * 카카오 API로 place_id 획득
   */
  async getKakaoPlaceId(restaurantName, region) {
    try {
      const apiUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      
      // 여러 검색 시도
      const searchQueries = [
        `${restaurantName} ${region}`,
        `${restaurantName}`,
        `${region} ${restaurantName} 맛집`
      ];
      
      for (const query of searchQueries) {
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
          // 지역별로 필터링된 결과 찾기
          for (const place of results) {
            const candidateResult = {
              placeId: place.id,
              placeName: place.place_name,
              address: place.address_name,
              roadAddress: place.road_address_name,
              latitude: parseFloat(place.y),
              longitude: parseFloat(place.x),
              phone: place.phone,
              category: place.category_name,
              url: place.place_url
            };
            
            // 지역 검증
            if (RegionValidator.validateRegion(region, candidateResult)) {
              console.log(`   ✅ 지역 검증 통과: ${candidateResult.placeName}`);
              return candidateResult;
            }
            
            // 체인점 예외 허용
            if (RegionValidator.isAllowedException(candidateResult.placeName, region, candidateResult.address)) {
              console.log(`   ⚡ 체인점 예외 허용: ${candidateResult.placeName}`);
              return candidateResult;
            }
          }
          
          // 모든 결과가 지역 검증 실패 시
          console.log(`   ❌ 모든 검색 결과가 지역 검증 실패: ${restaurantName} (${region})`);
        }
        
        await new Promise(resolve => setTimeout(resolve, 500));
      }
      
      return null;
      
    } catch (error) {
      console.error(`❌ 카카오 검색 오류: ${error.message}`);
      return null;
    }
  }

  /**
   * 카카오 이미지 검색
   */
  async getRestaurantImage(restaurantName) {
    try {
      const imageApiUrl = 'https://dapi.kakao.com/v2/search/image';
      
      const response = await axios.get(imageApiUrl, {
        headers: {
          'Authorization': `KakaoAK ${this.kakaoApiKey}`,
        },
        params: {
          query: `${restaurantName} 음식`,
          sort: 'accuracy',
          size: 3
        }
      });

      const documents = response.data.documents || [];
      if (documents.length > 0) {
        return documents[0].thumbnail_url;
      }
      
      return null;
    } catch (error) {
      return null;
    }
  }

  /**
   * 트렌드 점수 계산
   */
  calculateTrendScore(mentions) {
    const threeMonthsAgo = new Date(this.now.getTime() - 90 * 24 * 60 * 60 * 1000);
    const sixMonthsAgo = new Date(this.now.getTime() - 180 * 24 * 60 * 60 * 1000);
    
    let recentMentions = 0;
    let midMentions = 0;
    let totalViewCount = 0;
    
    mentions.forEach(mention => {
      const mentionDate = new Date(mention.publishedAt);
      totalViewCount += mention.viewCount;
      
      if (mentionDate > threeMonthsAgo) {
        recentMentions++;
      } else if (mentionDate > sixMonthsAgo) {
        midMentions++;
      }
    });
    
    // Hotness 계산 (0-100)
    const hotness = Math.min(100, 
      (recentMentions * 20) + 
      (midMentions * 10) + 
      (Math.log10(totalViewCount + 1) * 5)
    );
    
    // Consistency 계산 (꾸준함)
    const monthlyDistribution = this.getMonthlyDistribution(mentions);
    const consistency = Math.min(100, monthlyDistribution.length * 15);
    
    // 상승세 판단
    const isRising = recentMentions > (mentions.length - recentMentions) / 2;
    
    return {
      hotness: Math.round(hotness),
      consistency: Math.round(consistency),
      isRising: isRising,
      recentMentions: recentMentions
    };
  }

  /**
   * 월별 분포 계산
   */
  getMonthlyDistribution(mentions) {
    const monthlyCount = {};
    
    mentions.forEach(mention => {
      const date = new Date(mention.publishedAt);
      const monthKey = `${date.getFullYear()}-${date.getMonth() + 1}`;
      monthlyCount[monthKey] = (monthlyCount[monthKey] || 0) + 1;
    });
    
    return Object.keys(monthlyCount);
  }

  /**
   * 향상된 태그 생성
   */
  generateEnhancedTags(restaurantData, kakaoInfo, trendScore) {
    const tags = [];
    
    // 언급 횟수 기반 태그
    const mentionCount = restaurantData.mentions.length;
    if (mentionCount >= 10) {
      tags.push('#유튜브단골');
    }
    // 10회 미만은 언급 횟수 관련 태그 없음
    
    // 시간 기반 태그
    const firstMention = new Date(restaurantData.firstMentionDate);
    const daysSinceFirst = (this.now - firstMention) / (24 * 60 * 60 * 1000);
    
    if (daysSinceFirst < 90 && trendScore.recentMentions >= 3) {
      tags.push('#최근핫플');
    }
    
    if (trendScore.isRising) {
      tags.push('#요즘대세');
    }
    
    if (daysSinceFirst > 365 && trendScore.consistency > 60) {
      tags.push('#검증된맛집');
    }
    
    if (daysSinceFirst > 730) {
      tags.push('#스테디셀러');
    }
    
    // 로컬 인증 태그
    const text = restaurantData.mentions.map(m => m.title).join(' ');
    if (text.includes('현지인') || text.includes('동네')) {
      tags.push('#현지인단골집');
    }
    if (text.includes('택시기사') || text.includes('택시')) {
      tags.push('#택시기사추천');
    }
    if (text.includes('숨은') || text.includes('모르는')) {
      tags.push('#숨은맛집');
    }
    if (text.includes('찐') || text.includes('로컬')) {
      tags.push('#찐로컬맛집');
    }
    
    // 지역 기반 태그
    if (restaurantData.region === '제주도') {
      tags.push('#제주맛집');
      if (restaurantData.name.includes('흑돼지')) {
        tags.push('#제주흑돼지');
      }
    } else if (restaurantData.region === '서울') {
      tags.push('#서울맛집');
    } else if (restaurantData.region === '부산') {
      tags.push('#부산맛집');
    } else if (restaurantData.region === '경주') {
      tags.push('#경주맛집');
    }
    
    // 카테고리 기반 태그
    if (kakaoInfo?.category) {
      const category = kakaoInfo.category;
      if (category.includes('한식')) tags.push('#한식');
      else if (category.includes('일식')) tags.push('#일식');
      else if (category.includes('중식')) tags.push('#중식');
      else if (category.includes('카페')) tags.push('#카페');
    }
    
    // 중복 제거 및 최대 8개 제한
    return [...new Set(tags)].slice(0, 8);
  }

  /**
   * 대표 영상 선정 (최신 + 인기 조합)
   */
  selectRepresentativeVideo(mentions) {
    // 점수 계산: 조회수 × 최신성
    const scoredMentions = mentions.map(mention => {
      const daysSincePublish = (this.now - new Date(mention.publishedAt)) / (24 * 60 * 60 * 1000);
      const recencyScore = Math.max(0, 365 - daysSincePublish) / 365; // 0~1
      const viewScore = Math.log10(mention.viewCount + 1);
      
      return {
        ...mention,
        score: viewScore * (1 + recencyScore * 0.5)
      };
    });
    
    // 점수순 정렬
    scoredMentions.sort((a, b) => b.score - a.score);
    
    return scoredMentions[0];
  }

  /**
   * 지역별 크롤링 실행
   */
  async crawlRegion(region) {
    console.log(`\n🚀 ${region} 맛집 크롤링 시작...`);
    
    const searchQueries = this.getEnhancedSearchQueries()[region];
    const allVideos = [];
    
    // 모든 검색어로 영상 수집
    for (const query of searchQueries) {
      const videos = await this.searchYouTubeVideos(query, 25); // 영상 수 증가
      allVideos.push(...videos);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    console.log(`📺 총 ${allVideos.length}개 영상 수집 완료`);
    
    // 식당별 언급 분석
    const restaurantMap = this.analyzeRestaurantMentions(allVideos, region);
    console.log(`🍽️ ${restaurantMap.size}개 식당 추출`);
    
    // 언급 횟수순 정렬
    const sortedRestaurants = Array.from(restaurantMap.entries())
      .sort(([,a], [,b]) => b.mentions.length - a.mentions.length)
      .slice(0, 50); // 상위 50개로 확장
    
    const results = [];
    
    // 각 식당별 처리
    for (const [name, data] of sortedRestaurants) {
      console.log(`\n🔍 "${name}" 처리중... (${data.mentions.length}회 언급)`);
      
      // 카카오 API로 place_id 획득
      const kakaoInfo = await this.getKakaoPlaceId(name, region);
      
      if (!kakaoInfo) {
        console.log(`   ❌ 카카오 매칭 실패`);
        continue;
      }
      
      console.log(`   ✅ 카카오 매칭: ${kakaoInfo.placeName} (ID: ${kakaoInfo.placeId})`);
      
      // 이미지 검색
      const imageUrl = await this.getRestaurantImage(kakaoInfo.placeName);
      
      // 트렌드 점수 계산
      const trendScore = this.calculateTrendScore(data.mentions);
      
      // 태그 생성
      const tags = this.generateEnhancedTags(data, kakaoInfo, trendScore);
      
      // 대표 영상 선정
      const representativeVideo = this.selectRepresentativeVideo(data.mentions);
      
      // 결과 구성
      results.push({
        placeId: kakaoInfo.placeId,
        name: kakaoInfo.placeName,
        address: kakaoInfo.address,
        roadAddress: kakaoInfo.roadAddress,
        latitude: kakaoInfo.latitude,
        longitude: kakaoInfo.longitude,
        phone: kakaoInfo.phone,
        category: this.simplifyCategory(kakaoInfo.category),
        kakaoCategory: kakaoInfo.category,
        url: kakaoInfo.url,
        imageUrl: imageUrl,
        
        // 유튜브 통계
        youtubeStats: {
          mentionCount: data.mentions.length,
          channels: Array.from(data.channels),
          firstMentionDate: data.firstMentionDate,
          lastMentionDate: data.lastMentionDate,
          recentMentions: trendScore.recentMentions,
          representativeVideo: {
            title: representativeVideo.title,
            channelName: representativeVideo.channelTitle,
            videoId: representativeVideo.videoId,
            viewCount: representativeVideo.viewCount,
            publishedAt: representativeVideo.publishedAt,
            thumbnailUrl: representativeVideo.thumbnails.medium.url
          }
        },
        
        // 트렌드 정보
        trendScore: trendScore,
        featureTags: tags,
        
        // 메타데이터
        region: region,
        province: this.getProvince(region),
        city: this.getCity(region),
        isActive: true,
        isFeatured: true,
        source: 'youtube_placeid_crawler',
        crawledAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now()
      });
      
      await new Promise(resolve => setTimeout(resolve, 1500));
    }
    
    return results;
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
   * 지역별 도/특별시 매핑
   */
  getProvince(region) {
    const mapping = {
      '제주도': '제주특별자치도',
      '서울': '서울특별시',
      '부산': '부산광역시',
      '경주': '경상북도'
    };
    return mapping[region] || region;
  }

  /**
   * 지역별 도시 매핑
   */
  getCity(region) {
    const mapping = {
      '제주도': '제주시',
      '서울': '서울특별시',
      '부산': '부산광역시',
      '경주': '경주시'
    };
    return mapping[region] || region;
  }

  /**
   * Firestore에 저장 (place_id를 document ID로 사용)
   */
  async saveToFirestore(restaurants) {
    console.log(`\n💾 Firestore에 ${restaurants.length}개 맛집 저장 중...`);
    
    let savedCount = 0;
    let updatedCount = 0;
    
    for (const restaurant of restaurants) {
      try {
        const docRef = this.db.collection('restaurants').doc(restaurant.placeId);
        const doc = await docRef.get();
        
        if (doc.exists) {
          // 기존 데이터가 있으면 병합
          const existingData = doc.data();
          const mergedYoutubeStats = {
            ...restaurant.youtubeStats,
            mentionCount: (existingData.youtubeStats?.mentionCount || 0) + restaurant.youtubeStats.mentionCount,
            channels: [...new Set([
              ...(existingData.youtubeStats?.channels || []),
              ...restaurant.youtubeStats.channels
            ])]
          };
          
          await docRef.set({
            ...restaurant,
            youtubeStats: mergedYoutubeStats,
            updatedAt: admin.firestore.Timestamp.now()
          }, { merge: true });
          
          console.log(`   🔄 업데이트: ${restaurant.name}`);
          updatedCount++;
        } else {
          // 새로운 데이터
          await docRef.set(restaurant);
          console.log(`   ✅ 신규 저장: ${restaurant.name}`);
          savedCount++;
        }
        
      } catch (error) {
        console.error(`❌ 저장 실패 (${restaurant.name}):`, error.message);
      }
    }
    
    console.log(`\n📊 저장 완료: 신규 ${savedCount}개, 업데이트 ${updatedCount}개`);
  }

  /**
   * 전체 크롤링 실행
   */
  async crawlAll() {
    console.log('🎯 카카오 Place ID 기반 유튜브 맛집 크롤링 시작!\n');
    console.log('📋 특징:');
    console.log('   - 유튜브 언급 횟수 카운팅');
    console.log('   - 시간 기반 트렌드 분석');
    console.log('   - 대표 영상 저장');
    console.log('   - 찐로컬맛집 태그 시스템');
    console.log('   - 카카오 place_id를 Document ID로 사용\n');
    
    const regions = ['제주도']; // 제주도만 집중 크롤링
    const allRestaurants = [];
    
    for (const region of regions) {
      const restaurants = await this.crawlRegion(region);
      allRestaurants.push(...restaurants);
      
      // 지역별 저장
      if (restaurants.length > 0) {
        await this.saveToFirestore(restaurants);
      }
      
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    console.log(`\n🎉 전체 크롤링 완료!`);
    console.log(`   📊 총 ${allRestaurants.length}개 맛집 수집`);
    console.log(`   🏷️ 카카오 place_id 기반 중복 제거`);
    console.log(`   ⏰ 시간 기반 트렌드 분석 완료`);
    console.log(`   🎬 대표 유튜브 영상 저장 완료`);
  }
}

// 직접 실행
if (require.main === module) {
  async function run() {
    try {
      const crawler = new YouTubePlaceIdCrawler();
      await crawler.crawlAll();
    } catch (error) {
      console.error('❌ 크롤링 실패:', error.message);
      process.exit(1);
    }
  }
  
  run();
}

module.exports = YouTubePlaceIdCrawler;