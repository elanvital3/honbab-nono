import 'package:flutter/material.dart';
import '../../../models/meeting.dart';
import '../../../components/meeting_card.dart';
import '../../../services/auth_service.dart';
import '../../../styles/text_styles.dart';
import '../../../constants/app_design_tokens.dart';

class HomeTab extends StatefulWidget {
  final List<Meeting> meetings;
  final String selectedStatusFilter;
  final String selectedTimeFilter;
  final String selectedLocationFilter;
  final Function(String) onStatusFilterChanged;
  final Function(String) onTimeFilterChanged;
  final Function(String) onLocationFilterChanged;

  const HomeTab({
    super.key,
    required this.meetings,
    required this.selectedStatusFilter,
    required this.selectedTimeFilter,
    required this.selectedLocationFilter,
    required this.onStatusFilterChanged,
    required this.onTimeFilterChanged,
    required this.onLocationFilterChanged,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with AutomaticKeepAliveClientMixin {
  final List<String> _statusFilters = ['전체', '모집중', '모집완료'];
  final List<String> _timeFilters = ['오늘', '내일', '일주일', '전체', '지난모임'];

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    return Column(
      children: [
        // 필터 칩들 (두 줄로 배치)
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppDesignTokens.spacing1, horizontal: AppDesignTokens.spacing4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // 첫 번째 줄: 상태 필터
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._statusFilters.map(
                      (filter) => _buildFilterChip(
                        filter,
                        widget.selectedStatusFilter == filter,
                        () => widget.onStatusFilterChanged(filter),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 두 번째 줄: 시간 필터
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._timeFilters.map(
                      (filter) => _buildFilterChip(
                        filter,
                        widget.selectedTimeFilter == filter,
                        () => widget.onTimeFilterChanged(filter),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 모임 리스트
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // TODO: 모임 리스트 새로고침
              await Future.delayed(const Duration(seconds: 1));
            },
            child:
                widget.meetings.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '조건에 맞는 모임이 없어요',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '다른 필터를 선택하거나 첫 모임을 만들어보세요!',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: AppPadding.vertical8,
                      itemCount: widget.meetings.length,
                      itemBuilder: (context, index) {
                        final meeting = widget.meetings[index];
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          curve: Curves.easeOutBack,
                          child: MeetingCard(
                            meeting: meeting,
                            currentUserId: AuthService.currentUserId,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/meeting-detail',
                                arguments: meeting,
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}