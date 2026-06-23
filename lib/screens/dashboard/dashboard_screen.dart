import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/appointment.dart';
import '../../services/services.dart';
import 'calendar_tab.dart';
import 'forms_tab.dart';
import 'overview_tab.dart';

/// The artist's home: a rail (or bottom bar on narrow screens) switching between
/// Overview, Calendar and Forms. All three share one live stream of the artist's
/// appointments so counts and the calendar stay in sync.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Overview'),
    (icon: Icons.calendar_month_outlined, selected: Icons.calendar_month, label: 'Calendar'),
    (icon: Icons.description_outlined, selected: Icons.description, label: 'Forms'),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return StreamBuilder<List<Appointment>>(
      stream: db.appointmentsStream(uid),
      builder: (context, snap) {
        final appts = snap.data ?? const <Appointment>[];
        final pages = [
          OverviewTab(appointments: appts, loading: !snap.hasData),
          CalendarTab(appointments: appts),
          const FormsTab(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_destinations[_index].label),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                onPressed: () async {
                  await auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(child: pages[_index]),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: d.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
