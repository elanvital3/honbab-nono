import 'package:flutter/material.dart';
import '../models/user.dart' as app_user;

/// 참여자 프로필 사진을 4등분해서 보여주는 위젯
class ParticipantProfileWidget extends StatelessWidget {
  final List<app_user.User> participants;
  final String currentUserId;
  final String hostId;
  final double size;

  const ParticipantProfileWidget({
    super.key,
    required this.participants,
    required this.currentUserId,
    required this.hostId,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    // 최대 4명까지만 표시
    final displayParticipants = participants.take(4).toList();
    final participantCount = displayParticipants.length;
    
    return Stack(
      children: [
        // 프로필 사진 그리드
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: _buildProfileGrid(context, displayParticipants),
          ),
        ),
        
        // 호스트 뱃지 (현재 사용자가 호스트인 경우)
        if (currentUserId == hostId)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star,
                color: Colors.white,
                size: size * 0.25,
              ),
            ),
          ),
        
        // 참여자 수가 4명 초과일 때 표시
        if (participants.length > 4)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${participants.length - 4}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileGrid(BuildContext context, List<app_user.User> users) {
    if (users.isEmpty) {
      return _buildEmptyProfile(context);
    }
    
    switch (users.length) {
      case 1:
        return _buildSingleProfile(context, users[0]);
      case 2:
        return _buildTwoProfiles(context, users);
      case 3:
        return _buildThreeProfiles(context, users);
      case 4:
      default:
        return _buildFourProfiles(context, users);
    }
  }

  Widget _buildEmptyProfile(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Icon(
        Icons.group,
        color: Theme.of(context).colorScheme.outline,
        size: size * 0.5,
      ),
    );
  }

  Widget _buildSingleProfile(BuildContext context, app_user.User user) {
    return _buildProfileImage(context, user, size);
  }

  Widget _buildTwoProfiles(BuildContext context, List<app_user.User> users) {
    return Row(
      children: [
        Expanded(child: _buildProfileImage(context, users[0], size)),
        Container(width: 0.5, color: Colors.white),
        Expanded(child: _buildProfileImage(context, users[1], size)),
      ],
    );
  }

  Widget _buildThreeProfiles(BuildContext context, List<app_user.User> users) {
    final halfSize = size / 2;
    return Column(
      children: [
        SizedBox(
          height: halfSize,
          child: Row(
            children: [
              Expanded(child: _buildProfileImage(context, users[0], halfSize)),
              Container(width: 0.5, color: Colors.white),
              Expanded(child: _buildProfileImage(context, users[1], halfSize)),
            ],
          ),
        ),
        Container(height: 0.5, color: Colors.white),
        SizedBox(
          height: halfSize,
          child: _buildProfileImage(context, users[2], halfSize),
        ),
      ],
    );
  }

  Widget _buildFourProfiles(BuildContext context, List<app_user.User> users) {
    final halfSize = size / 2;
    return Column(
      children: [
        SizedBox(
          height: halfSize,
          child: Row(
            children: [
              Expanded(child: _buildProfileImage(context, users[0], halfSize)),
              Container(width: 0.5, color: Colors.white),
              Expanded(child: _buildProfileImage(context, users[1], halfSize)),
            ],
          ),
        ),
        Container(height: 0.5, color: Colors.white),
        SizedBox(
          height: halfSize,
          child: Row(
            children: [
              Expanded(child: _buildProfileImage(context, users[2], halfSize)),
              Container(width: 0.5, color: Colors.white),
              Expanded(child: _buildProfileImage(context, users[3], halfSize)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage(BuildContext context, app_user.User user, double imageSize) {
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      return Image.network(
        user.profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialAvatar(context, user, imageSize);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        },
      );
    }
    
    return _buildInitialAvatar(context, user, imageSize);
  }

  Widget _buildInitialAvatar(BuildContext context, app_user.User user, double avatarSize) {
    // 사용자 이름의 첫 글자로 아바타 생성
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final isHost = user.id == hostId;
    
    return Container(
      color: isHost 
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: avatarSize * 0.4,
            fontWeight: FontWeight.bold,
            color: isHost 
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}