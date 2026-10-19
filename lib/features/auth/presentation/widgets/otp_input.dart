import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';

/// A row of single-digit boxes backed by one real text field.
///
/// One field rather than one-per-box is what makes SMS autofill, paste and
/// backspace-across-boxes work; the boxes are pure presentation drawn from the
/// field's value.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.length,
    required this.controller,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.autofocus = true,
  });

  final int length;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Fired once the last digit is entered — used to submit without a tap.
  final ValueChanged<String>? onCompleted;

  final bool enabled;
  final bool hasError;
  final bool autofocus;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // The boxes reflect both the value and the focus, so both drive a rebuild.
    widget.controller.addListener(_onStateChanged);
    _focusNode.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    _focusNode
      ..removeListener(_onStateChanged)
      ..dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    widget.onChanged(value);
    if (value.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final digits = widget.controller.text;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (index) {
            return _OtpBox(
              digit: index < digits.length ? digits[index] : null,
              // The next empty box is highlighted while the field has focus,
              // standing in for a caret the user cannot see.
              isActive: _focusNode.hasFocus && index == digits.length,
              hasError: widget.hasError,
            );
          }),
        ),
        // Transparent field on top: tapping any box focuses it, and the
        // keyboard edits one continuous string.
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            // Hidden rather than removed: the boxes are the visible input.
            showCursor: false,
            cursorWidth: 0,
            enableInteractiveSelection: false,
            style: const TextStyle(color: Colors.transparent, height: 0.01),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            expands: true,
            maxLines: null,
            minLines: null,
            onChanged: _handleChanged,
          ),
        ),
        // Nothing above this point should intercept the pointer, but the row
        // height still has to be the boxes' height.
        IgnorePointer(child: SizedBox(height: sizing.otpBoxHeight)),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  final String? digit;
  final bool isActive;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isFilled = digit != null;
    final isHighlighted = isFilled || isActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: sizing.otpBoxWidth,
      height: sizing.otpBoxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: sizing.borderRadiusMd,
        border: Border.all(
          width: isHighlighted ? sizing.borderWidthEmphasis : sizing.hairline,
          color: switch ((hasError, isHighlighted)) {
            (true, _) => AppColors.danger,
            (false, true) => AppColors.primary,
            (false, false) => AppColors.border,
          },
        ),
      ),
      child: Text(digit ?? '', style: sizing.text.otpDigit),
    );
  }
}
