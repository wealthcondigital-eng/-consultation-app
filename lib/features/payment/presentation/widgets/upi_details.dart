import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/payment_method.dart';

/// Maps a UPI app to a glyph and a tint.
///
/// These are stand-ins: shipping GPay, PhonePe or Paytm branding requires each
/// provider's own artwork under their brand guidelines.
({IconData icon, Color color}) markForUpiApp(UpiApp app) => switch (app) {
  UpiApp.googlePay => (
    icon: Icons.g_mobiledata_rounded,
    color: Color(0xFF34A853),
  ),
  UpiApp.phonePe => (
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF5F259F),
  ),
  UpiApp.paytm => (icon: Icons.payments_rounded, color: Color(0xFF00BAF2)),
};

/// The UPI ID field, its verify action, and the app shortcuts.
class UpiDetails extends StatelessWidget {
  const UpiDetails({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onVerify,
    required this.canVerify,
    required this.isVerifying,
    this.verifiedAccountName,
    this.onAppSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;
  final bool canVerify;
  final bool isVerifying;

  /// Set once verification succeeds.
  final String? verifiedAccountName;

  final ValueChanged<UpiApp>? onAppSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('ENTER UPI ID'), style: sizing.text.inputLabel),
        SizedBox(height: sizing.spacingXxs * 1.5),
        _Field(
          controller: controller,
          onChanged: onChanged,
          onVerify: onVerify,
          canVerify: canVerify,
          isVerifying: isVerifying,
          isVerified: verifiedAccountName != null,
        ),
        if (verifiedAccountName != null) ...[
          SizedBox(height: sizing.spacingXxs * 1.5),
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: sizing.iconXs * 0.9,
                color: AppColors.success,
              ),
              SizedBox(width: sizing.spacingXxs),
              Flexible(
                child: Text(
                  verifiedAccountName!,
                  style: sizing.text.caption.copyWith(color: AppColors.success),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: sizing.spacingSm),
        Text(tr('Or pay using popular apps:'), style: sizing.text.caption),
        SizedBox(height: sizing.spacingXs),
        Wrap(
          spacing: sizing.spacingSm,
          runSpacing: sizing.spacingXs,
          children: [
            for (final app in UpiApp.values)
              _AppChip(app: app, onTap: () => onAppSelected?.call(app)),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.onChanged,
    required this.onVerify,
    required this.canVerify,
    required this.isVerifying,
    required this.isVerified,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onVerify;
  final bool canVerify;
  final bool isVerifying;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      height: sizing.searchFieldHeight,
      padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusSm),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              style: sizing.text.screenSubtitle.copyWith(
                color: AppColors.textPrimary,
              ),
              cursorColor: AppColors.primaryVivid,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'name@bank',
                hintStyle: sizing.text.fieldPlaceholder,
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onVerify(),
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Container(
            width: sizing.borderWidth,
            height: sizing.iconXs,
            color: AppColors.primaryVivid,
          ),
          SizedBox(width: sizing.spacingXs),
          if (isVerifying)
            SizedBox.square(
              dimension: sizing.iconXs,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryVivid),
              ),
            )
          else
            GestureDetector(
              onTap: canVerify ? onVerify : null,
              child: Text(
                isVerified ? tr('Verified') : tr('Verify'),
                style: sizing.text.screenSubtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  // Greyed until the address could plausibly exist.
                  color: canVerify || isVerified
                      ? AppColors.primaryVivid
                      : AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  const _AppChip({required this.app, required this.onTap});

  final UpiApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final mark = markForUpiApp(app);
    final radius = BorderRadius.circular(sizing.radiusSm);

    return Material(
      color: AppColors.canvas,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.spacingXs + 2,
            vertical: sizing.spacingXxs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mark.icon, size: sizing.iconXs * 0.9, color: mark.color),
              SizedBox(width: sizing.spacingXxs * 1.5),
              Text(
                app.label,
                style: sizing.text.caption.copyWith(color: AppColors.textLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
