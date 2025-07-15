import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';
import '../../services/evaluation_service.dart';
import '../../services/user_service.dart';
import '../../models/user.dart';

class UserCommentsScreen extends StatefulWidget {
  final String userId;
  final bool isMyComments; // 본인 코멘트인지 여부

  const UserCommentsScreen({
    super.key,
    required this.userId,
    this.isMyComments = true,
  });

  @override
  State<UserCommentsScreen> createState() => _UserCommentsScreenState();
}

class _UserCommentsScreenState extends State<UserCommentsScreen> {
  List<Map<String, dynamic>> _comments = [];
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 정보와 코멘트 병렬로 로드
      final results = await Future.wait([
        UserService.getUser(widget.userId),
        EvaluationService.getUserComments(widget.userId),
      ]);

      final user = results[0] as User?;
      final comments = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _user = user;
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isMyComments 
            ? '받은 코멘트' 
            : '${_user?.name ?? "사용자"}님의 코멘트',
          style: AppTextStyles.headlineSmall,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: AppDesignTokens.surfaceContainer,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.isMyComments 
                ? '아직 받은 코멘트가 없습니다'
                : '아직 작성된 코멘트가 없습니다',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMyComments 
                ? '모임에 참여하고 평가를 받아보세요!'
                : '모임 참여 후 다른 참여자들이 코멘트를 남겨줄 거에요',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 헤더 정보
        if (_user != null) _buildHeader(),
        
        // 코멘트 리스트
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _comments.length,
            itemBuilder: (context, index) {
              return _buildCommentCard(_comments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 프로필 사진
          CircleAvatar(
            radius: 30,
            backgroundImage: _user!.profileImageUrl != null 
              ? NetworkImage(_user!.profileImageUrl!)
              : null,
            backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
            child: _user!.profileImageUrl == null 
              ? Text(
                  _user!.name.isNotEmpty ? _user!.name[0] : '?',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppDesignTokens.primary,
                  ),
                )
              : null,
          ),
          const SizedBox(height: 12),
          
          // 이름과 평점
          Text(
            _user!.name,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // 받은 코멘트 수
          Text(
            '총 ${_comments.length}개의 코멘트',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final DateTime? meetingDate = comment['meetingDateTime'] as DateTime?;
    final DateTime createdAt = comment['createdAt'] as DateTime;
    final String meetingLocation = comment['meetingLocation'] as String? ?? '알 수 없는 장소';
    final String? restaurantName = comment['meetingRestaurant'] as String?;
    final String commentText = comment['comment'] as String;
    final double rating = comment['averageRating'] as double? ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 모임 정보 헤더
          Row(
            children: [
              Icon(
                Icons.restaurant,
                size: 16,
                color: AppDesignTokens.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  restaurantName ?? meetingLocation,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppDesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          
          if (meetingDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${meetingDate.year}.${meetingDate.month.toString().padLeft(2, '0')}.${meetingDate.day.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 코멘트 내용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              commentText,
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 평점과 작성일
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 평점
              if (rating > 0) ...[
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: AppDesignTokens.primary,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppDesignTokens.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              
              // 작성일
              Text(
                '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}