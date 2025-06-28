import 'package:flutter/material.dart';
import '../../constants/app_design_tokens.dart';
import '../../styles/text_styles.dart';

enum ButtonVariant { primary, secondary, outline, text }
enum ButtonSize { small, medium, large }

class CommonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final bool fullWidth;

  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final textStyle = _getTextStyle();
    final buttonHeight = _getButtonHeight();

    Widget buttonChild = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == ButtonVariant.primary 
                    ? Colors.white 
                    : AppDesignTokens.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                SizedBox(width: AppDesignTokens.spacing2),
              ],
              Text(text, style: textStyle),
            ],
          );

    return SizedBox(
      height: buttonHeight,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: buttonChild,
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppDesignTokens.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppDesignTokens.outline,
          elevation: AppDesignTokens.elevationLow,
          padding: _getButtonPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.medium,
          ),
        );
      case ButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppDesignTokens.surfaceContainer,
          foregroundColor: AppDesignTokens.onSurface,
          disabledBackgroundColor: AppDesignTokens.outline,
          elevation: 0,
          padding: _getButtonPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.medium,
          ),
        );
      case ButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppDesignTokens.primary,
          disabledBackgroundColor: Colors.transparent,
          elevation: 0,
          padding: _getButtonPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.medium,
            side: BorderSide(
              color: onPressed != null 
                  ? AppDesignTokens.primary 
                  : AppDesignTokens.outline,
            ),
          ),
        );
      case ButtonVariant.text:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppDesignTokens.primary,
          disabledBackgroundColor: Colors.transparent,
          elevation: 0,
          padding: _getButtonPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.medium,
          ),
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case ButtonSize.small:
        return AppTextStyles.labelMedium.copyWith(
          color: _getTextColor(),
        );
      case ButtonSize.medium:
        return AppTextStyles.labelLarge.copyWith(
          color: _getTextColor(),
        );
      case ButtonSize.large:
        return AppTextStyles.titleMedium.copyWith(
          color: _getTextColor(),
        );
    }
  }

  Color _getTextColor() {
    if (onPressed == null) return AppDesignTokens.outline;
    
    switch (variant) {
      case ButtonVariant.primary:
        return Colors.white;
      case ButtonVariant.secondary:
        return AppDesignTokens.onSurface;
      case ButtonVariant.outline:
      case ButtonVariant.text:
        return AppDesignTokens.primary;
    }
  }

  EdgeInsetsGeometry _getButtonPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing4,
          vertical: AppDesignTokens.spacing2,
        );
      case ButtonSize.medium:
        return AppPadding.buttonPadding;
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.spacing8,
          vertical: AppDesignTokens.spacing4,
        );
    }
  }

  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return AppDesignTokens.buttonHeightSmall;
      case ButtonSize.medium:
        return AppDesignTokens.buttonHeightDefault;
      case ButtonSize.large:
        return AppDesignTokens.buttonHeightLarge;
    }
  }
}

// FloatingActionButton 스타일 통일
class CommonFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final bool mini;

  const CommonFAB({
    super.key,
    this.onPressed,
    required this.child,
    this.tooltip,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppDesignTokens.primary,
      foregroundColor: Colors.white,
      elevation: AppDesignTokens.elevationMedium,
      tooltip: tooltip,
      mini: mini,
      child: child,
    );
  }
}

// 칩 스타일 통일
class CommonChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? avatar;
  final VoidCallback? onDeleted;

  const CommonChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.avatar,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap?.call(),
        backgroundColor: AppDesignTokens.surfaceContainer,
        selectedColor: AppDesignTokens.primary.withOpacity(0.2),
        checkmarkColor: AppDesignTokens.primary,
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: isSelected 
              ? AppDesignTokens.primary 
              : AppDesignTokens.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.medium,
          side: BorderSide(
            color: isSelected 
                ? AppDesignTokens.primary 
                : AppDesignTokens.outline,
          ),
        ),
      );
    }

    return Chip(
      label: Text(label),
      avatar: avatar,
      onDeleted: onDeleted,
      backgroundColor: AppDesignTokens.surfaceContainer,
      labelStyle: AppTextStyles.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.medium,
      ),
    );
  }
}