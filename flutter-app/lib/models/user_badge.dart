class UserBadge {
  final String id;
  final String name;
  final String emoji;
  final String category;
  final String description;

  const UserBadge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
  });

  // 모든 뱃지 목록
  static const List<UserBadge> allBadges = [
    // 식사 스타일
    UserBadge(
      id: 'eat_well',
      name: '잘 먹어요',
      emoji: '🍽️',
      category: '식사 스타일',
      description: '든든하게 많이 먹는 스타일',
    ),
    UserBadge(
      id: 'slow_eater',
      name: '천천히 오래먹어요',
      emoji: '🐌',
      category: '식사 스타일',
      description: '여유롭게 식사하는 스타일',
    ),
    UserBadge(
      id: 'fast_eater',
      name: '빨리빨리 먹어요',
      emoji: '⚡',
      category: '식사 스타일',
      description: '빠르게 식사하는 스타일',
    ),
    UserBadge(
      id: 'healthy_lover',
      name: '건강식 러버',
      emoji: '🥗',
      category: '식사 스타일',
      description: '건강한 음식 선호',
    ),

    // 성격/취향
    UserBadge(
      id: 'photographer',
      name: '나는야 포토그래퍼',
      emoji: '📸',
      category: '성격/취향',
      description: '음식 사진 찍기 좋아함',
    ),
    UserBadge(
      id: 'chatty',
      name: '수다쟁이',
      emoji: '💬',
      category: '성격/취향',
      description: '대화 많이 나누는 스타일',
    ),
    UserBadge(
      id: 'quiet',
      name: '조용조용',
      emoji: '🤫',
      category: '성격/취향',
      description: '조용히 식사하는 스타일',
    ),
    UserBadge(
      id: 'mood_maker',
      name: '분위기 메이커',
      emoji: '🎉',
      category: '성격/취향',
      description: '재밌게 분위기 띄우는 스타일',
    ),

    // 음식 취향
    UserBadge(
      id: 'spicy_challenger',
      name: '매운맛 챌린저',
      emoji: '🌶️',
      category: '음식 취향',
      description: '매운 음식 좋아함',
    ),
    UserBadge(
      id: 'soup_lover',
      name: '국물 러버',
      emoji: '🍜',
      category: '음식 취향',
      description: '국물 요리 선호',
    ),
    UserBadge(
      id: 'meat_lover',
      name: '고기 마니아',
      emoji: '🥩',
      category: '음식 취향',
      description: '고기 요리 전문',
    ),
    UserBadge(
      id: 'vegan_friendly',
      name: '비건 프렌들리',
      emoji: '🌱',
      category: '음식 취향',
      description: '채식 지향',
    ),
  ];

  // 카테고리별 뱃지 조회
  static List<UserBadge> getBadgesByCategory(String category) {
    return allBadges.where((badge) => badge.category == category).toList();
  }

  // ID로 뱃지 조회
  static UserBadge? getBadgeById(String id) {
    try {
      return allBadges.firstWhere((badge) => badge.id == id);
    } catch (e) {
      return null;
    }
  }

  // 모든 카테고리 목록
  static List<String> get allCategories {
    return allBadges.map((badge) => badge.category).toSet().toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserBadge && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$emoji $name';
}