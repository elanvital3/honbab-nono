import 'package:flutter/material.dart';
import '../models/user.dart';
import '../constants/app_design_tokens.dart';
import '../styles/text_styles.dart';
import 'common/common_card.dart';

class ParticipantEvaluationCard extends StatelessWidget {
  final User user;
  final int punctualityRating;
  final int mannersRating;
  final int meetAgainRating;
  final String comment;
  final bool hasExistingEvaluation;
  final Function(int) onPunctualityChanged;
  final Function(int) onMannersChanged;
  final Function(int) onMeetAgainChanged;
  final Function(String) onCommentChanged;

  const ParticipantEvaluationCard({
    super.key,
    required this.user,
    required this.punctualityRating,
    required this.mannersRating,
    required this.meetAgainRating,
    required this.comment,
    this.hasExistingEvaluation = false,
    required this.onPunctualityChanged,
    required this.onMannersChanged,
    required this.onMeetAgainChanged,
    required this.onCommentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 정보 헤더
          _buildUserHeader(),
          
          const SizedBox(height: 20),
          
          // 평가 항목들
          _buildRatingSection(
            '⏰ 시간준수',
            '약속한 시간에 맞춰 도착했나요?',
            punctualityRating,
            onPunctualityChanged,
          ),
          
          const SizedBox(height: 16),
          
          _buildRatingSection(
            '💬 대화매너',
            '대화하기 편하고 예의바른가요?',
            mannersRating,
            onMannersChanged,
          ),
          
          const SizedBox(height: 16),
          
          _buildRatingSection(
            '🤝 재만남의향',
            '다음에 또 만나고 싶나요?',
            meetAgainRating,
            onMeetAgainChanged,
          ),
          
          const SizedBox(height: 20),
          
          // 코멘트 입력
          _buildCommentSection(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
              ? NetworkImage(user.profileImageUrl!)
              : null,
          backgroundColor: AppDesignTokens.primary.withOpacity(0.15),
          child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppDesignTokens.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    user.name,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasExistingEvaluation)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppDesignTokens.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '수정',
                        style: AppTextStyles.caption.copyWith(
                          color: AppDesignTokens.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (user.rating > 0)
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.rating.toStringAsFixed(1),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(
    String title,
    String subtitle,
    int rating,
    Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' | ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[400],
              ),
            ),
            Expanded(
              child: Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () => onChanged(starValue),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.star,
                  size: 32,
                  color: starValue <= rating
                      ? Colors.amber
                      : Colors.grey[300],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '매우 아쉬워요',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
            Text(
              '매우 좋았어요',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추가 코멘트 (선택)',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onCommentChanged,
          maxLines: 2,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '좋았던 점이나 개선할 점을 자유롭게 작성해주세요',
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppDesignTokens.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(16),
            counterStyle: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey[500],
            ),
          ),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}