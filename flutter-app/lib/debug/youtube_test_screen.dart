import 'package:flutter/material.dart';
import '../../services/youtube_service.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class YoutubeTestScreen extends StatefulWidget {
  const YoutubeTestScreen({super.key});

  @override
  State<YoutubeTestScreen> createState() => _YoutubeTestScreenState();
}

class _YoutubeTestScreenState extends State<YoutubeTestScreen> {
  final _nameController = TextEditingController(text: '대춘해장국');
  final _addressController = TextEditingController(text: '서울특별시 강남구 역삼동 123-45');
  
  bool _isLoading = false;
  String _result = '';

  Future<void> _testYoutubeSearch() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      _result += '🎥 유튜브 검색 테스트 시작\n\n';
      
      // 1. API 키 테스트
      _result += '🔑 API 키 테스트 중...\n';
      final keyValid = await YoutubeService.testApiKey();
      _result += keyValid ? '✅ API 키 유효\n\n' : '❌ API 키 무효\n\n';
      
      if (!keyValid) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // 2. 실제 유튜브 검색 테스트
      _result += '🎥 유튜브 검색 결과:\n';
      final youtubeStats = await YoutubeService.searchRestaurantVideos(
        _nameController.text, 
        _addressController.text
      );
      
      if (youtubeStats != null) {
        _result += '✅ 검색 성공!\n';
        _result += '총 ${youtubeStats.mentionCount}개 영상 발견\n';
        _result += '채널 수: ${youtubeStats.channels.length}개\n';
        _result += '최근 언급: ${youtubeStats.recentMentions}개\n\n';
        
        _result += '📺 채널 목록:\n';
        for (final channel in youtubeStats.channels) {
          _result += '   - $channel\n';
        }
        _result += '\n';
        
        if (youtubeStats.representativeVideo != null) {
          final video = youtubeStats.representativeVideo!;
          _result += '🎬 대표 영상:\n';
          _result += '   제목: ${video.title}\n';
          _result += '   채널: ${video.channelName}\n';
          _result += '   영상ID: ${video.videoId}\n';
          _result += '   업로드일: ${video.publishedAt}\n';
        }
      } else {
        _result += '❌ 검색 실패\n';
      }
    } catch (e) {
      _result += '❌ 오류 발생: $e\n';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        title: Text(
          '유튜브 검색 테스트',
          style: AppTextStyles.titleLarge,
        ),
        backgroundColor: AppDesignTokens.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '식당 정보',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '식당명',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 12),
            
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: '주소',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testYoutubeSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('유튜브 검색 테스트'),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              '검색 결과',
              style: AppTextStyles.titleMedium,
            ),
            
            const SizedBox(height: 12),
            
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppDesignTokens.outline),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? '테스트 버튼을 눌러 검색해보세요.' : _result,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}