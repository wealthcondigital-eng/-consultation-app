import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Base theme. Only screen-size-independent concerns live here — anything with
/// a dimension belongs in `AppSizing` so it can scale per device.
class AppTheme {
  const AppTheme._();

  /// The design specifies Inter. No font assets are bundled yet, so this stays
  /// null and Flutter falls back to the platform font. Drop the Inter files
  /// into `assets/fonts/`, declare them in `pubspec.yaml`, then set this and
  /// `AppTextStyles.fontFamily` to `'Inter'`.
  static const String? fontFamily = null;

  /// The theme for whichever palette `ThemeController` has made active.
  static ThemeData get current =>
      _build(AppColors.isDark ? Brightness.dark : Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
          outline: AppColors.border,
        );

    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontFamily,
      // Named rather than left to the platform: the greeting's wave and any
      // emoji a patient types into chat find a colour glyph on every Android
      // build — and in the store-screenshot renderer, which has no automatic
      // emoji fallback at all.
      fontFamilyFallback: const ['Noto Color Emoji'],
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.surface,
      dividerColor: AppColors.border,
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      // An off switch has to look like something to tap. Material draws it
      // with the scheme's `outline` — here the hairline card border — so on a
      // white card it was a faint grey smudge, and doctors could not tell that
      // Online and Available 24/7 were switches at all. Off now has a clear
      // dark outline and a solid thumb; on keeps the brand fill.
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : AppColors.textSecondary,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surface,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionHandleColor: AppColors.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      // Every snackbar in the app goes through `AppSnackBar`, which builds its
      // own floating, rounded, icon-led content. This theme is what the few
      // framework-raised ones (a text field's paste confirmation, say) inherit,
      // so they do not appear as a square grey slab beside them.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.isDark
            ? AppColors.surfaceMuted
            : AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.primarySoft,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
