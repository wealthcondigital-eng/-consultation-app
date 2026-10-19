import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/payment_method.dart';

/// Maps a method to its glyph, keeping Flutter types out of the domain enum.
IconData iconForPaymentMethod(PaymentMethod method) => switch (method) {
  PaymentMethod.upi => Icons.smartphone_rounded,
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.netBanking => Icons.account_balance_rounded,
};

/// A selectable payment method. When selected it expands to reveal [details],
/// if the method needs any.
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onSelected,
    this.details,
  });

  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onSelected;

  /// Extra input revealed while this method is selected.
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onSelected,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              width: isSelected ? sizing.borderWidth : sizing.hairline,
              color: isSelected ? AppColors.primarySoft : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    iconForPaymentMethod(method),
                    size: sizing.iconSm,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Text(
                      tr(method.label),
                      style: sizing.text.fieldAffix,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: sizing.spacingXs),
                  _Radio(isSelected: isSelected),
                ],
              ),
              if (isSelected && details != null) ...[
                SizedBox(height: sizing.spacingMd),
                details!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      checked: isSelected,
      child: Container(
        width: sizing.radioSize,
        height: sizing.radioSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            width: isSelected ? sizing.borderWidthEmphasis : sizing.hairline,
            color: isSelected ? AppColors.primaryVivid : AppColors.border,
          ),
        ),
        child: isSelected
            ? Container(
                width: sizing.radioSize / 2,
                height: sizing.radioSize / 2,
                decoration: BoxDecoration(
                  color: AppColors.primaryVivid,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
