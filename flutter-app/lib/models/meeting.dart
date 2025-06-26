class Meeting {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime dateTime;
  final int maxParticipants;
  final int currentParticipants;
  final String hostName;
  final List<String> tags;
  final double? price;

  Meeting({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTime,
    required this.maxParticipants,
    this.currentParticipants = 1,
    required this.hostName,
    this.tags = const [],
    this.price,
  });

  bool get isAvailable => currentParticipants < maxParticipants;
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}일 후';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else {
      return '곧 시작';
    }
  }

  String get formattedDateTime {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}