import 'package:flutter/material.dart';
import '../../styles/text_styles.dart';
import '../../constants/app_design_tokens.dart';

class SelectOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  
  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
  });
}

class CommonSelectDialog<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<SelectOption<T>> options;
  final T? initialValue;
  final bool allowMultiSelect;
  final List<T>? initialSelectedValues;
  final String confirmText;
  final String cancelText;
  final bool showSearch;
  final String? searchHint;
  
  const CommonSelectDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    this.initialValue,
    this.allowMultiSelect = false,
    this.initialSelectedValues,
    this.confirmText = '확인',
    this.cancelText = '취소',
    this.showSearch = false,
    this.searchHint,
  });

  @override
  State<CommonSelectDialog<T>> createState() => _CommonSelectDialogState<T>();
}

class _CommonSelectDialogState<T> extends State<CommonSelectDialog<T>> {
  late T? selectedValue;
  late Set<T> selectedValues;
  late List<SelectOption<T>> filteredOptions;
  final TextEditingController searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue;
    selectedValues = Set<T>.from(widget.initialSelectedValues ?? []);
    filteredOptions = List.from(widget.options);
    
    if (widget.showSearch) {
      searchController.addListener(_filterOptions);
    }
  }
  
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
  
  void _filterOptions() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredOptions = widget.options.where((option) {
        return option.label.toLowerCase().contains(query) ||
               (option.subtitle?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }
  
  void _onSingleSelect(T value) {
    setState(() {
      selectedValue = value;
    });
    Navigator.pop(context, value);
  }
  
  void _onMultiSelect(T value) {
    setState(() {
      if (selectedValues.contains(value)) {
        selectedValues.remove(value);
      } else {
        selectedValues.add(value);
      }
    });
  }
  
  void _confirmMultiSelect() {
    Navigator.pop(context, selectedValues.toList());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: widget.allowMultiSelect 
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : EdgeInsets.zero,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.onSurface,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subtitle!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppDesignTokens.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 검색 필드
            if (widget.showSearch) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: widget.searchHint ?? '검색...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppDesignTokens.outline.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppDesignTokens.outline.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppDesignTokens.primary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 옵션 리스트
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredOptions.length,
                itemBuilder: (context, index) {
                  final option = filteredOptions[index];
                  final isSelected = widget.allowMultiSelect
                      ? selectedValues.contains(option.value)
                      : selectedValue == option.value;
                  
                  return ListTile(
                    leading: option.leading ?? 
                        (option.icon != null 
                            ? Icon(option.icon, color: AppDesignTokens.primary)
                            : null),
                    title: Text(
                      option.label,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected 
                            ? AppDesignTokens.primary 
                            : AppDesignTokens.onSurface,
                      ),
                    ),
                    subtitle: option.subtitle != null
                        ? Text(
                            option.subtitle!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppDesignTokens.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: widget.allowMultiSelect
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) => _onMultiSelect(option.value),
                            activeColor: AppDesignTokens.primary,
                          )
                        : isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppDesignTokens.primary,
                              )
                            : null,
                    onTap: widget.allowMultiSelect
                        ? () => _onMultiSelect(option.value)
                        : () => _onSingleSelect(option.value),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: widget.allowMultiSelect
          ? [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppDesignTokens.outline.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        widget.cancelText,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppDesignTokens.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmMultiSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignTokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '${widget.confirmText} (${selectedValues.length})',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
          : null,
    );
  }

  /// 단일 선택 다이얼로그를 표시합니다.
  static Future<T?> showSingle<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<SelectOption<T>> options,
    T? initialValue,
    bool showSearch = false,
    String? searchHint,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (context) => CommonSelectDialog<T>(
        title: title,
        subtitle: subtitle,
        options: options,
        initialValue: initialValue,
        allowMultiSelect: false,
        showSearch: showSearch,
        searchHint: searchHint,
      ),
    );
  }

  /// 다중 선택 다이얼로그를 표시합니다.
  static Future<List<T>?> showMultiple<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<SelectOption<T>> options,
    List<T>? initialSelectedValues,
    String confirmText = '확인',
    String cancelText = '취소',
    bool showSearch = false,
    String? searchHint,
  }) async {
    return showDialog<List<T>>(
      context: context,
      builder: (context) => CommonSelectDialog<T>(
        title: title,
        subtitle: subtitle,
        options: options,
        allowMultiSelect: true,
        initialSelectedValues: initialSelectedValues,
        confirmText: confirmText,
        cancelText: cancelText,
        showSearch: showSearch,
        searchHint: searchHint,
      ),
    );
  }
}