import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_field_shell.dart';
import '../../domain/entities/code_name.dart';

/// The alias input.
///
/// It carries more weight than an ordinary field — it is the one thing keeping
/// the patient anonymous — so the border picks up the brand colour while it has
/// focus.
class CodeNameField extends StatefulWidget {
  const CodeNameField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  State<CodeNameField> createState() => _CodeNameFieldState();
}

class _CodeNameFieldState extends State<CodeNameField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AppFieldShell(
      label: 'Enter Your Code Name',
      errorText: widget.errorText,
      helperText: tr(
        'This name will be visible to the doctor instead of your real identity',
      ),
      borderColor: _focusNode.hasFocus ? AppColors.primaryDeep : null,
      leading: Icon(
        Icons.person_outline_rounded,
        size: sizing.iconXs,
        color: _focusNode.hasFocus
            ? AppColors.primaryDeep
            : AppColors.textSecondary,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        maxLength: CodeName.maxLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        style: sizing.text.fieldValue,
        cursorColor: AppColors.primaryDeep,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Patient Hawk',
          hintStyle: sizing.text.fieldPlaceholder,
          counterText: '',
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
