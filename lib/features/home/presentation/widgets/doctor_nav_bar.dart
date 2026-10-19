import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bottom_nav_bar.dart';

/// The doctor app's top-level destinations.
///
/// Four, and each one has a screen. Patients and Earnings sat here once before
/// either had one, so half the bar led to "coming soon"; they are back because
/// the screens are.
enum DoctorTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  patients('Patients', Icons.groups_outlined, Icons.groups_rounded),
  earnings('Earnings', Icons.payments_outlined, Icons.payments_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const DoctorTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom navigation across the doctor app.
///
/// The same [AppBottomNavBar] the patient app uses. It used to be a static row
/// of four icons under four permanent captions, which at 320pt meant setting
/// "Appointments" a point smaller to stop it ellipsising; the shared bar shows
/// a label only on the selected tab, so the width problem does not arise.
class DoctorNavBar extends StatelessWidget {
  const DoctorNavBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final DoctorTab current;
  final ValueChanged<DoctorTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavBar<DoctorTab>(
      current: current,
      onSelected: onSelected,
      destinations: {
        for (final tab in DoctorTab.values)
          tab: AppNavDestination(
            label: tab.label,
            icon: tab.icon,
            activeIcon: tab.activeIcon,
          ),
      },
    );
  }
}
