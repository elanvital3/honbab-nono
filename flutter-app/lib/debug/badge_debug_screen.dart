import 'package:flutter/material.dart';
import '../../models/user_badge.dart';
import '../../components/user_badge_chip.dart';

class BadgeDebugScreen extends StatelessWidget {
  const BadgeDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('뱃지 디버그'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '이모지 개별 테스트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 이모지 개별 테스트
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildEmojiTest('🍽️', '식사'),
                _buildEmojiTest('🐌', '천천히'),
                _buildEmojiTest('⚡', '빨리'),
                _buildEmojiTest('🥗', '건강식'),
                _buildEmojiTest('📸', '사진'),
                _buildEmojiTest('💬', '수다'),
                _buildEmojiTest('🤫', '조용'),
                _buildEmojiTest('🎉', '분위기'),
                _buildEmojiTest('🌶️', '매운맛'),
                _buildEmojiTest('🍜', '국물'),
                _buildEmojiTest('🥩', '고기'),
                _buildEmojiTest('🌱', '비건'),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text(
              '뱃지 컴포넌트 테스트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 뱃지 컴포넌트 테스트
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UserBadge.allBadges.take(6).map((badge) => 
                UserBadgeChip(badgeId: badge.id)
              ).toList(),
            ),
            
            const SizedBox(height: 32),
            const Text(
              '모든 뱃지 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 모든 뱃지 리스트
            ...UserBadge.allCategories.map((category) {
              final badges = UserBadge.getBadgesByCategory(category);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...badges.map((badge) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: Center(
                        child: Text(
                          badge.emoji,
                          style: const TextStyle(
                            fontSize: 20,
                            fontFamily: null,
                          ),
                        ),
                      ),
                    ),
                    title: Text(badge.name),
                    subtitle: Text(badge.description),
                  )),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiTest(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: null, // 시스템 이모지 폰트 사용
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}