import 'package:flutter/material.dart';

import '../../../../core/widgets/app_bottom_nav_bar.dart';

/// The patient app's top-level destinations.
///
/// Three, and each one has a screen. The rule this bar follows is that it never
/// lists a place it cannot go: Appointments and Chat sat here once before either
/// had a screen, so a third of the bar led to "coming soon", and a bar that lies
/// about where it goes is worse than a short one.
enum PatientTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  appointments(
    'Appointments',
    Icons.event_note_outlined,
    Icons.event_note_rounded,
  ),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const PatientTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Bottom navigation across the patient app.
///
/// A thin binding over [AppBottomNavBar] rather than a bar of its own. The two
/// roles used to have separately written bars that had drifted apart — one
/// animated, one a static row with a top border — so crossing from the patient
/// app to the doctor app felt like crossing between two products.
class PatientNavBar extends StatelessWidget {
  const PatientNavBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final PatientTab current;
  final ValueChanged<PatientTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavBar<PatientTab>(
      current: current,
      onSelected: onSelected,
      destinations: {
        for (final tab in PatientTab.values)
          tab: AppNavDestination(
            label: tab.label,
            icon: tab.icon,
            activeIcon: tab.activeIcon,
          ),
      },
    );
  }
}
