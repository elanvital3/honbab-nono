class AddressParser {
  /// 주소에서 주요 지역 정보를 추출합니다.
  static List<String> extractLocationKeywords(String address) {
    final keywords = <String>[];
    
    if (address.isEmpty) return keywords;
    
    // 주소를 공백으로 분리
    final parts = address.split(' ');
    
    for (final part in parts) {
      // 구 단위 추출 (예: 강남구, 서초구)
      if (part.endsWith('구') && part.length >= 3) {
        keywords.add(part);
      }
      
      // 동 단위 추출 (예: 역삼동, 논현동)
      else if (part.endsWith('동') && part.length >= 3) {
        keywords.add(part);
      }
      
      // 역명 추출 (예: 강남역, 역삼역)
      else if (part.endsWith('역') && part.length >= 3) {
        keywords.add(part);
      }
      
      // 특별시/광역시 추출 (예: 서울, 부산)
      else if (part.contains('서울') || part.contains('부산') || 
               part.contains('대구') || part.contains('인천') ||
               part.contains('광주') || part.contains('대전') ||
               part.contains('울산')) {
        final city = part.replaceAll(RegExp(r'특별시|광역시'), '');
        if (city.isNotEmpty) {
          keywords.add(city);
        }
      }
      
      // 도 단위 추출 (예: 경기도 → 경기)
      else if (part.endsWith('도') && part.length >= 3) {
        final province = part.replaceAll('도', '');
        keywords.add(province);
      }
    }
    
    // 중복 제거 및 길이순 정렬 (짧은 것부터)
    return keywords.toSet().toList()
      ..sort((a, b) => a.length.compareTo(b.length));
  }
  
  /// 검색어 조합을 생성합니다.
  static List<String> generateSearchQueries(String restaurantName, String address) {
    final queries = <String>[];
    final locationKeywords = extractLocationKeywords(address);
    
    // 기본 검색어
    queries.add('$restaurantName 맛집');
    
    // 지역 정보와 조합
    for (final keyword in locationKeywords) {
      queries.add('$restaurantName $keyword 맛집');
      queries.add('$restaurantName $keyword');
    }
    
    // 여러 지역 정보 조합 (최대 2개)
    if (locationKeywords.length >= 2) {
      queries.add('$restaurantName ${locationKeywords[0]} ${locationKeywords[1]} 맛집');
    }
    
    return queries;
  }
  
  /// 블로그 포스트가 해당 식당과 관련있는지 검증합니다.
  static double calculateRelevanceScore(
    String restaurantName, 
    String address, 
    String blogTitle, 
    String blogDescription
  ) {
    double score = 0.0;
    final content = '$blogTitle $blogDescription'.toLowerCase();
    final restaurantLower = restaurantName.toLowerCase();
    final locationKeywords = extractLocationKeywords(address);
    
    // 식당명 포함 여부 (가장 중요)
    if (content.contains(restaurantLower)) {
      score += 50.0;
    }
    
    // 지역명 포함 여부
    for (final keyword in locationKeywords) {
      if (content.contains(keyword.toLowerCase())) {
        score += 20.0;
        break; // 하나라도 포함되면 충분
      }
    }
    
    // 맛집 관련 키워드
    final foodKeywords = ['맛집', '후기', '리뷰', '방문', '먹어봤', '다녀왔', '추천'];
    for (final keyword in foodKeywords) {
      if (content.contains(keyword)) {
        score += 5.0;
      }
    }
    
    // 광고성 키워드 감점
    final adKeywords = ['광고', '협찬', '제공', '할인', '쿠폰', '이벤트'];
    for (final keyword in adKeywords) {
      if (content.contains(keyword)) {
        score -= 10.0;
      }
    }
    
    return score.clamp(0.0, 100.0);
  }
}