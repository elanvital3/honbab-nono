import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../styles/text_styles.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onTap;
  final String? currentUserId; // 현재 사용자 ID (호스트 표시용)

  const MeetingCard({
    super.key,
    required this.meeting,
    this.onTap,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint('🔥 MeetingCard GestureDetector 클릭됨');
        debugPrint('🔥 onTap 함수: ${onTap != null ? "존재함" : "null"}');
        if (onTap != null) {
          debugPrint('🔥 onTap 함수 호출 시작');
          onTap!();
          debugPrint('🔥 onTap 함수 호출 완료');
        } else {
          debugPrint('❌ onTap 함수가 null입니다');
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),  // 당근마켓 스타일
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),  // 당근마켓 스타일
          elevation: 0.5,  // 당근마켓 스타일 미약한 그림자
          shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),  // 당근마켓 스타일 더 촘촘한 패딩
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽 이미지 영역 (당근마켓 스타일)
              Stack(
                children: [
                  Container(
                    width: 72,  // 당근마켓 스타일
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),  // 당근마켓 스타일
                      color: Theme.of(context).colorScheme.surfaceContainer,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: meeting.representativeImageUrl != null && meeting.representativeImageUrl!.isNotEmpty
                        ? Image.network(
                            meeting.representativeImageUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // 이미지 로드 실패 시 기본 아이콘 표시
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: Icon(
                                  Icons.restaurant,
                                  size: 28,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              // 로딩 중 표시
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainer,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / 
                                          loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.restaurant,
                            size: 28,  // 더 작게
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  
                  // 호스트 뱃지 (내가 호스트일 때만 표시)
                  if (currentUserId != null && currentUserId == meeting.hostId)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),  // 당근마켓 스타일
              
              // 오른쪽 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목과 상태
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            meeting.restaurantName ?? meeting.location,  // 식당 이름을 메인 타이틀로
                            style: AppTextStyles.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: meeting.status == 'completed'
                                ? Theme.of(context).colorScheme.outline.withOpacity(0.6)  // 완료된 모임
                                : meeting.isAvailable 
                                    ? Theme.of(context).colorScheme.primary  // 베이지 포인트!
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            meeting.status == 'completed' 
                                ? '완료'
                                : meeting.isAvailable ? '모집중' : '마감',
                            style: TextStyle(
                              fontSize: 11,
                              color: meeting.status == 'completed'
                                  ? Colors.white  // 완료된 모임은 흰 글씨
                                  : meeting.isAvailable 
                                      ? Colors.white  // 베이지 배경에 흰 글씨
                                      : Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // 모임 설명 (간단히)
                    Text(
                      meeting.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // 위치와 시간
                    Row(
                      children: [
                        Icon(
                          Icons.location_on, 
                          size: 13, 
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            meeting.fullAddress ?? meeting.location,
                            style: TextStyle(
                              fontSize: 12,  // 당근마켓 스타일
                              color: Theme.of(context).colorScheme.outline,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(
                          Icons.access_time, 
                          size: 14, 
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          meeting.formattedDateTime,  // 당근마켓처럼 간단하게
                          style: TextStyle(
                            fontSize: 12,  // 당근마켓 스타일
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // 하단 정보 (호스트 + 인원)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: currentUserId != null && currentUserId == meeting.hostId
                                  ? Theme.of(context).colorScheme.primary  // 내가 호스트면 베이지색
                                  : Theme.of(context).colorScheme.surfaceContainer,
                              child: Text(
                                meeting.hostName[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: currentUserId != null && currentUserId == meeting.hostId
                                      ? Colors.white  // 내가 호스트면 흰색 텍스트
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              children: [
                                Text(
                                  meeting.hostName,
                                  style: TextStyle(
                                    fontSize: 11,  // 당근마켓 스타일
                                    color: currentUserId != null && currentUserId == meeting.hostId
                                        ? Theme.of(context).colorScheme.onSurface  // 내가 호스트면 더 진한 색
                                        : Theme.of(context).colorScheme.outline,  // 연한 회색
                                    fontWeight: currentUserId != null && currentUserId == meeting.hostId
                                        ? FontWeight.w600  // 내가 호스트면 더 굵게
                                        : FontWeight.normal,
                                  ),
                                ),
                                // 내가 호스트일 때 작은 호스트 표시 추가
                                if (currentUserId != null && currentUserId == meeting.hostId) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      '내 모임',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group, 
                                size: 12, 
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${meeting.currentParticipants}/${meeting.maxParticipants}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // 태그들 (성별 선호도 포함)
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        // 성별 제한 태그 (누구나가 아닐 때만 표시)
                        if (meeting.genderRestriction != 'all')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  meeting.genderRestrictionIcon,
                                  style: const TextStyle(
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  meeting.genderRestrictionText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // 기존 태그들 (최대 2개)
                        ...meeting.tags.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}