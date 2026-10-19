import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../domain/entities/doctor_settings.dart';
import '../controllers/bank_account_controller.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Bank & Payouts: where the doctor's consultation fees are sent.
///
/// Two states, and the distinction is deliberate. What is on file is shown
/// **masked** — a screenshot of a settings screen should not carry a whole
/// account number, and the doctor already knows their own. Changing it means
/// typing the whole destination again, which is also the right amount of
/// friction for an operation that decides where money goes.
class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  late final BankAccountController _controller = sl<BankAccountController>();

  final TextEditingController _bankName = TextEditingController();
  final TextEditingController _holder = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _ifsc = TextEditingController();
  final TextEditingController _upi = TextEditingController();

  /// Set when the form opens, so the two fields that come back in full are
  /// seeded once rather than on every rebuild.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    for (final field in [_bankName, _holder, _number, _ifsc, _upi]) {
      field.dispose();
    }
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    if (_controller.isEditing && !_seeded) {
      _seeded = true;
      _bankName.text = _controller.account.bankName;
      _holder.text = _controller.account.accountHolderName;
      _upi.text = _controller.account.upiId;
    }
    if (!_controller.isEditing && _seeded) {
      // Cleared with the form. Nothing on this screen should keep holding an
      // account number once it has been sent.
      _seeded = false;
      for (final field in [_bankName, _holder, _number, _ifsc, _upi]) {
        field.clear();
      }
    }

    final message = _controller.errorMessage;
    if (message == null) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!saved || !mounted) return;

    AppSnackBar.success(context, 'Payout details saved.');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTopBar(
                title: 'Bank & Payouts',
                variant: AppTopBarVariant.outlined,
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final sizing = context.sizing;

    if (_controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final readError = _controller.hasLoaded ? null : _controller.errorMessage;
    if (readError != null) {
      return AppErrorView(message: readError, onRetry: _controller.load);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXxl,
      ),
      children: [
        if (_controller.summary.isSet && !_controller.isEditing) ...[
          _StoredAccount(
            summary: _controller.summary,
            onReplace: _controller.beginEditing,
          ),
          SizedBox(height: sizing.spacingLg),
          const _PayoutNote(),
        ] else ...[
          _Form(
            controller: _controller,
            bankName: _bankName,
            holder: _holder,
            number: _number,
            ifsc: _ifsc,
            upi: _upi,
          ),
          SizedBox(height: sizing.spacingLg),
          AppButton.primary(
            label: _controller.summary.isSet
                ? 'Replace account'
                : 'Save account',
            onPressed: _controller.canSave ? _save : null,
            isLoading: _controller.isSaving,
          ),
          if (_controller.summary.isSet) ...[
            SizedBox(height: sizing.spacingXs),
            AppButton.tertiary(
              label: 'Cancel',
              onPressed: _controller.isSaving
                  ? null
                  : _controller.cancelEditing,
            ),
          ],
          SizedBox(height: sizing.spacingLg),
          const _PayoutNote(),
        ],
      ],
    );
  }
}

/// What is on file, masked.
class _StoredAccount extends StatelessWidget {
  const _StoredAccount({required this.summary, required this.onReplace});

  final BankAccountSummary summary;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Bank', summary.bankName ?? '—'),
      ('Account holder', summary.accountHolderName ?? '—'),
      ('Account number', summary.accountNumberMasked ?? '—'),
      ('IFSC', summary.routingCode ?? '—'),
      if (summary.upiId case final upi?) ('UPI ID', upi),
    ];

    return ProfileSection(
      title: 'Payout account',
      actionLabel: 'Replace',
      onAction: onReplace,
      child: ProfileCard(
        children: [
          for (final (index, row) in rows.indexed)
            ProfileDetailRow(
              label: tr(row.$1),
              value: row.$2,
              showDivider: index < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.controller,
    required this.bankName,
    required this.holder,
    required this.number,
    required this.ifsc,
    required this.upi,
  });

  final BankAccountController controller;
  final TextEditingController bankName;
  final TextEditingController holder;
  final TextEditingController number;
  final TextEditingController ifsc;
  final TextEditingController upi;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final account = controller.account;
    final showErrors = controller.showErrors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Bank name',
          hint: 'HDFC Bank',
          controller: bankName,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? account.bankNameError : null,
          onChanged: controller.setBankName,
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'Account holder name',
          hint: 'As printed on your passbook',
          controller: holder,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? account.accountHolderNameError : null,
          onChanged: controller.setAccountHolderName,
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'Account number',
          hint: '9 to 18 digits',
          controller: number,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: showErrors ? account.accountNumberError : null,
          onChanged: controller.setAccountNumber,
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'IFSC code',
          hint: 'HDFC0000123',
          controller: ifsc,
          textCapitalization: TextCapitalization.characters,
          errorText: showErrors ? account.routingCodeError : null,
          onChanged: controller.setRoutingCode,
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'UPI ID',
          hint: 'name@bank',
          controller: upi,
          helperText: tr('Optional. Used for faster payouts where available.'),
          errorText: showErrors ? account.upiIdError : null,
          onChanged: controller.setUpiId,
        ),
      ],
    );
  }
}

/// Who can see this, and who cannot.
///
/// Worth saying on the screen where somebody types their account number: the
/// review console deliberately has no route that reads payout details, and a
/// doctor has no way to know that unless they are told.
class _PayoutNote extends StatelessWidget {
  const _PayoutNote();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: sizing.iconSm,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('Who sees this'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'Your payout details are used for payments only. Reviewers who '
              'approve registrations cannot read them — the review console has '
              'no route that reaches this record. The account number is shown '
              'back to you masked; to change it, enter the whole number again.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}
