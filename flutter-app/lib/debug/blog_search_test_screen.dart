import 'package:flutter/material.dart';
import '../../services/naver_blog_service.dart';
import '../../utils/address_parser.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class BlogSearchTestScreen extends StatefulWidget {
  const BlogSearchTestScreen({super.key});

  @override
  State<BlogSearchTestScreen> createState() => _BlogSearchTestScreenState();
}

class _BlogSearchTestScreenState extends State<BlogSearchTestScreen> {
  final _nameController = TextEditingController(text: '대춘해장국');
  final _addressController = TextEditingController(text: '서울특별시 강남구 역삼동 123-45');
  
  bool _isLoading = false;
  String _result = '';

  Future<void> _testBlogSearch() async {
    if (_nameController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // 1. 지역 키워드 추출 테스트
      final keywords = AddressParser.extractLocationKeywords(_addressController.text);
      _result += '🏷️ 추출된 지역 키워드: ${keywords.join(', ')}\n\n';
      
      // 2. 검색어 조합 생성 테스트
      final queries = AddressParser.generateSearchQueries(_nameController.text, _addressController.text);
      _result += '🔍 생성된 검색어들:\n';
      for (final query in queries) {
        _result += '   - $query\n';
      }
      _result += '\n';
      
      // 3. 실제 블로그 검색 테스트
      _result += '📝 블로그 검색 결과:\n';
      final blogData = await NaverBlogService.searchRestaurantBlogsWithAddress(
        _nameController.text, 
        _addressController.text
      );
      
      if (blogData != null) {
        _result += '총 ${blogData.totalCount}개 블로그 포스트 발견\n';
        _result += '필터링 후 ${blogData.posts.length}개 선별\n\n';
        
        for (int i = 0; i < blogData.posts.length; i++) {
          final post = blogData.posts[i];
          final score = AddressParser.calculateRelevanceScore(
            _nameController.text, 
            _addressController.text, 
            post.title, 
            post.description
          );
          
          _result += '${i + 1}. ${post.title}\n';
          _result += '   관련성: ${score.toStringAsFixed(1)}점\n';
          _result += '   작성자: ${post.bloggerName}\n';
          _result += '   내용: ${post.description.length > 50 ? post.description.substring(0, 50) + '...' : post.description}\n\n';
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
          '블로그 검색 테스트',
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
              onPressed: _isLoading ? null : _testBlogSearch,
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
                : const Text('블로그 검색 테스트'),
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