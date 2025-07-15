import 'package:flutter/material.dart';
import '../../scripts/update_jeju_places.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class UpdateTestScreen extends StatefulWidget {
  const UpdateTestScreen({super.key});

  @override
  State<UpdateTestScreen> createState() => _UpdateTestScreenState();
}

class _UpdateTestScreenState extends State<UpdateTestScreen> {
  bool _isUpdating = false;
  List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      appBar: AppBar(
        title: Text(
          '제주도 데이터 업데이트',
          style: AppTextStyles.titleMedium,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏝️ 제주도 Google Places 업데이트',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              '• 사진을 최대 10장까지 가져옵니다\n'
              '• 상세 영업시간 정보를 추가합니다\n'
              '• 기존 YouTube 데이터는 보존됩니다\n'
              '• 모든 제주도 맛집을 업데이트합니다',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('업데이트 중...'),
                        ],
                      )
                    : const Text(
                        '제주도 업데이트 시작',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_logs.isNotEmpty) ...[
              Text(
                '📋 업데이트 로그',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppDesignTokens.outline.withOpacity(0.2),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontFamily: 'monospace',
                            color: _getLogColor(log),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getLogColor(String log) {
    if (log.contains('✅')) return Colors.green;
    if (log.contains('❌')) return Colors.red;
    if (log.contains('⚠️')) return Colors.orange;
    if (log.contains('🎯')) return AppDesignTokens.primary;
    return AppDesignTokens.onSurface;
  }
  
  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _logs.clear();
    });
    
    try {
      // 업데이트 실행
      await JejuPlacesUpdater.updateJejuRestaurants();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('제주도 데이터 업데이트가 완료되었습니다!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs.add('❌ 전체 오류: $e');
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}