/**
 * 지역 검증 유틸리티
 * 유튜브 크롤링 지역과 카카오 API 주소가 일치하는지 확인
 */

class RegionValidator {
  
  /**
   * 지역별 주소 키워드 매핑
   */
  static getRegionKeywords() {
    return {
      '제주도': [
        '제주특별자치도', '제주시', '서귀포시', '제주도',
        '한림', '애월', '조천', '구좌', '성산', '표선', '남원', '안덕', '대정'
      ],
      '서울': [
        '서울특별시', '서울시', '서울',
        '강남구', '강동구', '강북구', '강서구', '관악구', '광진구', 
        '구로구', '금천구', '노원구', '도봉구', '동대문구', '동작구',
        '마포구', '서대문구', '서초구', '성동구', '성북구', '송파구',
        '양천구', '영등포구', '용산구', '은평구', '종로구', '중구', '중랑구'
      ],
      '부산': [
        '부산광역시', '부산시', '부산',
        '강서구 부산', '금정구 부산', '기장군', '남구 부산', '동구 부산', '동래구',
        '부산진구', '북구 부산', '사상구', '사하구', '서구 부산', '수영구',
        '연제구', '영도구', '중구 부산', '해운대구'
      ],
      '경주': [
        '경상북도', '경주시', '경주',
        '황리단길', '불국사', '첨성대', '안강', '현곡', '외동', '내남', '산내'
      ]
    };
  }

  /**
   * 주소에서 지역 추출
   */
  static extractRegionFromAddress(address) {
    if (!address) return null;
    
    const regionKeywords = this.getRegionKeywords();
    
    // 도/특별시/광역시를 먼저 체크 (더 구체적인 것 우선)
    const priorityKeywords = [
      '제주특별자치도', '서울특별시', '부산광역시', '대구광역시', 
      '인천광역시', '광주광역시', '대전광역시', '울산광역시', '경상북도'
    ];
    
    for (const keyword of priorityKeywords) {
      if (address.includes(keyword)) {
        if (keyword === '제주특별자치도') return '제주도';
        if (keyword === '서울특별시') return '서울';
        if (keyword === '부산광역시') return '부산';
        if (keyword === '경상북도' && address.includes('경주')) return '경주';
      }
    }
    
    // 그 다음 일반 키워드 체크
    for (const [region, keywords] of Object.entries(regionKeywords)) {
      for (const keyword of keywords) {
        if (address.includes(keyword)) {
          return region;
        }
      }
    }
    
    return null;
  }

  /**
   * 유튜브 크롤링 지역과 카카오 주소 일치 여부 확인
   */
  static validateRegionMatch(youtubeRegion, kakaoAddress) {
    const extractedRegion = this.extractRegionFromAddress(kakaoAddress);
    
    if (!extractedRegion) {
      console.log(`   ⚠️ 주소에서 지역 추출 실패: ${kakaoAddress}`);
      return false;
    }
    
    const isMatch = extractedRegion === youtubeRegion;
    
    if (!isMatch) {
      console.log(`   ❌ 지역 불일치: 유튜브(${youtubeRegion}) vs 카카오(${extractedRegion})`);
      console.log(`      주소: ${kakaoAddress}`);
    } else {
      console.log(`   ✅ 지역 일치 확인: ${youtubeRegion}`);
    }
    
    return isMatch;
  }

  /**
   * 좌표 기반 지역 검증 (백업 방법)
   */
  static validateRegionByCoordinates(region, latitude, longitude) {
    // 대략적인 지역별 좌표 범위
    const regionBounds = {
      '제주도': {
        minLat: 33.0, maxLat: 33.6,
        minLng: 126.0, maxLng: 127.0
      },
      '서울': {
        minLat: 37.4, maxLat: 37.7,
        minLng: 126.7, maxLng: 127.2
      },
      '부산': {
        minLat: 34.8, maxLat: 35.4,
        minLng: 128.7, maxLng: 129.4
      },
      '경주': {
        minLat: 35.6, maxLat: 36.1,
        minLng: 129.0, maxLng: 129.6
      }
    };
    
    const bounds = regionBounds[region];
    if (!bounds) return false;
    
    const isInBounds = latitude >= bounds.minLat && latitude <= bounds.maxLat &&
                      longitude >= bounds.minLng && longitude <= bounds.maxLng;
    
    if (!isInBounds) {
      console.log(`   ❌ 좌표 범위 벗어남: ${region} (${latitude}, ${longitude})`);
    }
    
    return isInBounds;
  }

  /**
   * 종합 지역 검증
   */
  static validateRegion(youtubeRegion, kakaoResult) {
    if (!kakaoResult) return false;
    
    // 0차: 체인점 예외 체크 (지역 무관하게 허용)
    if (this.isAllowedException(kakaoResult.placeName, youtubeRegion, kakaoResult.address)) {
      console.log(`   ⚡ 체인점 예외로 지역 검증 통과: ${kakaoResult.placeName}`);
      return true;
    }
    
    // 1차: 주소 기반 검증
    const addressMatch = this.validateRegionMatch(youtubeRegion, kakaoResult.address);
    
    // 2차: 좌표 기반 검증 (주소가 애매한 경우)
    const coordMatch = this.validateRegionByCoordinates(
      youtubeRegion, 
      kakaoResult.latitude, 
      kakaoResult.longitude
    );
    
    // 주소 매칭이 실패해도 좌표는 맞으면 허용 (경계 지역 고려)
    const finalResult = addressMatch || coordMatch;
    
    if (!finalResult) {
      console.log(`   ❌ 최종 지역 검증 실패: ${kakaoResult.placeName}`);
      console.log(`      예상: ${youtubeRegion}, 실제: ${kakaoResult.address}`);
    }
    
    return finalResult;
  }

  /**
   * 허용 가능한 예외 케이스 (체인점 등)
   */
  static isAllowedException(restaurantName, youtubeRegion, kakaoAddress) {
    // 전국 체인점은 허용
    const chainKeywords = [
      '맥도날드', 'KFC', '버거킹', '롯데리아', '맘스터치',
      '스타벅스', '이디야', '투썸플레이스', '할리스',
      '교촌치킨', 'BHC', '굽네치킨', '처갓집양념치킨',
      '도미노피자', '피자헛', '파파존스'
    ];
    
    for (const keyword of chainKeywords) {
      if (restaurantName.includes(keyword)) {
        console.log(`   ⚡ 체인점 예외 허용: ${restaurantName}`);
        return true;
      }
    }
    
    return false;
  }
}

module.exports = RegionValidator;