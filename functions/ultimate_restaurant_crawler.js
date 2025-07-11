/**
 * 🍽️ Ultimate Restaurant Crawler
 * 
 * 통합 맛집 데이터 수집 시스템 - 최신 개선 버전
 * - YouTube 맛집 크롤링 (지역별 강화된 검색)
 * - 카카오 Place ID 매칭 및 상세 정보
 * - Google Places API 연동 (사진, 영업시간, 리뷰)
 * - 네이버 블로그 데이터 추가
 * - 스마트 매칭 시스템 (한국어 최적화)
 * - 지역 검증 및 필터링
 * 
 * 사용법: node ultimate_restaurant_crawler.js
 */

const axios = require('axios');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// 환경변수 로드
require('dotenv').config({ path: '../flutter-app/.env' });

// =============================================================================
// 🔧 설정 및 초기화
// =============================================================================

class UltimateRestaurantCrawler {
  constructor() {
    // Firebase 초기화
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: 'honbab-nono'
      });
    }
    this.db = admin.firestore();
    
    // API 키들 - 로테이션 지원
    this.kakaoApiKey = process.env.KAKAO_REST_API_KEY;
    
    // YouTube API 키 로테이션 시스템
    this.youtubeApiKeys = [
      process.env.YOUTUBE_API_KEY,
      process.env.YOUTUBE_API_KEY_2,
      process.env.YOUTUBE_API_KEY_3
    ].filter(key => key); // null/undefined 제거
    
    this.currentYoutubeKeyIndex = 0;
    this.youtubeApiKey = this.youtubeApiKeys[0]; // 기본 키
    
    // Google Places API 키 로테이션 시스템
    this.googleApiKeys = [
      process.env.GOOGLE_PLACES_API_KEY,
      process.env.GOOGLE_PLACES_API_KEY_2,
      process.env.GOOGLE_PLACES_API_KEY_3
    ].filter(key => key); // null/undefined 제거
    
    this.currentGoogleKeyIndex = 0;
    this.googleApiKey = this.googleApiKeys[0]; // 기본 키
    
    this.naverClientId = process.env.NAVER_CLIENT_ID;
    this.naverSecret = process.env.NAVER_CLIENT_SECRET;
    
    // 필수 API 키 확인
    if (this.youtubeApiKeys.length === 0 || !this.kakaoApiKey || this.googleApiKeys.length === 0) {
      throw new Error('필수 API 키가 누락되었습니다. .env 파일을 확인하세요.');
    }
    
    // 로깅 시스템 초기화
    this.initializeLogging();
    
    this.log(`🔑 YouTube API 키 ${this.youtubeApiKeys.length}개 로드됨`);
    this.log(`🔑 Google Places API 키 ${this.googleApiKeys.length}개 로드됨`);
    
    this.now = new Date();
    this.stats = {
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
  }

  // =============================================================================
  // 📝 로깅 시스템
  // =============================================================================

  /**
   * 로깅 시스템 초기화
   */
  initializeLogging() {
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const timeStr = now.toTimeString().split(' ')[0].replace(/:/g, '-'); // HH-MM-SS
    
    this.logFileName = `crawler_${dateStr}_${timeStr}.log`;
    this.logFilePath = path.join(__dirname, 'logs', this.logFileName);
    
    // logs 디렉토리 생성
    const logsDir = path.dirname(this.logFilePath);
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }
    
    // 로그 파일 생성 및 헤더 작성
    const header = `[${now.toISOString()}] 🍽️ Ultimate Restaurant Crawler 시작\n` +
                  `로그 파일: ${this.logFileName}\n` +
                  `===========================================\n\n`;
    
    fs.writeFileSync(this.logFilePath, header, 'utf8');
    console.log(`📝 로그 파일 생성: ${this.logFilePath}`);
  }

  /**
   * 통합 로깅 함수 (콘솔 + 파일)
   */
  log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logLine = `[${timestamp}] [${level}] ${message}\n`;
    
    // 콘솔 출력
    console.log(message);
    
    // 파일 저장
    try {
      fs.appendFileSync(this.logFilePath, logLine, 'utf8');
    } catch (error) {
      console.error('로그 파일 쓰기 실패:', error);
    }
  }

  /**
   * 에러 로깅
   */
  logError(message, error = null) {
    let errorMessage = message;
    if (error) {
      errorMessage += ` - ${error.message}`;
      if (error.stack) {
        errorMessage += `\n스택 트레이스: ${error.stack}`;
      }
    }
    this.log(errorMessage, 'ERROR');
  }

  /**
   * 성공 로깅
   */
  logSuccess(message) {
    this.log(message, 'SUCCESS');
  }

  /**
   * 워닝 로깅
   */
  logWarning(message) {
    this.log(message, 'WARNING');
  }

  // =============================================================================
  // 🔑 API 키 로테이션 시스템
  // =============================================================================

  /**
   * YouTube API 키 로테이션 (403 에러 시 다음 키로 교체)
   */
  rotateYoutubeApiKey() {
    if (this.youtubeApiKeys.length <= 1) {
      this.logError('❌ 더 이상 사용할 YouTube API 키가 없습니다.');
      return false;
    }
    
    this.currentYoutubeKeyIndex = (this.currentYoutubeKeyIndex + 1) % this.youtubeApiKeys.length;
    this.youtubeApiKey = this.youtubeApiKeys[this.currentYoutubeKeyIndex];
    
    this.logWarning(`🔄 YouTube API 키 교체: ${this.currentYoutubeKeyIndex + 1}/${this.youtubeApiKeys.length}`);
    return true;
  }

  /**
   * Google Places API 키 로테이션 (403 에러 시 다음 키로 교체)
   */
  rotateGoogleApiKey() {
    if (this.googleApiKeys.length <= 1) {
      this.logError('❌ 더 이상 사용할 Google Places API 키가 없습니다.');
      return false;
    }
    
    this.currentGoogleKeyIndex = (this.currentGoogleKeyIndex + 1) % this.googleApiKeys.length;
    this.googleApiKey = this.googleApiKeys[this.currentGoogleKeyIndex];
    
    this.logWarning(`🔄 Google Places API 키 교체: ${this.currentGoogleKeyIndex + 1}/${this.googleApiKeys.length}`);
    return true;
  }

  /**
   * API 키 상태 확인 및 자동 로테이션 (YouTube용)
   */
  async checkAndRotateYoutubeKey(error) {
    if (error.response?.status === 403 || error.code === 403 || error.message.includes('quotaExceeded')) {
      console.log('⚠️ YouTube API 할당량 초과 감지');
      
      if (this.rotateYoutubeApiKey()) {
        console.log('✅ 새 YouTube API 키로 재시도 가능');
        return true;
      } else {
        console.log('❌ 모든 YouTube API 키 할당량 소진됨');
        return false;
      }
    }
    return false;
  }

  /**
   * API 키 상태 확인 및 자동 로테이션 (Google Places용)
   */
  async checkAndRotateGoogleKey(error) {
    if (error.response?.status === 403 || error.code === 403) {
      console.log('⚠️ Google Places API 할당량 초과 감지');
      
      if (this.rotateGoogleApiKey()) {
        console.log('✅ 새 Google Places API 키로 재시도 가능');
        return true;
      } else {
        console.log('❌ 모든 Google Places API 키 할당량 소진됨');
        return false;
      }
    }
    return false;
  }

  // =============================================================================
  // 🔍 지역별 강화된 검색 시스템
  // =============================================================================

  /**
   * 지역별 강화된 검색 쿼리 (세분화된 버전)
   */
  getEnhancedSearchQueries() {
    return {
      '제주도': [
        // 제주시 세분화 검색
        '제주시 맛집 추천',
        '제주시 현지인 맛집',
        '제주시 찐로컬맛집',
        '제주시 숨은맛집',
        '제주시 흑돼지 맛집',
        '제주시 해산물 맛집',
        '제주시 고기국수 맛집',
        '제주시 카페',
        
        // 서귀포시 세분화 검색
        '서귀포시 맛집 추천',
        '서귀포시 현지인 맛집',
        '서귀포시 찐로컬맛집',
        '서귀포시 해산물 맛집',
        '서귀포시 흑돼지 맛집',
        '서귀포시 카페',
        
        // 구체적 지역 검색
        '성산 맛집', 
        '애월 맛집',
        '중문 맛집',
        '한림 맛집',
        '조천 맛집'
      ],
      '서울': [
        // 전체 서울 검색
        '서울 맛집 추천', 
        '서울 현지인 맛집',
        '서울 숨은 맛집',
        '서울 찐로컬맛집',
        
        // 세분화된 지역별 검색
        '홍대 맛집 추천',
        '홍대 현지인 맛집',
        '강남 맛집 추천', 
        '강남 현지인 맛집',
        '명동 맛집 추천',
        '명동 현지인 맛집',
        '이태원 맛집 추천',
        '이태원 현지인 맛집',
        '인사동 맛집 추천',
        '인사동 현지인 맛집',
        '동대문 맛집 추천',
        '동대문 현지인 맛집'
      ],
      '부산': [
        // 전체 부산 검색
        '부산 맛집 추천',
        '부산 현지인 맛집', 
        '부산 꼭가야할 맛집',
        '부산 찐로컬맛집',
        
        // 세분화된 지역별 검색
        '해운대 맛집 추천',
        '해운대 현지인 맛집',
        '서면 맛집 추천',
        '서면 현지인 맛집', 
        '광안리 맛집 추천',
        '광안리 현지인 맛집',
        '남포동 맛집 추천',
        '남포동 현지인 맛집',
        '송정 맛집 추천',
        '송정 현지인 맛집',
        '기장 맛집 추천',
        '기장 현지인 맛집'
      ]
    };
  }

  /**
   * 현재 타겟 지역 설정
   */
  getTargetRegions() {
    return ['서울']; // 서울만 수집
    // return ['제주도', '서울', '부산']; // 전체 지역 (주석 처리)
  }

  /**
   * 지역별 세부 지역 정보 (Google Places 검색용)
   */
  getSubRegions(region) {
    const subRegionMap = {
      '제주도': [
        '제주시',
        '서귀포시'
      ],
      '서울': [
        '홍대',
        '강남',
        '명동', 
        '이태원',
        '인사동',
        '동대문'
      ],
      '부산': [
        '해운대',
        '서면',
        '광안리',
        '남포동',
        '송정',
        '기장'
      ]
    };
    
    return subRegionMap[region] || [region];
  }

  // =============================================================================
  // 🎥 YouTube 데이터 수집
  // =============================================================================

  /**
   * YouTube API로 영상 검색 (재시도 로직 포함)
   */
  async searchYouTubeVideos(searchQuery, maxResults = 5, retryCount = 0) {
    try {
      console.log(`🔍 YouTube 검색: "${searchQuery}"`);
      
      const response = await axios.get('https://www.googleapis.com/youtube/v3/search', {
        params: {
          part: 'snippet',
          q: searchQuery,
          type: 'video',
          maxResults: maxResults,
          order: 'relevance',
          key: this.youtubeApiKey,
          regionCode: 'KR',
          relevanceLanguage: 'ko',
          // 숏츠 포함: 짧은 영상도 검색 결과에 포함
          videoDuration: 'any' // short, medium, long, any (기본값은 any이지만 명시적으로 설정)
        }
      });

      if (response.data.items) {
        this.stats.youtubeVideos += response.data.items.length;
        console.log(`   ✅ ${response.data.items.length}개 영상 찾음`);
        
        // 각 영상의 전체 설명을 가져오기 위해 Videos API 호출
        const videoIds = response.data.items.map(item => item.id.videoId).join(',');
        const detailsResponse = await axios.get('https://www.googleapis.com/youtube/v3/videos', {
          params: {
            part: 'snippet',
            id: videoIds,
            key: this.youtubeApiKey
          }
        });
        
        // Search API 결과에 전체 설명 덮어쓰기
        if (detailsResponse.data.items) {
          response.data.items.forEach((searchItem, index) => {
            const detailItem = detailsResponse.data.items.find(d => d.id === searchItem.id.videoId);
            if (detailItem) {
              searchItem.snippet.description = detailItem.snippet.description || '';
            }
          });
        }
        
        return response.data.items;
      }
      
      return [];
    } catch (error) {
      // 403 에러 시 YouTube API 키 로테이션 및 재시도
      if ((error.response?.status === 403 || error.message.includes('quotaExceeded')) && retryCount < this.youtubeApiKeys.length - 1) {
        console.log(`⚠️ YouTube API 할당량 초과 (키 ${this.currentYoutubeKeyIndex + 1}/${this.youtubeApiKeys.length})`);
        
        if (await this.checkAndRotateYoutubeKey(error)) {
          console.log(`🔄 YouTube API 키 교체 후 재시도 중... (${retryCount + 1}회차)`);
          await new Promise(resolve => setTimeout(resolve, 1000)); // 1초 대기
          return this.searchYouTubeVideos(searchQuery, maxResults, retryCount + 1);
        }
      }
      
      console.error(`❌ YouTube 검색 실패: ${error.message}`);
      this.stats.errors++;
      return [];
    }
  }

  /**
   * 영상 제목에서 식당명 추출 (정교한 정확도 우선 버전)
   */
  extractRestaurantNames(videos) {
    const restaurantNames = new Set();
    
    videos.forEach(video => {
      const title = video.snippet.title;
      const description = video.snippet.description || '';
      
      console.log(`   🔍 분석 중: "${title}"`);
      
      // 전체 텍스트 준비
      const allText = `${title} ${description}`;
      
      // 🔍 전체 텍스트 로그 출력 (디버깅용)
      console.log(`   📝 전체 텍스트:\n${allText}\n   ---`);
      
      // 1차: 해시태그에서 정확한 식당명만 추출
      const hashtagMatches = title.match(/#([가-힣]+)/g) || [];
      hashtagMatches.forEach(hashtag => {
        const name = hashtag.replace('#', '').trim();
        if (this.isExactRestaurantName(name)) {
          restaurantNames.add(name);
          console.log(`     ✅ 해시태그에서 추출: ${name}`);
        }
      });
      
      // 2차: 따옴표나 브래킷 안의 식당명 추출 (가장 확실한 경우)
      const bracketPatterns = [
        /[『「『】【】\(\)\[\]]([가-힣]{2,8}(?:김밥|국수|국밥|갈비|횟집|식당|카페|베이커리|돈까스|치킨))[』」』】【】\(\)\[\]]/g,
        /[""'']([가-힣]{2,8}(?:김밥|국수|국밥|갈비|횟집|식당|카페|베이커리|돈까스|치킨))[""'']/g
      ];
      bracketPatterns.forEach(pattern => {
        const matches = allText.match(pattern) || [];
        matches.forEach(match => {
          const extracted = match.replace(/[『「『】【】\(\)\[\]""'']/g, '').trim();
          console.log(`     🔍 괄호 매치: "${extracted}" → 검증 결과: ${this.isExactRestaurantName(extracted)}`);
          if (this.isExactRestaurantName(extracted)) {
            restaurantNames.add(extracted);
            console.log(`     ✅ 따옴표/괄호에서 추출: ${extracted}`);
          }
        });
      });
      
      // 3차: 실제 YouTube 설명에서 자주 나타나는 패턴들 (단순하고 정확한 패턴)
      const specificPatterns = [
        // "상호 : 가시아방국수" 형태
        /상호\s*:\s*([가-힣]{2,10})/g,
        
        // "1위 가시아방국수", "BEST 1) 금돈가" 형태
        /(?:\d+위|\d+\)|BEST\s*\d+\))\s*([가-힣]{2,10})/g,
        
        // "1. 금돈가", "2. 문개항아리" 형태 (리스트)
        /\d+\.\s*([가-힣]{2,10})/g,
        
        // "▶ 모들한상", "✅ 상희식당" 형태
        /[▶►✅✔☑🔸🔹]\s*([가-힣]{2,10})/g,
        
        // "📍 비밀역", "📌 한림오젠" 형태 (위치 표시)
        /[📍📌]\s*([가-힣]{2,10})/g,
        
        // "가시아방국수 :", "모들한상:" 형태 (콜론 앞)
        /([가-힣]{2,10})\s*:/g,
        
        // "가시아방국수 (", "부촌(" 형태 (괄호 앞) - 더 제한적, 식당 관련 단어만
        /([가-힣]{2,6}(?:김밥|국수|국밥|갈비|치킨|식당|카페|베이커리|돈까스|횟집|회집|숯불|구이|전골|찜|탕|반점|중국집|일식집|양식집|생선|고기|바베큐|피자|떡볶이|순대|족발|보쌈|찜닭|감자탕|해장국|순두부|칼국수|냉면|비빔밥|덮밥|정식|한식|중식|일식|양식|분식|뷔페|도시락|레스토랑|요리|쿡|키친|다이닝|가든|하우스|스토어|타운|플레이스|룸|클럽|라운지|펍|바))\s*\(/g,
        
        // "이곳은 금돈가", "여기는 문개항아리" 형태
        /(?:이곳은|여기는|바로)\s+([가-힣]{2,10})/g,
        
        // 기본적인 식당명 + 메뉴 조합
        /([가-힣]{2,8}(?:김밥|국수|국밥|갈비|치킨|식당|카페|베이커리|돈까스))/g,
        
        // 완전히 제거 - 너무 많은 일반 단어 추출
      ];
      
      specificPatterns.forEach((pattern, index) => {
        const matches = allText.match(pattern) || [];
        matches.forEach(match => {
          // 패턴에 따라 다르게 추출
          let extracted = '';
          
          if (pattern.source.includes('상호')) {
            // "상호 : 식당명" 형태
            extracted = match.replace(/상호\s*:\s*/, '').trim();
          } else if (pattern.source.includes('위|\\)|BEST')) {
            // "1위 식당명", "BEST 1) 식당명" 형태
            extracted = match.replace(/(?:\d+위|\d+\)|BEST\s*\d+\))\s*/, '').trim();
          } else if (pattern.source.includes('\\d+\\.')) {
            // "1. 식당명" 형태
            extracted = match.replace(/\d+\.\s*/, '').trim();
          } else if (pattern.source.includes('[▶►✅✔☑🔸🔹]')) {
            // "▶ 식당명" 형태
            extracted = match.replace(/[▶►✅✔☑🔸🔹]\s*/, '').trim();
          } else if (pattern.source.includes('[📍📌]')) {
            // "📍 식당명" 형태
            extracted = match.replace(/[📍📌]\s*/, '').trim();
          } else if (pattern.source.includes(':\\s*')) {
            // "식당명 :" 형태
            extracted = match.replace(/\s*:.*/, '').trim();
          } else if (pattern.source.includes('\\(')) {
            // "식당명 (" 형태
            extracted = match.replace(/\s*\(.*/, '').trim();
          } else if (pattern.source.includes('이곳은|여기는|바로')) {
            // "이곳은 식당명" 형태
            extracted = match.replace(/(?:이곳은|여기는|바로)\s+/, '').trim();
          } else {
            // 기본적으로 첫 번째 단어 추출
            extracted = match.trim().split(/\s+/)[0];
          }
          
          // 불필요한 문자 제거
          extracted = extracted.replace(/[:\(\),.!?#]/g, '').trim();
          
          console.log(`     🔍 패턴 ${index + 1} 매치: "${match}" → 추출: "${extracted}" → 검증: ${this.isExactRestaurantName(extracted)}`);
          
          if (this.isExactRestaurantName(extracted)) {
            restaurantNames.add(extracted);
            console.log(`     ✅ 구체적 패턴에서 추출: ${extracted}`);
          }
        });
      });
    });

    console.log(`\n🔍 영상 제목들 분석:`);
    videos.forEach((video, index) => {
      console.log(`   ${index + 1}. ${video.snippet.title}`);
    });
    
    console.log(`\n📊 최종 추출된 식당명: ${restaurantNames.size}개`);
    if (restaurantNames.size > 0) {
      console.log('추출된 식당명들:', Array.from(restaurantNames));
    } else {
      console.log('⚠️ 추출된 식당명이 없습니다.');
    }
    return Array.from(restaurantNames);
  }
  
  /**
   * 정확한 식당명인지 확인 (단순하고 효과적인 기준)
   */
  isExactRestaurantName(name) {
    // 기본 조건 체크
    if (!name || name.length < 2 || name.length > 15) return false;
    if (!(/[가-힣]/.test(name))) return false;
    
    // 너무 짧은 이름 제외 (2글자 이상 필요)
    if (name.length < 2) return false;
    
    // 절대 제외되어야 하는 키워드들 (명확히 식당명이 아닌 것들만)
    const excludeTerms = [
      // 라벨/필드명 (유튜브 설명에서 자주 나오는 라벨들)
      '상호', '매장명', '가게명', '주소', '영업시간', '전화번호', '메뉴', '가격', '주차',
      '위치', '연락처', '운영시간', '휴무일', '좌석', '포장', '배달', '가게', '특징',
      '라스트오더', '정기휴무', '브레이크타임', '편집', '음악',
      
      // 맛집 관련 (일반 명사)
      '맛집', '유명맛집', '인기맛집', '현지맛집', '로컬맛집', '숨은맛집', '찐맛집',
      '제주맛집', '서귀포맛집', '부산맛집', '서울맛집', '유명맛집', '맛집들',
      
      // 지역명 (식당명이 아님)
      '제주도', '제주시', '서귀포', '애월', '성산', '중문', '한림', '서귀포시',
      '동문시장', '중앙시장', '올레시장', '제주에서', '제주까지', '제주도하면', '제주도를',
      
      // 제주도 행정구역 (읍/면/동)
      '구좌읍', '우도면', '표선면', '성산읍', '남원읍', '대정읍', '한경면',
      '한림읍', '애월읍', '조천읍', '용담동', '건입동', '화북동', '삼양동',
      '이도동', '삼도동', '용담일동', '용담이동', '건입동', '화북일동', '화북이동',
      '삼양일동', '삼양이동', '삼양삼동', '이도일동', '이도이동', '삼도일동', '삼도이동',
      '연동', '노형동', '외도동', '이호동', '도두동', '월평동', '영평동',
      '오라동', '아라동', '봉개동', '화순동', '동홍동', '서홍동', '토평동',
      '하귀동', '중앙동', '서귀동', '동산동', '강정동', '대천동', '중문동',
      '예래동', '상예동', '하예동', '보목동', '토평동', '신효동', '효돈동',
      '안덕면', '대정읍', '한경면', '표선면', '성산읍', '구좌읍', '조천읍',
      '한림읍', '애월읍', '우도면', '추자면',
      
      // 제주도 관광지 및 지명
      '함덕해수욕장', '서우봉', '제주돌문화공원', '거문오름', '만장굴', '성산일출봉',
      '우도', '추자도', '비자림', '용눈이오름', '사라봉', '한라산', '백록담',
      '천지연폭포', '정방폭포', '천제연폭포', '주상절리', '용머리해안', '산방산',
      '섭지코지', '성읍민속마을', '김녕미로공원', '만장굴', '협재해수욕장',
      '금능해수욕장', '곽지해수욕장', '이호테우해수욕장', '삼양해수욕장',
      '함덕해수욕장', '김녕해수욕장', '월정리해수욕장', '하도해수욕장',
      '신양해수욕장', '표선해수욕장', '화순해수욕장', '쇠소깍', '올레길',
      '테마파크', '구간', '랜드', '캔디원', '헬로키티', '테디베어',
      '아쿠아플라넷', '플레이케이팝', '미니랜드', '러브랜드', '믿거나말거나',
      '세계자동차박물관', '테디베어뮤지엄', '아프리카박물관', '김영갑갤러리',
      '방문객센터', '자연휴양림', '삼나무숲', '편백나무숲', '붉은오름',
      '물영아리', '1100고지', '어리목', '영실', '성판악', '관음사',
      '돈내코', '용연', '이중섭거리', '올레시장', '동문시장', '중앙지하상가',
      '제주민속촌', '제주올레', '제주국제공항', '제주항', '성산항', '한림항',
      '애월항', '화순항', '모슬포항', '우도봉수대', '우도등대', '서빈백사',
      '검멀레', '신창풍차해안도로', '납읍리', '종달리', '세화리', '평대리',
      '하도리', '월정리', '김녕리', '동복리', '세화포구', '종달포구',
      '하도포구', '월정포구', '김녕포구', '동복포구', '신천포구', '온평포구',
      '표선포구', '화순포구', '강정포구', '중문포구', '대포포구', '안덕포구',
      '화순포구', '송악산', '마라도', '가파도', '형제섬', '범섬',
      '문섬', '섶섬', '지귀도', '혈망봉', '머체왓숲길', '비자림로',
      '평화로', '516도로', '1132도로', '1117도로', '1139도로',
      '일주동로', '일주서로', '번영로', '중앙로', '관덕로', '탑동로',
      '동광로', '서광로', '한경로', '대정로', '안덕로', '중문로',
      '표선로', '성산로', '구좌로', '조천로', '한림로', '애월로',
      '노형로', '연삼로', '1100로', '516로', '평화로', '중산간로',
      '해안도로', '올레길', '둘레길', '한라수목원', '절물자연휴양림',
      '사려니숲길', '붉은오름자연휴양림', '한라산국립공원', '제주세계자연유산센터',
      '제주돌문화공원', '제주민속촌', '제주항공우주박물관', '제주국제평화센터',
      '제주국제컨벤션센터', 'ICC제주', '제주월드컵경기장', '제주종합운동장',
      '제주실내체육관', '제주국제자유도시', '제주특별자치도', '제주도청',
      '제주시청', '서귀포시청', '제주교육청', '제주지방법원', '제주지방검찰청',
      '제주지방경찰청', '제주소방서', '제주보건소', '제주세무서',
      '제주고용센터', '제주관광공사', '제주개발공사', '제주국제대학교',
      '제주대학교', '제주교육대학교', '제주한라대학교', '제주관광대학교',
      '제주국제관광대학', '제주전문대학', '제주산업정보대학', '제주관광고등학교',
      '제주제일고등학교', '제주여자고등학교', '제주중앙고등학교', '서귀포고등학교',
      '대정고등학교', '한림고등학교', '애월고등학교', '성산고등학교',
      '표선고등학교', '남원고등학교', '구좌고등학교', '조천고등학교',
      
      // 숫자/순위 (식당명이 아님)
      '1위', '2위', '3위', '4위', '5위', '1등', '2등', '3등', 'BEST', 'TOP',
      
      // 일반적인 메뉴명 (식당명이 아님)
      '고기국수', '해물국수', '갈치회', '통갈치', '흑돼지', '해산물', '고등어회',
      
      // 방송/프로그램명
      '환승연애', '런닝맨', '무한도전', '나혼자산다',
      
      // 형용사/부사/일반단어
      '최고', '대박', '진짜', '정말', '너무', '완전', '압도적', '유명', '인생',
      '제일', '찾는', '바로', '여기가', '곳은', '가장', '없는', '많은',
      '미친', '있어요', '하세요', '보이는', '남겨주세요', '여기우다',
      
      // 소셜미디어/연락처
      '이메일', '블로그', '인스타', '인스타그램', '페이스북', '유튜브', '채널',
      
      // 카페 관련
      '카페', '제주카페', '제주신상카페', '제주도카페', '애월카페', '테마카페',
      '시내카페', '베이커리카페', '카이막카페', '제주도농장카페', '제주도대형카페',
      '제주도신상카페',
      
      // 여행 관련
      '제주여행', '서귀포여행', '제주도여행',
      
      // 음식 재료/음식명
      '우니', '카이막', '제주카이막', '뻘건고기국수', '매운갈비', '돌솥밥', '해물탕', '콤보',
      
      // 방송/프로그램명
      '동진다혜', '다혜동진',
      
      // 기타 일반 단어들
      '그룹으로',
      '라스트오더', '사장님의', '미쳤던', '여기는', '믿고', '아무거나',
      '그리고', '이제', '잠깐', '그런데', '지금', '나중에', '한번',
      '그때', '오늘', '내일', '어제', '언제', '어디', '어떻게',
      '다시', '또다시', '계속', '항상', '자주', '가끔', '때로',
      '모든', '모두', '전부', '일부', '조금', '많이', '적게',
      '크게', '작게', '높게', '낮게', '빠르게', '느리게',
      '특히', '특별히', '독특한', '평범한', '일반적인', '특이한',
      '맛있는', '맛없는', '달콤한', '쓴맛', '매운맛', '짠맛',
      '부드러운', '딱딱한', '뜨거운', '차가운', '따뜻한',
      '신선한', '오래된', '새로운', '낡은', '깨끗한', '더러운',
      '좋은', '나쁜', '예쁜', '못생긴', '아름다운', '추한',
      '빠른', '느린', '편리한', '불편한', '가까운', '먼',
      '크기', '모양', '색깔', '재료', '방법', '과정', '결과',
      '시작', '끝', '중간', '처음', '마지막', '다음', '이전',
      '위에', '아래에', '옆에', '앞에', '뒤에', '안에', '밖에',
      '방향', '거리', '길이', '넓이', '높이', '깊이', '무게',
      '가격', '돈', '비용', '할인', '무료', '유료', '저렴',
      '비싸다', '싸다', '경제적', '비경제적', '합리적',
      '따라서', '그래서', '그러므로', '하지만', '그러나',
      '또는', '혹은', '아니면', '그리고', '그런데', '그래도',
      '만약', '만일', '혹시', '아마도', '아마', '확실히',
      '절대', '결코', '반드시', '꼭', '벌써', '이미', '아직',
      '갑자기', '천천히', '빨리', '급히', '서둘러', '여유롭게',
      '조심스럽게', '대충', '정확히', '완전히', '부분적으로',
      '완벽하게', '불완전하게', '성공적으로', '실패적으로',
      '행복하게', '슬프게', '즐겁게', '괴롭게', '편안하게',
      '이해하다', '모르다', '알다', '배우다', '가르치다',
      '말하다', '듣다', '보다', '읽다', '쓰다', '그리다',
      '만들다', '부수다', '고치다', '바꾸다', '움직이다',
      '멈추다', '서다', '앉다', '눕다', '걷다', '뛰다',
      '가다', '오다', '들어가다', '나가다', '올라가다',
      '내려가다', '돌아가다', '돌아오다', '떠나다', '도착하다',
      '선택하다', '결정하다', '생각하다', '느끼다', '원하다',
      '좋아하다', '싫어하다', '사랑하다', '미워하다', '기다리다',
      '찾다', '발견하다', '잃다', '얻다', '주다', '받다',
      '빌리다', '빌려주다', '사다', '팔다', '나누다', '모으다',
      '쌓다', '쌓이다', '흩어지다', '정리하다', '청소하다',
      '씻다', '닦다', '입다', '벗다', '신다', '신기다',
      '먹다', '마시다', '요리하다', '설거지하다', '준비하다',
      '일하다', '쉬다', '잠자다', '일어나다', '씻다',
      '치다', '때리다', '밀다', '당기다', '던지다', '잡다',
      '들다', '내리다', '올리다', '펴다', '접다', '자르다',
      '붙이다', '떼다', '열다', '닫다', '켜다', '끄다',
      '누르다', '돌리다', '흔들다', '비틀다', '굽다',
      '펴다', '구부리다', '뻗다', '오그라들다', '펄럭이다',
      '날리다', '떨어지다', '떨어뜨리다', '올려놓다', '내려놓다',
      '놓다', '두다', '넣다', '빼다', '채우다', '비우다',
      '쏟다', '따르다', '흘리다', '막다', '뚫다', '파다',
      '심다', '뽑다', '자라다', '피다', '지다', '말라다',
      '썩다', '익다', '타다', '꺼지다', '이루다', '개발하다',
      '발전하다', '성장하다', '변화하다', '개선하다', '악화하다',
      '시작하다', '끝내다', '계속하다', '중단하다', '멈추다',
      '반복하다', '연습하다', '연구하다', '실험하다', '시도하다',
      '노력하다', '성공하다', '실패하다', '포기하다', '극복하다',
      '참다', '견디다', '버티다', '지키다', '보호하다',
      '공격하다', '방어하다', '도망가다', '쫓다', '숨다',
      '나타나다', '사라지다', '생기다', '없어지다', '존재하다',
      '살다', '죽다', '태어나다', '자라다', '늙다',
      '건강하다', '아프다', '치료하다', '회복하다', '예방하다',
      '운동하다', '건강', '질병', '병원', '의사', '간호사',
      '약', '치료', '수술', '검사', '진단', '예방',
      '위험', '안전', '조심', '주의', '경고', '금지',
      '허용', '승인', '거부', '반대', '찬성', '동의',
      '의견', '생각', '아이디어', '계획', '목표', '꿈',
      '희망', '걱정', '불안', '두려움', '공포', '기쁨',
      '행복', '슬픔', '괴로움', '고통', '즐거움', '재미',
      '흥미', '관심', '궁금', '놀라운', '신기한', '이상한',
      '평범한', '일반적인', '특별한', '독특한', '흔한',
      '드문', '많은', '적은', '충분한', '부족한', '넘치는',
      '복잡한', '간단한', '쉬운', '어려운', '힘든',
      '편한', '불편한', '자유로운', '제한된', '넓은',
      '좁은', '긴', '짧은', '두꺼운', '얇은', '무거운',
      '가벼운', '단단한', '부드러운', '거친', '매끄러운',
      '밝은', '어두운', '환한', '흐린', '맑은', '탁한',
      '투명한', '불투명한', '깨끗한', '더러운', '신선한',
      '상한', '뜨거운', '차가운', '따뜻한', '시원한',
      '건조한', '습한', '젖은', '마른', '단맛', '쓴맛',
      '신맛', '짠맛', '매운맛', '담백한', '진한', '연한',
      '향긋한', '냄새나는', '조용한', '시끄러운', '빠른',
      '느린', '높은', '낮은', '깊은', '얕은', '가까운',
      '먼', '오래된', '새로운', '옛날', '현대', '미래',
      '과거', '현재', '지금', '그때', '언제', '어디',
      '어떻게', '왜', '무엇', '누구', '어느', '몇',
      '모든', '각각', '하나', '둘', '셋', '넷', '다섯',
      '여섯', '일곱', '여덟', '아홉', '열', '백', '천',
      '만', '억', '조', '첫째', '둘째', '셋째', '마지막',
      '처음', '중간', '끝', '앞', '뒤', '위', '아래',
      '옆', '안', '밖', '여기', '저기', '거기', '어디',
      '이곳', '저곳', '그곳', '어디든', '어디서', '어디로',
      '이제', '그제', '어제', '오늘', '내일', '모레',
      '다음', '이전', '먼저', '나중', '동시', '순서',
      '차례', '번갈아', '함께', '혼자', '같이', '따로',
      '직접', '간접', '바로', '곧', '즉시', '천천히',
      '빨리', '급히', '서둘러', '여유롭게', '조심스럽게',
      '대충', '정확히', '완전히', '부분적으로', '전체적으로',
      '개별적으로', '일반적으로', '특별히', '특히', '주로',
      '대부분', '일부', '조금', '많이', '매우', '아주',
      '정말', '진짜', '사실', '실제', '실제로', '사실상',
      '물론', '당연히', '확실히', '분명히', '절대',
      '결코', '전혀', '완전히', '거의', '별로', '전혀',
      '아마도', '아마', '혹시', '만약', '만일', '그런데',
      '하지만', '그러나', '그래도', '그래서', '그러므로',
      '따라서', '그리고', '또한', '게다가', '뿐만아니라',
      '또는', '혹은', '아니면', '그냥', '단순히', '단지',
      '오히려', '차라리', '대신', '보다', '만큼', '처럼',
      '같이', '비슷하게', '다르게', '반대로', '거꾸로',
      '역시', '과연', '정말로', '실제로', '사실상',
      '어쨌든', '아무튼', '그런데', '그래도', '그러나',
      '하지만', '하지만', '그렇지만', '그럼에도', '불구하고',
      '대신에', '덕분에', '때문에', '원인', '결과',
      '영향', '효과', '변화', '개선', '악화', '발전',
      '성장', '감소', '증가', '상승', '하락', '개발',
      '제작', '생산', '제조', '창조', '발명', '발견',
      '연구', '조사', '실험', '시도', '노력', '성공',
      '실패', '포기', '극복', '해결', '문제', '어려움',
      '장애', '도전', '기회', '가능성', '확률', '위험',
      '안전', '보호', '예방', '치료', '회복', '건강',
      '질병', '부상', '사고', '실수', '잘못', '오류',
      '정확', '정밀', '세밀', '자세', '꼼꼼', '신중',
      '조심', '주의', '경고', '알림', '공지', '발표',
      '보고', '설명', '소개', '안내', '지시', '명령',
      '요청', '부탁', '질문', '답변', '대답', '응답',
      '반응', '반응', '태도', '자세', '행동', '활동',
      '움직임', '변화', '발전', '성장', '학습', '교육',
      '훈련', '연습', '준비', '계획', '목표', '목적',
      '의도', '생각', '아이디어', '아이디어', '창의',
      '상상', '꿈', '희망', '기대', '예상', '예측',
      '추측', '가정', '가능', '불가능', '확실', '불확실',
      '명확', '불명확', '분명', '애매', '복잡', '간단',
      '쉬운', '어려운', '힘든', '편한', '불편한',
      '자유', '제한', '규칙', '법칙', '원칙', '기준',
      '표준', '일반', '특별', '독특', '흔한', '드문',
      '많은', '적은', '충분', '부족', '넘치는', '모자라는',
      '완전', '불완전', '전체', '부분', '개별', '공통',
      '차이', '다름', '같음', '비슷', '유사', '동일',
      '다른', '새로운', '오래된', '현대', '과거', '미래',
      '시간', '공간', '장소', '위치', '방향', '거리',
      '속도', '빠른', '느린', '높은', '낮은', '크기',
      '모양', '색깔', '재료', '성분', '구성', '구조',
      '형태', '상태', '조건', '상황', '환경', '분위기',
      '느낌', '기분', '감정', '생각', '의견', '판단',
      '평가', '비교', '선택', '결정', '선호', '취향',
      '관심', '흥미', '호기심', '궁금', '놀라운',
      '신기한', '이상한', '평범한', '일반적인', '특별한',
      '독특한', '흔한', '드문', '많은', '적은', '충분한',
      '부족한', '넘치는', '복잡한', '간단한', '쉬운',
      '어려운', '힘든', '편한', '불편한', '자유로운',
      '제한된', '넓은', '좁은', '긴', '짧은', '두꺼운',
      '얇은', '무거운', '가벼운', '단단한', '부드러운',
      '거친', '매끄러운', '밝은', '어두운', '환한',
      '흐린', '맑은', '탁한', '투명한', '불투명한',
      '깨끗한', '더러운', '신선한', '상한', '뜨거운',
      '차가운', '따뜻한', '시원한', '건조한', '습한',
      '젖은', '마른', '단맛', '쓴맛', '신맛', '짠맛',
      '매운맛', '담백한', '진한', '연한', '향긋한',
      '냄새나는', '조용한', '시끄러운', '빠른', '느린',
      '높은', '낮은', '깊은', '얕은', '가까운', '먼',
      '오래된', '새로운', '옛날', '현대', '미래', '과거',
      '현재', '지금', '그때', '언제', '어디', '어떻게',
      '왜', '무엇', '누구', '어느', '몇', '모든',
      '각각', '하나', '둘', '셋', '넷', '다섯', '여섯',
      '일곱', '여덟', '아홉', '열', '백', '천', '만',
      '억', '조', '첫째', '둘째', '셋째', '마지막',
      '처음', '중간', '끝', '앞', '뒤', '위', '아래',
      '옆', '안', '밖', '여기', '저기', '거기', '어디',
      '이곳', '저곳', '그곳', '어디든', '어디서', '어디로',
      '이제', '그제', '어제', '오늘', '내일', '모레',
      '다음', '이전', '먼저', '나중', '동시', '순서',
      '차례', '번갈아', '함께', '혼자', '같이', '따로',
      '직접', '간접', '바로', '곧', '즉시', '천천히',
      '빨리', '급히', '서둘러', '여유롭게', '조심스럽게',
      '대충', '정확히', '완전히', '부분적으로', '전체적으로',
      '개별적으로', '일반적으로', '특별히', '특히', '주로',
      '대부분', '일부', '조금', '많이', '매우', '아주',
      '정말', '진짜', '사실', '실제', '실제로', '사실상',
      '물론', '당연히', '확실히', '분명히', '절대',
      '결코', '전혀', '완전히', '거의', '별로', '전혀',
      '아마도', '아마', '혹시', '만약', '만일', '그런데',
      '하지만', '그러나', '그래도', '그래서', '그러므로',
      '따라서', '그리고', '또한', '게다가', '뿐만아니라',
      '또는', '혹은', '아니면', '그냥', '단순히', '단지',
      '오히려', '차라리', '대신', '보다', '만큼', '처럼',
      '같이', '비슷하게', '다르게', '반대로', '거꾸로',
      '역시', '과연', '정말로', '실제로', '사실상',
      '어쨌든', '아무튼', '그런데', '그래도', '그러나',
      '하지만', '하지만', '그렇지만', '그럼에도', '불구하고',
      '대신에', '덕분에', '때문에', '원인', '결과',
      '영향', '효과', '변화', '개선', '악화', '발전',
      '성장', '감소', '증가', '상승', '하락', '개발',
      '제작', '생산', '제조', '창조', '발명', '발견',
      '연구', '조사', '실험', '시도', '노력', '성공',
      '실패', '포기', '극복', '해결', '문제', '어려움',
      '장애', '도전', '기회', '가능성', '확률', '위험',
      '안전', '보호', '예방', '치료', '회복', '건강',
      '질병', '부상', '사고', '실수', '잘못', '오류',
      '정확', '정밀', '세밀', '자세', '꼼꼼', '신중',
      '조심', '주의', '경고', '알림', '공지', '발표',
      '보고', '설명', '소개', '안내', '지시', '명령',
      '요청', '부탁', '질문', '답변', '대답', '응답',
      '반응', '반응', '태도', '자세', '행동', '활동',
      '움직임', '변화', '발전', '성장', '학습', '교육',
      '훈련', '연습', '준비', '계획', '목표', '목적',
      '의도', '생각', '아이디어', '아이디어', '창의',
      '상상', '꿈', '희망', '기대', '예상', '예측',
      '추측', '가정', '가능', '불가능', '확실', '불확실',
      '명확', '불명확', '분명', '애매', '복잡', '간단',
      '쉬운', '어려운', '힘든', '편한', '불편한',
      '자유', '제한', '규칙', '법칙', '원칙', '기준',
      '표준', '일반', '특별', '독특', '흔한', '드문',
      '많은', '적은', '충분', '부족', '넘치는', '모자라는',
      '완전', '불완전', '전체', '부분', '개별', '공통',
      '차이', '다름', '같음', '비슷', '유사', '동일',
      '다른', '새로운', '오래된', '현대', '과거', '미래',
      '시간', '공간', '장소', '위치', '방향', '거리',
      '속도', '빠른', '느린', '높은', '낮은', '크기',
      '모양', '색깔', '재료', '성분', '구성', '구조',
      '형태', '상태', '조건', '상황', '환경', '분위기',
      '느낌', '기분', '감정', '생각', '의견', '판단',
      '평가', '비교', '선택', '결정', '선호', '취향',
      '관심', '흥미', '호기심', '궁금', '놀라운',
      '신기한', '이상한', '평범한', '일반적인', '특별한',
      '독특한', '흔한', '드문', '많은', '적은', '충분한',
      '부족한', '넘치는', '복잡한', '간단한', '쉬운',
      '어려운', '힘든', '편한', '불편한', '자유로운',
      '제한된', '넓은', '좁은', '긴', '짧은', '두꺼운',
      '얇은', '무거운', '가벼운', '단단한', '부드러운',
      '거친', '매끄러운', '밝은', '어두운', '환한',
      '흐린', '맑은', '탁한', '투명한', '불투명한',
      '깨끗한', '더러운', '신선한', '상한', '뜨거운',
      '차가운', '따뜻한', '시원한', '건조한', '습한',
      '젖은', '마른', '단맛', '쓴맛', '신맛', '짠맛',
      '매운맛', '담백한', '진한', '연한', '향긋한',
      '냄새나는', '조용한', '시끄러운', '빠른', '느린',
      '높은', '낮은', '깊은', '얕은', '가까운', '먼',
      '오래된', '새로운', '옛날', '현대', '미래', '과거',
      '현재', '지금', '그때', '언제', '어디', '어떻게',
      '왜', '무엇', '누구', '어느', '몇', '모든',
      '각각', '하나', '둘', '셋', '넷', '다섯', '여섯',
      '일곱', '여덟', '아홉', '열', '백', '천', '만',
      '억', '조', '첫째', '둘째', '셋째', '마지막',
      '처음', '중간', '끝', '앞', '뒤', '위', '아래',
      '옆', '안', '밖', '여기', '저기', '거기', '어디',
      '이곳', '저곳', '그곳', '어디든', '어디서', '어디로',
      '이제', '그제', '어제', '오늘', '내일', '모레',
      '다음', '이전', '먼저', '나중', '동시', '순서',
      '차례', '번갈아', '함께', '혼자', '같이', '따로',
      '직접', '간접', '바로', '곧', '즉시', '천천히',
      '빨리', '급히', '서둘러', '여유롭게', '조심스럽게',
      '대충', '정확히', '완전히', '부분적으로', '전체적으로',
      '개별적으로', '일반적으로', '특별히', '특히', '주로',
      '대부분', '일부', '조금', '많이', '매우', '아주',
      '정말', '진짜', '사실', '실제', '실제로', '사실상',
      '물론', '당연히', '확실히', '분명히', '절대',
      '결코', '전혀', '완전히', '거의', '별로', '전혀',
      '아마도', '아마', '혹시', '만약', '만일', '그런데',
      '하지만', '그러나', '그래도', '그래서', '그러므로',
      '따라서', '그리고', '또한', '게다가', '뿐만아니라',
      '또는', '혹은', '아니면', '그냥', '단순히', '단지',
      '오히려', '차라리', '대신', '보다', '만큼', '처럼',
      '같이', '비슷하게', '다르게', '반대로', '거꾸로',
      '역시', '과연', '정말로', '실제로', '사실상',
      '어쨌든', '아무튼', '그런데', '그래도', '그러나',
      '하지만', '하지만', '그렇지만', '그럼에도', '불구하고',
      '대신에', '덕분에', '때문에',
      
      // 시간/상황 관련
      '아침식사', '점심식사', '저녁식사', '브런치', '야식', '영업시간',
      
      // 먹방/영상 관련
      '먹방', '영상', '유튜브', '채널', '리뷰', '영상에', '궁금하신',
      
      // 기타 일반 단어들
      '음식', '비교', '편집', '음악', '할인', '렌트카', '문의', '가입시', '무료',
      '에디의', '브금대통령', '프로', '아래', '저도', '이주한', '하나인', '특집'
    ];
    
    // 정확히 일치하거나 포함하는지 체크
    for (const term of excludeTerms) {
      if (name === term || name.includes(term)) {
        return false;
      }
    }
    
    // 지역명으로만 이루어진 경우 제외
    const locations = ['제주', '서귀포', '애월', '성산', '중문', '한림', '서울', '부산'];
    if (locations.includes(name)) {
      return false;
    }
    
    return true;
  }

  /**
   * 일반적인 용어인지 확인 (기존 함수 - 하위 호환성 유지)
   */
  isGenericTerm(name) {
    return !this.isExactRestaurantName(name);
  }

  /**
   * 식당명 유효성 검사 (기존 검증된 방식)
   */
  isValidRestaurantName(name) {
    // 기본 조건 체크
    if (name.length < 2 || name.length > 15) return false;
    if (!(/[가-힣]/.test(name))) return false;
    
    // 제외 키워드 (매우 엄격하게)
    const excludeWords = [
      '추천', '리뷰', '영상', '채널', '여행', '관광', '투어', '코스',
      '베스트', 'best', '탑텐', '순위', '랭킹', 'top',
      '이건', '저장각', '서쪽부터', '남쪽까지', '도민이', '풍경지들을',
      '상반기', '천하제일', '조회수', '달리고', '곳이죠', '뒤지는', '곳입니다',
      '놓치지', '마세요', '협찬은', '않았습니다', '좋아하고', '좋아하는',
      '이곳저곳', '다니며', '촬영했던', '여기로', '가보세요', '가심비', '가성비',
      '실패없는', '최신판', '내돈내산', '광고없음', '모드로', '살란다', '내돈내산으로',
      '확률을', '줄이는', '인기가', '소개해', '드릴게요', '저장해두시고', '다녀와보세요',
      // 추가: 지역명 + 맛집 조합들
      '제주도맛집', '제주맛집', '서귀포맛집', '애월맛집', '성산맛집', '한림맛집',
      '로컬맛집', '현지맛집', '현지인맛집', '숨은맛집', '유명맛집', '인기맛집',
      '노포맛집', '찐맛집', '진짜맛집', '대박맛집', '월정리맛집', '함덕맛집',
      '협재맛집', '중문맛집', '표선맛집', '구좌맛집', '조천맛집', '우도맛집',
      // 음식종류 + 맛집
      '흑돼지맛집', '해물맛집', '갈치맛집', '고기국수맛집', '회맛집', '국밥맛집',
      '한식맛집', '중식맛집', '일식맛집', '양식맛집', '카페맛집',
      // 지역명만
      '제주도', '제주시', '서귀포', '애월', '한림', '성산', '표선', '구좌', '조천',
      // 기타 일반적인 표현
      '노형동맛집', '연동맛집', '이도동맛집', '삼도동맛집', '제주현지인맛집',
      '제주도현지맛집', '제주유명횟집', '인생맛집', '껍질꼬치부터',
      '해수욕장맛집', '올레시장본점', '함덕해수욕장맛집', '제주함덕맛집',
      // 추가 제외 단어들
      '민박집', '모음집', '해산물맛집', '섭지코지맛집', '공항근처맛집', '국수맛집',
      '고기국수', '제주 고기국수', '메뉴 고기국수', '진짜 고기국수', '음식 고기국수',
      '바로 고기국수', '근처 고기국수', '감성카페',
      // 더 추가
      '불특정', '갈치구이맛집', '우니맛집', '성게국수', '라면맛집', '해물라면맛집',
      '리즈맛집', '제주뼈찜맛집', '동탄맛집', '화성맛집', '계절식탁',
      '이호일동 자매국수', '맛집 효퇴국수', '공항근처 골막식당', '맛집 자매국수'
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

  // =============================================================================
  // 🗺️ 카카오 Place ID 매칭 시스템
  // =============================================================================

  /**
   * 카카오 API로 식당 정보 검색
   */
  async searchKakaoPlace(restaurantName, region = '제주도') {
    try {
      // 지역별 검색 쿼리 최적화
      const regionKeywords = {
        '제주도': ['제주', '제주도', '제주특별자치도'],
        '서울': ['서울', '서울시', '서울특별시'],
        '부산': ['부산', '부산시', '부산광역시']
      };
      
      const keywords = regionKeywords[region] || [region];
      let bestMatch = null;

      for (const keyword of keywords) {
        const query = `${restaurantName} ${keyword}`;
        
        const response = await axios.get('https://dapi.kakao.com/v2/local/search/keyword.json', {
          headers: {
            'Authorization': `KakaoAK ${this.kakaoApiKey}`
          },
          params: {
            query: query,
            category_group_code: 'FD6', // 음식점
            size: 15,
            sort: 'accuracy'
          }
        });

        if (response.data.documents && response.data.documents.length > 0) {
          // 스마트 매칭으로 최적 결과 찾기
          const matchedPlace = this.findBestMatch(restaurantName, response.data.documents);
          if (matchedPlace && (!bestMatch || matchedPlace.score > bestMatch.score)) {
            bestMatch = matchedPlace;
          }
        }

        // API 호출 간격
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      return bestMatch?.place || null;
    } catch (error) {
      console.error(`❌ 카카오 검색 실패 (${restaurantName}): ${error.message}`);
      this.stats.errors++;
      return null;
    }
  }

  // =============================================================================
  // 🧠 스마트 매칭 시스템
  // =============================================================================

  /**
   * 문자열 정규화 (띄어쓰기, 특수문자 제거)
   */
  normalizeString(str) {
    if (!str) return '';
    return str.toLowerCase()
      .replace(/\s+/g, '')           // 모든 공백 제거
      .replace(/[\-\_\.]/g, '')      // 하이픈, 언더스코어, 점 제거
      .replace(/[()]/g, '')          // 괄호 제거
      .trim();
  }

  /**
   * 두 문자열의 유사도 계산 (0~1)
   */
  calculateSimilarity(str1, str2) {
    if (!str1 || !str2) return 0;
    
    const s1 = this.normalizeString(str1);
    const s2 = this.normalizeString(str2);
    
    if (s1 === s2) return 1.0;
    
    // 긴 문자열에서 짧은 문자열이 얼마나 포함되는지 계산
    const [shorter, longer] = s1.length <= s2.length ? [s1, s2] : [s2, s1];
    
    if (shorter.length === 0) return 0;
    
    // 완전 포함 체크
    if (longer.includes(shorter)) {
      return shorter.length / longer.length;
    }
    
    return 0;
  }

  /**
   * 카카오 검색 결과에서 최적 매칭 찾기
   */
  findBestMatch(targetName, places) {
    let bestMatch = null;
    let bestScore = 0;

    for (const place of places) {
      const similarity = this.calculateSimilarity(targetName, place.place_name);
      
      // 유사도 임계값 0.7 이상
      if (similarity >= 0.7 && similarity > bestScore) {
        bestScore = similarity;
        bestMatch = {
          place: place,
          score: similarity
        };
      }
    }

    return bestMatch;
  }

  // =============================================================================
  // 📍 Google Places API 연동
  // =============================================================================

  /**
   * Google Places API로 상세 정보 가져오기 (재시도 로직 포함)
   */
  async getGooglePlacesDetails(kakaoPlace, retryCount = 0) {
    try {
      if (!kakaoPlace.x || !kakaoPlace.y) return null;

      const lat = parseFloat(kakaoPlace.y);
      const lng = parseFloat(kakaoPlace.x);

      // Nearby Search로 장소 찾기
      const searchResponse = await axios.get('https://maps.googleapis.com/maps/api/place/nearbysearch/json', {
        params: {
          location: `${lat},${lng}`,
          radius: 50,
          name: kakaoPlace.place_name,
          type: 'restaurant',
          key: this.googleApiKey,
          language: 'ko'
        }
      });

      if (!searchResponse.data.results || searchResponse.data.results.length === 0) {
        return null;
      }

      const googlePlace = searchResponse.data.results[0];

      // Place Details로 상세 정보 가져오기
      const detailsResponse = await axios.get('https://maps.googleapis.com/maps/api/place/details/json', {
        params: {
          place_id: googlePlace.place_id,
          fields: 'place_id,name,rating,user_ratings_total,photos,regular_opening_hours,current_opening_hours,business_status,reviews,formatted_phone_number,website,price_level',
          key: this.googleApiKey,
          language: 'ko'
        }
      });

      if (detailsResponse.data.result) {
        return detailsResponse.data.result;
      }

      return null;
    } catch (error) {
      // 403 에러 시 API 키 로테이션 및 재시도
      if ((error.response?.status === 403 || error.message.includes('OVER_QUERY_LIMIT')) && retryCount < this.googleApiKeys.length - 1) {
        console.log(`⚠️ Google Places API 할당량 초과 (키 ${this.currentGoogleKeyIndex + 1}/${this.googleApiKeys.length})`);
        
        if (await this.checkAndRotateGoogleKey(error)) {
          console.log(`🔄 Google Places API 키 교체 후 재시도 중... (${retryCount + 1}회차)`);
          await new Promise(resolve => setTimeout(resolve, 1000)); // 1초 대기
          return this.getGooglePlacesDetails(kakaoPlace, retryCount + 1);
        }
      }
      
      console.error(`❌ Google Places 조회 실패: ${error.message}`);
      this.stats.errors++;
      return null;
    }
  }

  /**
   * Google Places Text Search로 지역별 맛집 검색
   */
  async searchGooglePlacesRestaurants(region, subRegion) {
    try {
      const restaurantNames = new Set();
      
      // 검색 쿼리 구성 (카테고리별)
      const searchQueries = [
        `${subRegion} 맛집`,
        `${subRegion} 현지인 맛집`, 
        `${subRegion} 카페`,
        `${subRegion} 음식점`,
        `${subRegion} 베이커리`
      ];

      console.log(`\n🔍 Google Places 검색: ${subRegion}`);
      console.log(`   검색 쿼리 수: ${searchQueries.length}개`);

      for (const query of searchQueries) {
        console.log(`   📍 검색 중: "${query}"`);
        
        const response = await axios.get('https://maps.googleapis.com/maps/api/place/textsearch/json', {
          params: {
            query: query,
            type: 'restaurant',
            language: 'ko',
            region: 'kr',
            key: this.googleApiKey
          }
        });

        if (response.data.results && response.data.results.length > 0) {
          console.log(`   ✅ ${response.data.results.length}개 장소 발견`);
          
          response.data.results.forEach(place => {
            // 지역 필터링 (제주도 내의 장소만)
            if (this.validateRegion(place.geometry.location.lat, place.geometry.location.lng, region)) {
              restaurantNames.add(place.name);
            }
          });
        } else {
          console.log(`   ❌ 검색 결과 없음`);
        }
        
        // API 호출 간격
        await new Promise(resolve => setTimeout(resolve, 1000));
      }

      console.log(`   📊 Google Places 결과: ${restaurantNames.size}개 고유 식당명 추출`);
      return Array.from(restaurantNames);
      
    } catch (error) {
      console.error(`❌ Google Places 검색 실패: ${error.message}`);
      return [];
    }
  }

  // =============================================================================
  // 📝 네이버 블로그 데이터 수집
  // =============================================================================

  /**
   * 네이버 블로그 검색
   */
  async searchNaverBlogs(restaurantName, address) {
    try {
      if (!this.naverClientId || !this.naverSecret) {
        return null;
      }

      // 더 정확한 검색을 위한 쿼리 구성
      const locationKeywords = this.extractLocationKeywords(address);
      
      // 일반적인 이름인 경우 더 구체적인 검색
      const isGenericName = this.isGenericRestaurantName(restaurantName);
      
      let searchQuery;
      if (isGenericName) {
        // 일반적인 이름이면 주소를 더 구체적으로 포함
        const specificLocation = this.getSpecificLocation(address);
        searchQuery = `"${restaurantName}" ${specificLocation} 맛집`;
        console.log(`   ⚠️ 일반적인 식당명 감지: "${restaurantName}" → 구체적 검색: "${searchQuery}"`);
      } else {
        // 고유한 이름이면 기존 방식
        searchQuery = `${restaurantName} ${locationKeywords.join(' ')} 맛집`;
      }

      const response = await axios.get('https://openapi.naver.com/v1/search/blog.json', {
        headers: {
          'X-Naver-Client-Id': this.naverClientId,
          'X-Naver-Client-Secret': this.naverSecret
        },
        params: {
          query: searchQuery,
          display: 10,
          sort: 'sim'
        }
      });

      if (response.data.items && response.data.items.length > 0) {
        // 블로그 결과 필터링 (식당명이 정확히 제목에 포함된 것만)
        const filteredBlogs = response.data.items.filter(item => {
          const title = item.title.replace(/<[^>]*>/g, '');
          const description = item.description.replace(/<[^>]*>/g, '');
          
          // 🔥 엄격한 필터링: 식당명이 제목에 정확히 포함되어야 함 (띄어쓰기 무시)
          const titleNormalized = title.replace(/\s+/g, '').toLowerCase();
          const restaurantNameNormalized = restaurantName.replace(/\s+/g, '').toLowerCase();
          const hasTitleMatch = titleNormalized.includes(restaurantNameNormalized);
          
          if (!hasTitleMatch) {
            console.log(`   ❌ 제목 불일치: "${title}" (식당명: ${restaurantName})`);
            return false;
          }
          
          // 주소의 주요 지역명 중 하나는 포함되어야 함
          const content = (title + ' ' + description).toLowerCase();
          const locationKeywords = this.extractLocationKeywords(address);
          const hasLocation = locationKeywords.length === 0 || 
            locationKeywords.some(keyword => content.includes(keyword.toLowerCase()));
          
          if (!hasLocation) {
            console.log(`   ❌ 지역 불일치: "${title}" (지역: ${locationKeywords.join(', ')})`);
            return false;
          }
          
          console.log(`   ✅ 정확한 매칭: "${title}"`);
          return true;
        });

        const blogs = filteredBlogs.map(item => ({
          title: item.title.replace(/<[^>]*>/g, ''),
          link: item.link,
          description: item.description.replace(/<[^>]*>/g, ''),
          bloggername: item.bloggername,
          postdate: item.postdate
        }));

        console.log(`   📝 네이버 블로그: ${response.data.items.length}개 → 필터링 후 ${blogs.length}개`);

        return {
          totalCount: blogs.length,
          blogs: blogs,
          searchQuery: searchQuery,
          updatedAt: new Date()
        };
      }

      return null;
    } catch (error) {
      console.error(`❌ 네이버 블로그 검색 실패: ${error.message}`);
      return null;
    }
  }

  /**
   * 일반적인 식당명인지 판별 (정확한 검색이 필요한 경우)
   */
  isGenericRestaurantName(name) {
    const genericNames = [
      '맛있는집', '좋은집', '행복한집', '우리집', '엄마집', '할머니집', '고향집',
      '맛나는집', '든든한집', '따뜻한집', '정성스런집', '사랑방', '정갈한집',
      '맛집', '별미집', '진미집', '별천지', '토속촌', '향토집', '전통집',
      '온갖집', '모든집', '새집', '옛날집', '시골집', '동네집', '마을집',
      '백반집', '한정식집', '가정식집', '집밥집', '손맛집', '정식집',
      '횟집', '고깃집', '국수집', '냉면집', '갈비집', '삼겹살집', 
      '해물집', '생선집', '조개집', '대게집', '랍스터집', '전복집',
      '카페', '커피숍', '다방', '찻집', '디저트카페', '베이커리',
      // 제주 지역 일반명
      '제주집', '한라산집', '성산집', '서귀포집', '애월집', '중문집'
    ];
    
    return genericNames.some(generic => 
      name.includes(generic) || name === generic
    );
  }

  /**
   * 주소에서 구체적인 위치 정보 추출 (일반적 식당명용)
   */
  getSpecificLocation(address) {
    if (!address) return '';
    
    // 동/읍/면까지 구체적으로 추출
    const parts = [];
    
    // 시/군/구 추출
    const cityMatch = address.match(/([가-힣]+[시군구])/);
    if (cityMatch) parts.push(cityMatch[1]);
    
    // 동/읍/면 추출
    const districtMatch = address.match(/([가-힣]+[동읍면])/);
    if (districtMatch) parts.push(districtMatch[1]);
    
    // 도로명이나 번지까지 포함 (더 구체적으로)
    const roadMatch = address.match(/([가-힣]+로|[가-힣]+길)/);
    if (roadMatch) parts.push(roadMatch[1]);
    
    return parts.join(' ');
  }

  /**
   * 주소에서 지역 키워드 추출
   */
  extractLocationKeywords(address) {
    if (!address) return [];

    const keywords = [];
    
    // 시/도 추출
    const provinceMatch = address.match(/(제주특별자치도|서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시|경기도|강원도|충청북도|충청남도|전라북도|전라남도|경상북도|경상남도)/);
    if (provinceMatch) {
      keywords.push(provinceMatch[1]);
    }

    // 시/군/구 추출
    const cityMatch = address.match(/([가-힣]+[시군구])/);
    if (cityMatch) {
      keywords.push(cityMatch[1]);
    }

    // 동/읍/면 추출
    const districtMatch = address.match(/([가-힣]+[동읍면])/);
    if (districtMatch) {
      keywords.push(districtMatch[1]);
    }

    return keywords;
  }

  // =============================================================================
  // 🔄 데이터 소스 통합 시스템
  // =============================================================================

  /**
   * YouTube와 Google Places 맛집 데이터를 통합
   */
  mergeRestaurantSources(youtubeRestaurants, googlePlacesRestaurants) {
    console.log(`\n🔄 데이터 소스 통합 중...`);
    console.log(`   YouTube 식당: ${youtubeRestaurants.length}개`);
    console.log(`   Google Places 식당: ${googlePlacesRestaurants.length}개`);

    // Set을 사용하여 중복 제거
    const mergedSet = new Set();
    
    // YouTube 식당명 추가
    youtubeRestaurants.forEach(name => {
      mergedSet.add(this.normalizeRestaurantName(name));
    });
    
    // Google Places 식당명 추가 (중복 체크하면서)
    googlePlacesRestaurants.forEach(name => {
      const normalized = this.normalizeRestaurantName(name);
      
      // 기존 이름들과 유사도 체크
      let isDuplicate = false;
      for (const existing of mergedSet) {
        if (this.calculateSimilarity(normalized, existing) > 0.8) {
          isDuplicate = true;
          break;
        }
      }
      
      if (!isDuplicate) {
        mergedSet.add(normalized);
      }
    });

    const mergedList = Array.from(mergedSet);
    console.log(`   통합 결과: ${mergedList.length}개 (중복 제거됨)`);
    console.log(`   추가된 식당: ${mergedList.length - youtubeRestaurants.length}개`);
    
    return mergedList;
  }

  /**
   * 식당명 정규화 (비교를 위한)
   */
  normalizeRestaurantName(name) {
    return name
      .replace(/\s+/g, '') // 공백 제거
      .replace(/[()]/g, '') // 괄호 제거
      .replace(/제주|서귀포/g, '') // 지역명 제거
      .toLowerCase();
  }

  /**
   * 두 문자열 간의 유사도 계산 (Jaccard 유사도)
   */
  calculateSimilarity(str1, str2) {
    const set1 = new Set(str1.split(''));
    const set2 = new Set(str2.split(''));
    
    const intersection = new Set([...set1].filter(x => set2.has(x)));
    const union = new Set([...set1, ...set2]);
    
    return intersection.size / union.size;
  }

  // =============================================================================
  // 🛡️ 지역 검증 시스템
  // =============================================================================

  /**
   * 지역 검증 (제주도 좌표 범위 체크)
   */
  validateRegion(lat, lng, targetRegion = '제주도') {
    const regionBounds = {
      '제주도': {
        minLat: 33.0,
        maxLat: 33.6,
        minLng: 126.0,
        maxLng: 127.0
      },
      '서울': {
        minLat: 37.4,
        maxLat: 37.7,
        minLng: 126.7,
        maxLng: 127.2
      },
      '부산': {
        minLat: 35.0,
        maxLat: 35.4,
        minLng: 128.9,
        maxLng: 129.3
      }
    };

    const bounds = regionBounds[targetRegion];
    if (!bounds) return false;

    return lat >= bounds.minLat && lat <= bounds.maxLat && 
           lng >= bounds.minLng && lng <= bounds.maxLng;
  }

  // =============================================================================
  // 💾 데이터 저장 시스템
  // =============================================================================

  /**
   * Firestore에 식당 데이터 저장
   */
  async saveRestaurantData(restaurantData) {
    try {
      const docRef = this.db.collection('restaurants').doc(restaurantData.placeId);
      
      await docRef.set({
        ...restaurantData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true
      }, { merge: true });

      console.log(`✅ 저장 완료: ${restaurantData.name}`);
      this.stats.saved++;
      return true;
    } catch (error) {
      console.error(`❌ 저장 실패 (${restaurantData.name}): ${error.message}`);
      this.stats.errors++;
      return false;
    }
  }

  // =============================================================================
  // 🚀 메인 실행 로직
  // =============================================================================

  /**
   * 전체 크롤링 프로세스 실행
   */
  async run() {
    this.log('🍽️ Ultimate Restaurant Crawler 시작!');
    this.log('='.repeat(50));

    const targetRegions = this.getTargetRegions();
    const searchQueries = this.getEnhancedSearchQueries();

    for (const region of targetRegions) {
      this.log(`\n📍 ${region} 지역 크롤링 시작`);
      this.log('='.repeat(50));
      
      const queries = searchQueries[region] || [];
      const allRestaurantNames = new Set();

      // 1단계: YouTube에서 맛집명 수집
      this.log(`\n🎥 1단계: YouTube 맛집 크롤링`);
      this.log(`   검색 키워드 수: ${queries.length}개`);
      this.log(`   키워드당 최대 영상: ${50}개`);
      this.log(`   예상 최대 영상 수: ${queries.length * 50}개 (중복 제거 전)\n`);
      
      // 중복 영상 제거를 위한 Map 사용 (videoId 기준)
      const videoMap = new Map();
      
      for (const query of queries) {
        const videos = await this.searchYouTubeVideos(query);
        
        // 중복 제거하면서 allVideos에 추가
        videos.forEach(video => {
          if (video.id && video.id.videoId) {
            videoMap.set(video.id.videoId, video);
          }
        });
        
        const names = this.extractRestaurantNames(videos);
        names.forEach(name => allRestaurantNames.add(name));
        console.log(`   "${query}": ${videos.length}개 영상 → ${names.length}개 식당명 추출`);
        
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
      
      // 중복 제거된 영상들을 allVideos 배열로 변환
      const allVideos = Array.from(videoMap.values());

      console.log(`\n📊 YouTube 크롤링 결과:`);
      console.log(`   총 영상 수: ${allVideos.length}개 (중복 제거됨)`);
      console.log(`   추출된 고유 식당명: ${allRestaurantNames.size}개`);

      // 2단계: Google Places에서 맛집명 수집
      console.log(`\n🔍 2단계: Google Places 맛집 크롤링`);
      const subRegions = this.getSubRegions(region);
      const googlePlacesRestaurants = [];
      
      for (const subRegion of subRegions) {
        const googleRestaurants = await this.searchGooglePlacesRestaurants(region, subRegion);
        googlePlacesRestaurants.push(...googleRestaurants);
        
        // API 호출 간격
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      console.log(`\n📊 Google Places 크롤링 결과:`);
      console.log(`   추출된 고유 식당명: ${googlePlacesRestaurants.length}개`);
      this.stats.googlePlacesRestaurants += googlePlacesRestaurants.length;
      this.stats.extractedRestaurants += allRestaurantNames.size;

      // 3단계: Google Places + YouTube 데이터 통합
      console.log(`\n🔄 3단계: 데이터 소스 통합`);
      const youtubeList = Array.from(allRestaurantNames);
      const mergedRestaurantNames = this.mergeRestaurantSources(youtubeList, googlePlacesRestaurants);
      this.stats.mergedRestaurants += mergedRestaurantNames.length;

      // 4단계: 카카오 API로 상세 정보 매칭
      console.log(`\n🗺️ 4단계: 카카오 Place ID 매칭`);
      console.log(`   처리할 식당명: ${mergedRestaurantNames.length}개\n`);
      
      let processedCount = 0;
      let successCount = 0;
      
      for (const restaurantName of mergedRestaurantNames) {
        processedCount++;
        process.stdout.write(`\r[${processedCount}/${mergedRestaurantNames.length}] ${restaurantName} 검색 중...`);

        const kakaoPlace = await this.searchKakaoPlace(restaurantName, region);
        if (!kakaoPlace) {
          process.stdout.write(`   ❌\n`);
          continue;
        }

        const lat = parseFloat(kakaoPlace.y);
        const lng = parseFloat(kakaoPlace.x);

        // 지역 검증
        if (!this.validateRegion(lat, lng, region)) {
          process.stdout.write(`   ❌ (지역 벗어남)\n`);
          continue;
        }

        process.stdout.write(`   ✅\n`);
        console.log(`   → ${kakaoPlace.place_name} (Place ID: ${kakaoPlace.id})`);
        this.stats.kakaoMatched++;
        successCount++;

        // 3단계: Google Places로 상세 정보 보강
        console.log(`   🔍 Google Places 상세 정보 수집 중...`);
        const googleDetails = await this.getGooglePlacesDetails(kakaoPlace);
        
        let googleData = null;
        if (googleDetails) {
          // 🔥 Google Places 사진 URL 생성
          const photoUrls = [];
          if (googleDetails.photos && googleDetails.photos.length > 0) {
            for (const photo of googleDetails.photos.slice(0, 10)) { // 최대 10장
              if (photo.photo_reference) {
                const photoUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=${photo.photo_reference}&key=${this.googleApiKey}`;
                photoUrls.push(photoUrl);
              }
            }
          }

          googleData = {
            placeId: googleDetails.place_id || null,
            rating: googleDetails.rating || null,
            userRatingsTotal: googleDetails.user_ratings_total || null,
            photos: photoUrls, // 🔥 실제 사용 가능한 이미지 URL들
            regularOpeningHours: googleDetails.regular_opening_hours || googleDetails.opening_hours || null,
            currentOpeningHours: googleDetails.current_opening_hours || null,
            businessStatus: googleDetails.business_status || null,
            reviews: googleDetails.reviews || [],
            phoneNumber: googleDetails.formatted_phone_number || null,
            website: googleDetails.website || null,
            priceLevel: googleDetails.price_level || null
          };
          this.stats.googleEnhanced++;
          console.log(`   ✅ Google Places 데이터 추가`);
        }

        // 4단계: 네이버 블로그 데이터 추가
        console.log(`   📝 네이버 블로그 검색 중...`);
        const naverBlogData = await this.searchNaverBlogs(restaurantName, kakaoPlace.road_address_name || kakaoPlace.address_name);
        
        if (naverBlogData) {
          this.stats.naverBlogAdded++;
          console.log(`   ✅ 네이버 블로그 ${naverBlogData.totalCount}개 추가`);
        }

        // 5단계: YouTube 통계 생성
        const youtubeStats = this.createYouTubeStats(restaurantName, allVideos);
        if (youtubeStats) {
          console.log(`   ✅ YouTube 언급 ${youtubeStats.mentionCount}회 추가`);
        }

        // 최종 데이터 구성
        const restaurantData = {
          placeId: kakaoPlace.id,
          name: kakaoPlace.place_name,
          address: kakaoPlace.address_name,
          roadAddress: kakaoPlace.road_address_name,
          latitude: lat,
          longitude: lng,
          category: kakaoPlace.category_name,
          phone: kakaoPlace.phone,
          url: kakaoPlace.place_url,
          region: region,
          city: this.extractCity(kakaoPlace.address_name),
          province: this.extractProvince(kakaoPlace.address_name),
          googlePlaces: googleData,
          naverBlog: naverBlogData,
          youtubeStats: youtubeStats, // 🔥 YouTube 통계 추가!
          source: 'youtube_crawler',
          tags: this.generateTags(restaurantName, kakaoPlace, region)
        };

        // Firestore에 저장
        await this.saveRestaurantData(restaurantData);
        
        // API 호출 간격
        await new Promise(resolve => setTimeout(resolve, 1500));
      }
      
      console.log(`\n\n📊 ${region} 지역 크롤링 완료:`);
      console.log(`   YouTube 맛집: ${youtubeList.length}개`);
      console.log(`   Google Places 맛집: ${googlePlacesRestaurants.length}개`);
      console.log(`   통합 후 총 맛집: ${mergedRestaurantNames.length}개`);
      console.log(`   카카오 매칭 성공: ${successCount}/${mergedRestaurantNames.length}개 (${Math.round(successCount/mergedRestaurantNames.length*100)}%)`);
      console.log(`   Firestore 저장: ${this.stats.saved}개`);
    }

    this.printFinalStats();
  }

  /**
   * 주소에서 시/도 추출
   */
  extractProvince(address) {
    if (!address) return '';
    const match = address.match(/(제주특별자치도|서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시|경기도|강원도|충청북도|충청남도|전라북도|전라남도|경상북도|경상남도)/);
    return match ? match[1] : '';
  }

  /**
   * 주소에서 시/군/구 추출
   */
  extractCity(address) {
    if (!address) return '';
    const match = address.match(/([가-힣]+[시군구])/);
    return match ? match[1] : '';
  }

  /**
   * YouTube 통계 생성
   */
  createYouTubeStats(restaurantName, allVideos) {
    // 해당 식당명이 언급된 영상들 찾기
    const mentionedVideos = allVideos.filter(video => {
      const title = video.snippet.title.toLowerCase();
      const description = video.snippet.description.toLowerCase();
      const restaurant = restaurantName.toLowerCase();
      
      return title.includes(restaurant) || description.includes(restaurant);
    });

    if (mentionedVideos.length === 0) {
      return null;
    }

    // 채널명 수집
    const channels = [...new Set(mentionedVideos.map(video => video.snippet.channelTitle))];
    
    // 대표 영상 선택 (가장 최근 또는 조회수 높은)
    const representativeVideo = mentionedVideos[0]; // 첫 번째 영상을 대표로
    
    return {
      mentionCount: mentionedVideos.length,
      channels: channels,
      firstMentionDate: mentionedVideos[mentionedVideos.length - 1]?.snippet.publishedAt,
      lastMentionDate: mentionedVideos[0]?.snippet.publishedAt,
      recentMentions: mentionedVideos.filter(video => {
        const publishDate = new Date(video.snippet.publishedAt);
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
        return publishDate > threeMonthsAgo;
      }).length,
      representativeVideo: {
        title: representativeVideo.snippet.title,
        channelName: representativeVideo.snippet.channelTitle,
        videoId: representativeVideo.id.videoId,
        viewCount: 0, // YouTube API v3에서는 search로 조회수를 바로 못가져옴
        publishedAt: representativeVideo.snippet.publishedAt,
        thumbnailUrl: representativeVideo.snippet.thumbnails?.medium?.url
      }
    };
  }

  /**
   * 식당 태그 생성
   */
  generateTags(restaurantName, kakaoPlace, region) {
    const tags = [];
    
    // 지역 태그 제거 (1번 요청 - 의미 없으므로)
    // tags.push(region);
    
    // 카테고리에서 마지막 2개 태그 추출 (하위 → 상위 순서)
    if (kakaoPlace.category_name) {
      const categoryParts = kakaoPlace.category_name.split(' > ');
      if (categoryParts.length > 1) {
        // 1순위: 최하위 카테고리 (가장 구체적)
        const lastCategory = categoryParts[categoryParts.length - 1];
        if (lastCategory && lastCategory !== '음식점') {
          tags.push(lastCategory);
        }
        
        // 2순위: 그 전 상위 카테고리 
        if (categoryParts.length > 2) {
          const secondLastCategory = categoryParts[categoryParts.length - 2];
          if (secondLastCategory && secondLastCategory !== '음식점' && secondLastCategory !== lastCategory) {
            tags.push(secondLastCategory);
          }
        }
      }
    }
    
    // 특별 태그
    if (restaurantName.includes('현지인') || restaurantName.includes('로컬')) {
      tags.push('찐로컬맛집');
    }
    
    return tags;
  }

  /**
   * 최종 통계 출력
   */
  printFinalStats() {
    this.log('\n' + '='.repeat(50));
    this.logSuccess('🎉 통합 크롤링 완료! 최종 통계:');
    this.log('='.repeat(50));
    this.log(`📺 YouTube 영상 수집: ${this.stats.youtubeVideos}개`);
    this.log(`🎥 YouTube 식당명 추출: ${this.stats.extractedRestaurants}개`);
    this.log(`🔍 Google Places 식당명 수집: ${this.stats.googlePlacesRestaurants}개`);
    this.log(`🔄 통합 후 총 식당명: ${this.stats.mergedRestaurants}개`);
    this.log(`🗺️ 카카오 매칭 성공: ${this.stats.kakaoMatched}개`);
    this.log(`📊 Google Places 상세 정보 보강: ${this.stats.googleEnhanced}개`);
    this.log(`📝 네이버 블로그 추가: ${this.stats.naverBlogAdded}개`);
    this.log(`💾 Firestore 저장: ${this.stats.saved}개`);
    this.log(`❌ 에러 발생: ${this.stats.errors}개`);
    this.log('='.repeat(50));
    this.log(`📈 향상된 발견율: ${Math.round((this.stats.mergedRestaurants / this.stats.extractedRestaurants) * 100)}% (기존 대비 ${this.stats.googlePlacesRestaurants}개 추가)`);
    this.log('='.repeat(50));
  }
}

// =============================================================================
// 🎬 실행
// =============================================================================

async function main() {
  try {
    const crawler = new UltimateRestaurantCrawler();
    await crawler.run();
    crawler.logSuccess('✅ 크롤링 프로세스 정상 완료');
  } catch (error) {
    console.error('❌ 크롤링 중 치명적 오류:', error);
    if (error.stack) {
      console.error('스택 트레이스:', error.stack);
    }
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = UltimateRestaurantCrawler;