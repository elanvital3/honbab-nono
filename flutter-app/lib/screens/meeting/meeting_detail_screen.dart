import 'package:flutter/material.dart';
import '../../models/meeting.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({
    super.key,
    required this.meeting,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  bool _isJoined = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('모임 상세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 공유 기능
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능 준비 중입니다')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildInfo(),
            _buildDescription(),
            _buildHost(),
            _buildParticipants(),
            const SizedBox(height: 100), // 버튼 공간 확보
          ],
        ),
      ),
      bottomNavigationBar: _buildJoinButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.meeting.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.meeting.isAvailable 
                      ? Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.meeting.isAvailable ? '모집중' : '마감',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.meeting.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.meeting.tags.map((tag) => Chip(
                label: Text(tag),
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                side: BorderSide.none,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.location_on,
            '장소',
            widget.meeting.location,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.access_time,
            '시간',
            '${widget.meeting.formattedDateTime} (${widget.meeting.timeAgo})',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.group,
            '인원',
            '${widget.meeting.currentParticipants}/${widget.meeting.maxParticipants}명',
          ),
          if (widget.meeting.price != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.payments,
              '예상 비용',
              '${widget.meeting.price!.toInt()}원',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '모임 설명',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.meeting.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHost() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '모임 주최자',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  widget.meeting.hostName[0],
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.meeting.hostName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '모임 호스트',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  // TODO: 호스트 프로필 보기
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('프로필 보기 기능 준비 중입니다')),
                  );
                },
                child: const Text('프로필 보기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipants() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참여자 (${widget.meeting.currentParticipants}/${widget.meeting.maxParticipants})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // 임시 참여자 리스트
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.meeting.currentParticipants,
            itemBuilder: (context, index) {
              final names = ['${widget.meeting.hostName} (주최자)', '김영희', '박철수', '이나영'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: index == 0 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      child: Text(
                        names[index][0],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      names[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.meeting.isAvailable
                ? () {
                    setState(() {
                      _isJoined = !_isJoined;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isJoined ? '모임에 참여했습니다!' : '모임 참여를 취소했습니다'),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isJoined 
                  ? Colors.grey 
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.meeting.isAvailable
                  ? (_isJoined ? '참여 취소' : '모임 참여하기')
                  : '모집 마감',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}