import 'package:flutter/material.dart';
import '../models/meeting.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onTap;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),  // 당근마켓 스타일
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),  // 당근마켓 스타일
        elevation: 0.5,  // 당근마켓 스타일 미약한 그림자
        shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),  // 당근마켓 스타일 더 촘촘한 패딩
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽 이미지 영역 (당근마켓 스타일)
              Container(
                width: 72,  // 당근마켓 스타일
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),  // 당근마켓 스타일
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 28,  // 더 작게
                  color: Theme.of(context).colorScheme.outline,
                ),
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
                            style: TextStyle(
                              fontSize: 15,  // 당근마켓 스타일
                              fontWeight: FontWeight.w600,  // 당근마켓 스타일
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.3,  // 줄간격
                            ),
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
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                              child: Text(
                                meeting.hostName[0],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              meeting.hostName,
                              style: TextStyle(
                                fontSize: 11,  // 당근마켓 스타일
                                color: Theme.of(context).colorScheme.outline,  // 연한 회색
                                fontWeight: FontWeight.normal,
                              ),
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
                        // 성별 선호도 태그 (항상 표시)
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
                          child: Text(
                            meeting.genderPreference,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
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