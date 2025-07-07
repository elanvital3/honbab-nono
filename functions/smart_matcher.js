/**
 * 스마트 맛집 매칭 시스템
 * - 간단하지만 정확한 매칭 알고리즘
 * - 한국어 식당명에 최적화
 */

class SmartMatcher {
  
  /**
   * 문자열 정규화 (띄어쓰기, 특수문자 제거)
   */
  static normalizeString(str) {
    if (!str) return '';
    return str.toLowerCase()
      .replace(/\s+/g, '')           // 모든 공백 제거
      .replace(/[\-\_\.]/g, '')      // 하이픈, 언더스코어, 점 제거
      .replace(/[()]/g, '')          // 괄호 제거
      .trim();
  }
  
  /**
   * 두 문자열의 유사도 계산 (0~1)
   * 띄어쓰기와 특수문자 차이를 무시하고 비교
   */
  static calculateSimilarity(str1, str2) {
    if (!str1 || !str2) return 0;
    
    const s1 = this.normalizeString(str1);
    const s2 = this.normalizeString(str2);
    
    if (s1 === s2) return 1.0;
    
    // 긴 문자열에서 짧은 문자열이 얼마나 포함되는지 계산
    const [shorter, longer] = s1.length <= s2.length ? [s1, s2] : [s2, s1];
    
    if (shorter.length === 0) return 0;
    
    // 완전 포함 체크 (정규화된 문자열로)
    if (longer.includes(shorter)) {
      return shorter.length / longer.length;
    }
    
    // 공통 문자 개수 체크 (순서 고려)
    let commonChars = 0;
    for (let i = 0; i < shorter.length; i++) {
      if (longer.includes(shorter[i])) {
        commonChars++;
      }
    }
    
    return commonChars / shorter.length;
  }
  
  /**
   * 식당명에서 핵심 키워드 추출
   */
  static extractKeywords(restaurantName) {
    if (!restaurantName) return [];
    
    // 불필요한 접미사 제거
    const suffixes = ['갤러리', '카페', '레스토랑', '식당', '횟집', '맛집', '집', '점', '관'];
    let cleanName = restaurantName;
    
    for (const suffix of suffixes) {
      if (cleanName.endsWith(suffix)) {
        cleanName = cleanName.slice(0, -suffix.length);
      }
    }
    
    // 2글자 이상의 의미있는 단어들 추출
    const keywords = [];
    
    // 전체 이름 (정규화된 형태도 포함)
    if (cleanName.length >= 2) {
      keywords.push(cleanName);
      keywords.push(this.normalizeString(cleanName)); // 정규화된 형태 추가
    }
    
    // 단어 분리 (공백, 특수문자 기준)
    const words = cleanName.split(/[\s\-\_\.]+/).filter(word => word.length >= 2);
    keywords.push(...words);
    
    // 단어들의 정규화된 형태도 추가
    words.forEach(word => {
      if (word.length >= 2) {
        keywords.push(this.normalizeString(word));
      }
    });
    
    return [...new Set(keywords)]; // 중복 제거
  }
  
  /**
   * 지역 필터링 (기본적인 지역 검증)
   */
  static isLocationMatch(targetRegion, kakaoAddress) {
    if (!targetRegion || !kakaoAddress) return true; // 정보 없으면 통과
    
    const region = targetRegion.toLowerCase();
    const address = kakaoAddress.toLowerCase();
    
    // 주요 지역 매칭
    const regionMap = {
      '제주도': ['제주', '서귀포'],
      '서울': ['서울'],
      '부산': ['부산'],
      '경주': ['경주', '경북'],
      '대구': ['대구'],
      '인천': ['인천'],
      '광주': ['광주'],
      '대전': ['대전'],
      '울산': ['울산']
    };
    
    const matchingTerms = regionMap[region] || [region];
    return matchingTerms.some(term => address.includes(term));
  }
  
  /**
   * 카카오 검색 결과에서 최적 매칭 찾기
   */
  static findBestMatch(restaurantName, kakaoResults, targetRegion = null) {
    if (!kakaoResults || kakaoResults.length === 0) {
      return null;
    }
    
    const keywords = this.extractKeywords(restaurantName);
    console.log(`🔍 키워드 추출: "${restaurantName}" → [${keywords.join(', ')}]`);
    
    let bestMatch = null;
    let bestScore = 0;
    
    for (const place of kakaoResults) {
      let score = 0;
      const placeName = place.place_name || '';
      const placeAddress = place.address_name || '';
      
      // 1. 이름 유사도 (가중치: 70%)
      const nameSimilarity = this.calculateSimilarity(restaurantName, placeName);
      score += nameSimilarity * 0.7;
      
      // 2. 키워드 매칭 (가중치: 20%) - 정규화된 매칭
      let keywordMatches = 0;
      const normalizedPlaceName = this.normalizeString(placeName);
      
      for (const keyword of keywords) {
        const normalizedKeyword = this.normalizeString(keyword);
        if (normalizedPlaceName.includes(normalizedKeyword)) {
          keywordMatches++;
        }
      }
      const keywordScore = keywords.length > 0 ? keywordMatches / keywords.length : 0;
      score += keywordScore * 0.2;
      
      // 3. 지역 매칭 (가중치: 10%)
      const locationMatch = this.isLocationMatch(targetRegion, placeAddress);
      if (locationMatch) {
        score += 0.1;
      }
      
      console.log(`   ${placeName}: 점수=${score.toFixed(3)} (이름=${nameSimilarity.toFixed(2)}, 키워드=${keywordScore.toFixed(2)}, 지역=${locationMatch})`);
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = {
          ...place,
          matchScore: score,
          nameSimilarity,
          keywordScore,
          locationMatch
        };
      }
    }
    
    // 최소 임계값 확인 (0.3 이상이어야 매칭)
    if (bestScore >= 0.3) {
      console.log(`✅ 최적 매칭: "${bestMatch.place_name}" (점수: ${bestScore.toFixed(3)})`);
      return bestMatch;
    } else {
      console.log(`❌ 매칭 점수 부족: 최고 점수 ${bestScore.toFixed(3)} < 0.3`);
      return null;
    }
  }
  
  /**
   * 매칭 결과 검증 (사후 검증)
   */
  static validateMatch(originalName, matchedPlace) {
    if (!matchedPlace) return false;
    
    const score = matchedPlace.matchScore || 0;
    const nameSimilarity = matchedPlace.nameSimilarity || 0;
    
    // 기본 검증
    if (score < 0.3) return false;
    
    // 이름이 너무 다르면 거부
    if (nameSimilarity < 0.2) return false;
    
    // 너무 일반적인 매칭 거부
    const matchedName = matchedPlace.place_name.toLowerCase();
    const originalLower = originalName.toLowerCase();
    
    // 1. 매칭된 이름이 너무 일반적인 경우 거부
    const tooGeneric = ['맛집', '식당', '카페', '레스토랑', '음식점'];
    if (tooGeneric.some(generic => matchedName === generic || matchedName.endsWith(generic))) {
      console.log(`⚠️ 너무 일반적인 매칭: "${originalName}" → "${matchedPlace.place_name}"`);
      return false;
    }
    
    // 2. 지역명만 매칭되는 경우 거부 (예: "제주맛집")
    const regions = ['제주', '서울', '부산', '경주', '대구', '인천', '광주', '대전'];
    const isOnlyRegionMatch = regions.some(region => 
      originalLower.includes(region) && 
      matchedName.includes(region) && 
      matchedName.replace(region, '').trim().length <= 2
    );
    
    if (isOnlyRegionMatch) {
      console.log(`⚠️ 지역명만 매칭됨: "${originalName}" → "${matchedPlace.place_name}"`);
      return false;
    }
    
    return true;
  }
}

module.exports = SmartMatcher;