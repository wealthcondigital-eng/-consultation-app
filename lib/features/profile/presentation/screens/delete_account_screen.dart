import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../domain/usecases/delete_patient_account.dart';

/// Ends the account, permanently.
///
/// Two things stand between a tap and an erasure: the page says **what goes**
/// (and links to the notice for what stays), and the dialog behind the button
/// is the last chance to stop.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Delete your account?',
      message:
          'Your profile, photo and reports are erased immediately. This '
          'cannot be undone.',
      confirmLabel: 'Delete permanently',
      cancelLabel: 'Keep my account',
      icon: Icons.delete_forever_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await sl<DeletePatientAccount>()();

      // The token is for an account that no longer exists, so it is cleared
      // whatever the sign-out call answers — the server will refuse it for the
      // same reason it no longer has a user.
      await sl<SignOut>()().catchError((Object _) {});

      if (!mounted) return;

      // No waiting period any more: the same number can sign up again
      // straight away, through the usual code, profile and consent steps.
      AppSnackBar.success(
        context,
        tr(
          'Account deleted. You can sign up again with the same number '
          'whenever you like.',
        ),
      );

      // Everything behind this belonged to the account that is gone, so the
      // whole stack goes rather than being left for a back gesture to reach.
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppSnackBar.error(context, failure.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppSnackBar.error(context, const Failure.unexpected().message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(
              title: 'Delete Account',
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  sizing.screenPaddingH,
                  sizing.spacingMd,
                  sizing.screenPaddingH,
                  sizing.spacingLg,
                ),
                children: [const _Notice()],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                sizing.screenPaddingH,
                sizing.spacingXs,
                sizing.screenPaddingH,
                sizing.spacingMd,
              ),
              // Red, and dead only while a deletion is in flight. Built here
              // rather than as an `AppButton`: the app has no destructive
              // variant, and a delete button wearing the brand's teal is a
              // delete button that looks like every other action on the screen.
              child: FilledButton(
                onPressed: _isDeleting ? null : _delete,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(sizing.buttonHeight),
                  backgroundColor: AppColors.danger,
                  disabledBackgroundColor: AppColors.danger.withValues(
                    alpha: 0.35,
                  ),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(sizing.radiusMd),
                  ),
                ),
                child: _isDeleting
                    ? SizedBox.square(
                        dimension: sizing.iconSm,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        tr('Delete my account'),
                        style: sizing.text.buttonLabel.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one line that has to be on this screen, and a way to the rest.
///
/// What is kept, what is erased, and why are
/// all in the Data Protection Notice this links to, rather than stacked here
/// in front of someone who has already decided.
class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: sizing.iconSm,
                color: AppColors.danger,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('This cannot be undone'),
                  style: sizing.text.cardTitle,
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'Your profile, photo, reports and medical history will be '
              'permanently erased.',
            ),
            style: sizing.text.bodySmall,
          ),
          SizedBox(height: sizing.spacingSm),
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.dataProtection),
            child: Text(
              tr('What happens to your data'),
              style: sizing.text.bodySmall.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
