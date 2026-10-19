import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/practice_setup.dart';
import '../../../../core/l10n/tr.dart';

/// One priced consultation type: a free-entry amount, and quick picks under it.
///
/// Free entry **and** chips, not one or the other. The screen used to offer
/// four fixed amounts and nothing else, so a doctor who charges ₹450 could not
/// say so. The chips stay because most doctors pick a round number and typing
/// is the slower path for them.
class ConsultationFeeField extends StatefulWidget {
  const ConsultationFeeField({
    super.key,
    required this.kind,
    required this.setup,
    required this.onChanged,
    this.errorText,
    this.trailing,
  });

  final ConsultationFeeKind kind;
  final PracticeSetup setup;

  /// Null clears the fee, which prices only the other consultation type.
  final ValueChanged<int?> onChanged;

  final String? errorText;

  /// An extra control on the header row — "Same as video", on the audio field.
  final Widget? trailing;

  @override
  State<ConsultationFeeField> createState() => _ConsultationFeeFieldState();
}

class _ConsultationFeeFieldState extends State<ConsultationFeeField> {
  final TextEditingController _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.text = widget.kind.from(widget.setup)?.toString() ?? '';
  }

  @override
  void didUpdateWidget(ConsultationFeeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only when the value changed *elsewhere* — a chip tap, or "Same as
    // video". Writing the field on every rebuild would move the caret to the
    // end while somebody was typing in the middle of a number.
    final fee = widget.kind.from(widget.setup);
    final shown = int.tryParse(_amount.text.trim());
    if (fee != shown) _amount.text = fee?.toString() ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _onTyped(String value) {
    final trimmed = value.trim();
    widget.onChanged(trimmed.isEmpty ? null : int.tryParse(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final fee = widget.kind.from(widget.setup);
    final error = widget.errorText;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: error == null ? AppColors.border : AppColors.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                widget.kind == ConsultationFeeKind.video
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                size: sizing.iconSm,
                color: AppColors.primaryVivid,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr(widget.kind.label),
                  style: sizing.text.cardTitle,
                ),
              ),
              ?widget.trailing,
            ],
          ),
          SizedBox(height: sizing.spacingXxs),
          Text(tr(widget.kind.description), style: sizing.text.helperText),
          SizedBox(height: sizing.spacingSm),
          _AmountField(
            controller: _amount,
            currencySymbol: widget.setup.currencySymbol,
            onChanged: _onTyped,
            hasError: error != null,
          ),
          if (error != null) ...[
            SizedBox(height: sizing.spacingXxs),
            Text(tr(error), style: sizing.text.error),
          ],
          SizedBox(height: sizing.spacingSm),
          Wrap(
            spacing: sizing.spacingXs,
            runSpacing: sizing.spacingXs,
            children: [
              for (final option in widget.setup.feeOptions)
                _FeeChip(
                  label: widget.setup.formatFee(option),
                  isSelected: option == fee,
                  onTap: () => widget.onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The number itself, with the currency symbol fixed to the left of it.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.currencySymbol,
    required this.onChanged,
    required this.hasError,
  });

  final TextEditingController controller;
  final String currencySymbol;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      height: sizing.inputHeight,
      padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusInput),
        border: Border.all(
          width: sizing.hairline,
          color: hasError ? AppColors.danger : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            currencySymbol,
            style: sizing.text.amountTotal.copyWith(
              fontSize: sizing.sp(20),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              // Digits only, and capped at five: the platform's ceiling is
              // ₹100,000, so a sixth digit can only be a typo.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: onChanged,
              style: sizing.text.amountTotal.copyWith(fontSize: sizing.sp(20)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: sizing.text.fieldPlaceholder,
              ),
            ),
          ),
          Text(
            tr('per consultation'),
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeChip extends StatelessWidget {
  const _FeeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusSm);

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primaryDeep : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.spacingSm,
              vertical: sizing.spacingXs,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: isSelected
                  ? null
                  : Border.all(width: sizing.hairline, color: AppColors.border),
            ),
            child: Text(
              label,
              style: sizing.text.fieldValue.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
