import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/bank_account.dart';
import '../controllers/doctor_setup_controller.dart';
import '../../../../core/l10n/tr.dart';

/// Step three: where the doctor's consultation payouts land.
class BankStep extends StatelessWidget {
  const BankStep({
    super.key,
    required this.controller,
    required this.controllers,
  });

  final DoctorSetupController controller;

  /// Owned by the screen, keyed by field, so entries survive a step change.
  final BankFieldControllers controllers;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final account = controller.bankAccount;
    final showErrors = controller.showErrors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'Provide your bank details to enable direct secure payouts for '
            'completed telemedicine consultations.',
          ),
          style: sizing.text.helperText,
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'Bank Name',
          hint: 'e.g. Chase Bank',
          controller: controllers.bankName,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? account.bankNameError : null,
          onChanged: (value) => controller.changeBankAccount(
            (current) => current.copyWith(bankName: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'Account Holder Name',
          hint: 'e.g. Dr. Sarah Jenkins',
          controller: controllers.accountHolderName,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? account.accountHolderNameError : null,
          onChanged: (value) => controller.changeBankAccount(
            (current) => current.copyWith(accountHolderName: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'Account Number',
          hint: 'e.g. 1234567890',
          controller: controllers.accountNumber,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: BankAccount.maxAccountNumberLength,
          errorText: showErrors ? account.accountNumberError : null,
          onChanged: (value) => controller.changeBankAccount(
            (current) => current.copyWith(accountNumber: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'IFSC Code / Routing Code',
          hint: 'e.g. CHAS0123456',
          controller: controllers.routingCode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            // Codes are always upper case, so the field does it rather than
            // making the doctor hold shift.
            TextInputFormatter.withFunction(
              (_, next) => next.copyWith(text: next.text.toUpperCase()),
            ),
          ],
          errorText: showErrors ? account.routingCodeError : null,
          onChanged: (value) => controller.changeBankAccount(
            (current) => current.copyWith(routingCode: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'UPI ID (Optional)',
          hint: 'e.g. sarahjenkins@okaxis',
          controller: controllers.upiId,
          keyboardType: TextInputType.emailAddress,
          helperText: 'A second payout route, if you use UPI.',
          errorText: account.upiIdError,
          onChanged: (value) => controller.changeBankAccount(
            (current) => current.copyWith(upiId: value),
          ),
        ),
      ],
    );
  }
}

/// The text controllers the bank step needs, kept together so the screen owns
/// one object rather than five fields.
class BankFieldControllers {
  BankFieldControllers();

  final TextEditingController bankName = TextEditingController();
  final TextEditingController accountHolderName = TextEditingController();
  final TextEditingController accountNumber = TextEditingController();
  final TextEditingController routingCode = TextEditingController();
  final TextEditingController upiId = TextEditingController();

  void dispose() {
    bankName.dispose();
    accountHolderName.dispose();
    accountNumber.dispose();
    routingCode.dispose();
    upiId.dispose();
  }
}
