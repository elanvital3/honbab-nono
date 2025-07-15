# 모달 시스템 사용 가이드

혼밥노노 앱의 모든 모달은 일관된 디자인과 사용성을 위해 통일된 컴포넌트를 사용합니다.

## 📋 사용 가능한 모달 컴포넌트

### 1. CommonConfirmDialog
**기본 확인/취소 다이얼로그**

```dart
// 기본 사용
final result = await CommonConfirmDialog.show(
  context: context,
  title: '제목',
  content: '내용',
);

// 삭제 확인 (빨간색)
final result = await CommonConfirmDialog.showDelete(
  context: context,
  title: '삭제 확인',
  content: '정말로 삭제하시겠습니까?',
);

// 완료 확인 (초록색)
final result = await CommonConfirmDialog.showComplete(
  context: context,
  title: '완료',
  content: '작업이 완료되었습니다.',
);

// 경고 확인 (주황색)
final result = await CommonConfirmDialog.showWarning(
  context: context,
  title: '경고',
  content: '주의가 필요한 작업입니다.',
);
```

### 2. CommonLoadingDialog
**로딩 상태 표시 다이얼로그**

```dart
// 기본 로딩
CommonLoadingDialog.show(
  context: context,
  message: '잠시만 기다려주세요...',
);

// 진행률 표시
CommonLoadingDialog.showProgress(
  context: context,
  message: '파일 업로드 중...',
  progress: 0.7, // 0.0 ~ 1.0
  showProgressText: true,
);

// 비동기 작업과 함께 사용
final result = await CommonLoadingDialog.showWithTask(
  context: context,
  message: '데이터 저장 중...',
  task: saveData(),
);

// 수동으로 닫기
CommonLoadingDialog.hide(context);
```

### 3. CommonSelectDialog
**선택 다이얼로그 (단일/다중 선택)**

```dart
// 단일 선택
final selectedValue = await CommonSelectDialog.showSingle<String>(
  context: context,
  title: '옵션 선택',
  options: [
    SelectOption(value: 'option1', label: '옵션 1'),
    SelectOption(value: 'option2', label: '옵션 2', subtitle: '설명'),
    SelectOption(value: 'option3', label: '옵션 3', icon: Icons.star),
  ],
);

// 다중 선택
final selectedValues = await CommonSelectDialog.showMultiple<String>(
  context: context,
  title: '여러 항목 선택',
  options: options,
  initialSelectedValues: ['option1'],
  showSearch: true,
  searchHint: '옵션 검색...',
);
```

### 4. CommonMeetingCompletionDialog
**모임 완료 전용 다이얼로그 (체크리스트 포함)**

```dart
final result = await CommonMeetingCompletionDialog.show(
  context: context,
  title: '모임 완료',
  subtitle: '모임을 완료하시겠습니까?',
  checklistItems: [
    '정산을 모두 완료하였나요?',
    '참여자들에게 평가 요청이 전송됩니다',
    '모든 평가가 완료되면 모임이 최종 완료됩니다',
  ],
  note: '호스트는 평가를 받는 대상이므로 평가하지 않습니다',
);
```

## 🎨 디자인 토큰

### 통일된 스타일 가이드
- **borderRadius**: 16px (모든 모달)
- **contentPadding**: 24px (제목과 내용)
- **actionsPadding**: 16px (버튼 영역)
- **버튼 borderRadius**: 12px
- **버튼 간격**: 12px

### 색상 시스템
- **Primary 버튼**: AppDesignTokens.primary (베이지)
- **Secondary 버튼**: 투명 배경 + 테두리
- **삭제 버튼**: Colors.red[400]
- **완료 버튼**: Colors.green[600]
- **경고 버튼**: Colors.orange[600]

### 버튼 순서 (왼쪽에서 오른쪽)
1. **취소** (TextButton, 회색)
2. **확인/실행** (ElevatedButton, 컬러)

## 📝 사용 규칙

### DO ✅
```dart
// 항상 공통 컴포넌트 사용
final result = await CommonConfirmDialog.show(...);

// 적절한 변형 선택
await CommonConfirmDialog.showDelete(...); // 삭제 시
await CommonLoadingDialog.show(...); // 로딩 시

// 의미있는 메시지 제공
CommonLoadingDialog.show(
  context: context,
  message: '데이터를 저장하는 중...', // 구체적
);
```

### DON'T ❌
```dart
// 직접 AlertDialog 사용 금지
showDialog(
  context: context,
  builder: (context) => AlertDialog(...), // ❌
);

// 일관성 없는 스타일
AlertDialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20), // ❌ 16px 사용
  ),
);

// 모호한 메시지
CommonLoadingDialog.show(
  context: context,
  message: '잠시만 기다려주세요...', // ❌ 너무 일반적
);
```

## 🔧 커스터마이징

새로운 모달이 필요한 경우:

1. **기존 컴포넌트 확장 우선 고려**
2. **디자인 토큰 준수**
3. **일관된 네이밍 규칙** (`Common___Dialog`)
4. **정적 팩토리 메서드 제공** (`.show()`, `.showXxx()`)

## 📊 마이그레이션 상태

### ✅ 완료된 화면
- `meeting_detail_screen.dart`: 모든 모달 통일 완료
- `home_screen.dart`: 일부 로딩 다이얼로그 통일 완료

### 🔄 진행중
- `account_deletion_screen.dart`: 4개 AlertDialog 대기
- `chat_room_screen.dart`, `chat_screen.dart`: 6개 AlertDialog 대기

### 📈 예상 효과
- **200+ 줄 코드 절약**
- **UI 일관성 100% 달성**
- **유지보수성 대폭 향상**
- **새 기능 개발 속도 증가**

---

**새로운 모달 추가 시 이 가이드를 참고하여 일관성을 유지해주세요!**