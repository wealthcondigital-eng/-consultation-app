import 'package:flutter/material.dart';

import '../format/app_date_format.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';
import '../l10n/tr.dart';

/// A date picker built from three wheels rather than a month grid.
///
/// A calendar is the right shape for "which day next week"; it is the wrong
/// shape for a birth date, where the year is the hard part and a grid makes you
/// page through hundreds of months to reach it. Spinning straight to a year is
/// two gestures instead of two hundred.
///
/// Returns the chosen date, or null when dismissed.
class AppDateWheelSheet extends StatefulWidget {
  const AppDateWheelSheet({
    super.key,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    this.confirmLabel = 'Done',
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String confirmLabel;

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
    required String title,
    String confirmLabel = 'Done',
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusLg),
        ),
      ),
      builder: (_) => AppDateWheelSheet(
        initial: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<AppDateWheelSheet> createState() => _AppDateWheelSheetState();
}

class _AppDateWheelSheetState extends State<AppDateWheelSheet> {
  late int _day;
  late int _month;
  late int _year;

  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  int get _firstYear => widget.firstDate.year;
  int get _lastYear => widget.lastDate.year;

  /// Handles February and the 30-day months, leap years included.
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  @override
  void initState() {
    super.initState();

    final start = _clamp(widget.initial);
    _day = start.day;
    _month = start.month;
    _year = start.year;

    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - _firstYear,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  /// Keeps the day wheel honest when the month or year changes underneath it —
  /// 31 January becoming February must land on the 28th, not vanish.
  void _syncDayToMonth() {
    final maxDay = _daysInMonth;
    if (_day <= maxDay) return;

    _day = maxDay;

    // Deferred a frame: the day wheel's item count shrinks in this same
    // rebuild, and driving the controller before the list has caught up can
    // scroll it past its own end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayController.hasClients) return;

      _dayController.animateToItem(
        maxDay - 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _isSelectionAllowed {
    final selected = DateTime(_year, _month, _day);
    return !selected.isBefore(widget.firstDate) &&
        !selected.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final itemExtent = sizing.h(44);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingXs,
          sizing.screenPaddingH,
          sizing.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(widget.title), style: sizing.text.navTitle),
            SizedBox(height: sizing.spacingXs),
            Text(
              AppDateFormat.monthDayYear(DateTime(_year, _month, _day)),
              style: sizing.text.cardTitleLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: sizing.spacingMd),
            SizedBox(
              height: itemExtent * 5,
              child: Stack(
                children: [
                  // The band marking the selected row, behind the wheels so the
                  // numbers stay legible on top of it.
                  Center(
                    child: Container(
                      height: itemExtent,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(sizing.radiusMd),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Wheel(
                          controller: _dayController,
                          itemExtent: itemExtent,
                          count: _daysInMonth,
                          labelAt: (index) => '${index + 1}',
                          onChanged: (index) =>
                              setState(() => _day = index + 1),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Wheel(
                          controller: _monthController,
                          itemExtent: itemExtent,
                          count: 12,
                          labelAt: AppDateFormat.monthLabelAt,
                          onChanged: (index) => setState(() {
                            _month = index + 1;
                            _syncDayToMonth();
                          }),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Wheel(
                          controller: _yearController,
                          itemExtent: itemExtent,
                          count: _lastYear - _firstYear + 1,
                          labelAt: (index) => '${_firstYear + index}',
                          onChanged: (index) => setState(() {
                            _year = _firstYear + index;
                            _syncDayToMonth();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: sizing.spacingLg),
            AppButton.primary(
              label: widget.confirmLabel,
              onPressed: _isSelectionAllowed
                  ? () =>
                        Navigator.of(context).pop(DateTime(_year, _month, _day))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// One column of the picker.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemExtent,
    required this.count,
    required this.labelAt,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final int count;
  final String Function(int index) labelAt;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      // Gentle curvature: enough to read as a wheel, not so much that the rows
      // either side become unreadable.
      diameterRatio: 1.8,
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          return Center(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                // `selectedItem` throws before the wheel has been laid out.
                final selected =
                    controller.hasClients && controller.position.haveDimensions
                    ? controller.selectedItem
                    : controller.initialItem;

                final isSelected = selected == index;
                return Text(
                  labelAt(index),
                  style: isSelected
                      ? sizing.text.fieldValue.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )
                      : sizing.text.fieldValue.copyWith(
                          color: AppColors.textTertiary,
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
