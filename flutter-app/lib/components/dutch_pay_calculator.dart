import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_design_tokens.dart';
import '../styles/text_styles.dart';
import '../components/common/common_button.dart';

class DutchPayCalculator extends StatefulWidget {
  final int participantCount;
  final String meetingName;
  final List<String>? participantNames;
  
  const DutchPayCalculator({
    super.key,
    required this.participantCount,
    required this.meetingName,
    this.participantNames,
  });

  @override
  State<DutchPayCalculator> createState() => _DutchPayCalculatorState();
}

class _DutchPayCalculatorState extends State<DutchPayCalculator> {
  // 계산 모드: 'equal' (균등 분할), 'individual' (각자 계산)
  String _calculationMode = 'equal';
  
  // 균등 분할 모드
  final TextEditingController _totalAmountController = TextEditingController();
  
  // 각자 계산 모드
  List<TextEditingController> _individualControllers = [];
  List<String> _participantNames = [];
  
  @override
  void initState() {
    super.initState();
    _initializeParticipants();
  }
  
  void _initializeParticipants() {
    _individualControllers = List.generate(
      widget.participantCount,
      (_) => TextEditingController(),
    );
    
    // 실제 참여자 이름이 있으면 사용, 없으면 기본값 사용
    if (widget.participantNames != null && widget.participantNames!.length >= widget.participantCount) {
      _participantNames = List.from(widget.participantNames!.take(widget.participantCount));
    } else {
      _participantNames = List.generate(
        widget.participantCount,
        (index) => '참여자 ${index + 1}',
      );
    }
  }
  
  @override
  void dispose() {
    _totalAmountController.dispose();
    for (final controller in _individualControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // 총 금액 계산 (균등 분할)
  double get _totalAmount {
    return double.tryParse(_totalAmountController.text) ?? 0;
  }
  
  // 1인당 금액 (균등 분할)
  double get _perPersonAmount {
    if (widget.participantCount == 0) return 0;
    return _totalAmount / widget.participantCount;
  }
  
  // 개별 총액 (각자 계산)
  double get _individualTotal {
    double total = 0;
    for (final controller in _individualControllers) {
      total += double.tryParse(controller.text) ?? 0;
    }
    return total;
  }
  
  // 계산 결과 텍스트 생성
  String _generateResultText() {
    if (_calculationMode == 'equal') {
      return '''
🍽️ ${widget.meetingName}
📍 더치페이 계산 결과

총 인원: ${widget.participantCount}명
총 금액: ${_numberFormat(_totalAmount)}원
💰 1인당: ${_numberFormat(_perPersonAmount)}원
''';
    } else {
      final buffer = StringBuffer();
      buffer.writeln('🍽️ ${widget.meetingName}');
      buffer.writeln('📍 각자 계산 결과\n');
      
      for (int i = 0; i < widget.participantCount; i++) {
        final amount = double.tryParse(_individualControllers[i].text) ?? 0;
        buffer.writeln('${_participantNames[i]}: ${_numberFormat(amount)}원');
      }
      
      buffer.writeln('\n총 합계: ${_numberFormat(_individualTotal)}원');
      
      return buffer.toString();
    }
  }
  
  String _numberFormat(double number) {
    return number.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  Future<void> _shareToChat() async {
    try {
      // ChatService import 필요
      final text = _generateResultText();
      
      // 현재 모임의 채팅방에 메시지 전송
      // 이 함수는 MeetingDetailScreen에서 호출되므로, 부모에서 meetingId를 받아야 합니다
      // 임시로 Navigator.pop으로 결과를 반환하여 부모에서 처리하도록 구현
      Navigator.pop(context, text);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('채팅방 공유 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calculate,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '더치페이 계산기',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // 바디
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 계산 모드 선택
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeButton(
                            'equal',
                            '균등 분할',
                            Icons.groups,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModeButton(
                            'individual',
                            '각자 계산',
                            Icons.person,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 입력 필드들
                    if (_calculationMode == 'equal')
                      _buildEqualSplitInput()
                    else
                      _buildIndividualInput(),
                    
                    const SizedBox(height: 24),
                    
                    // 결과 표시
                    _buildResultSection(),
                  ],
                ),
              ),
            ),
            
            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: CommonButton(
                text: '채팅방 공유하기',
                onPressed: _shareToChat,
                variant: ButtonVariant.primary,
                icon: const Icon(Icons.share),
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModeButton(String mode, String label, IconData icon) {
    final isSelected = _calculationMode == mode;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _calculationMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEqualSplitInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '총 금액',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _totalAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0',
            suffixText: '원',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '참여 인원: ${widget.participantCount}명',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildIndividualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '개별 금액 입력',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(widget.participantCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _individualControllers[index],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _participantNames[index],
                hintText: '0',
                suffixText: '원',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (_) => setState(() {}),
            ),
          );
        }),
      ],
    );
  }
  
  
  Widget _buildResultSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '계산 결과',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_calculationMode == 'equal') ...[
            _buildResultRow('총 금액', '${_numberFormat(_totalAmount)}원'),
            const Divider(height: 20),
            _buildResultRow(
              '1인당',
              '${_numberFormat(_perPersonAmount)}원',
              isHighlight: true,
            ),
          ] else ...[
            ..._buildIndividualResults(),
            const Divider(height: 20),
            _buildResultRow(
              '총 합계',
              '${_numberFormat(_individualTotal)}원',
              isHighlight: true,
            ),
          ],
        ],
      ),
    );
  }
  
  List<Widget> _buildIndividualResults() {
    final results = <Widget>[];
    
    for (int i = 0; i < widget.participantCount; i++) {
      final amount = double.tryParse(_individualControllers[i].text) ?? 0;
      
      results.add(_buildResultRow(
        _participantNames[i],
        '${_numberFormat(amount)}원',
      ));
    }
    
    return results;
  }
  
  Widget _buildResultRow(String label, String value, {
    bool isHighlight = false,
    bool isSubtext = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSubtext ? 14 : 16,
              color: isSubtext ? Colors.grey[600] : Colors.black87,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 16,
              color: isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}