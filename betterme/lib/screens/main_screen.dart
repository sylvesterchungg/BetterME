import 'package:flutter/material.dart';
import '../theme.dart';
import 'dashboard_tab.dart';
import 'daily_log_tab.dart';
import 'health_tasks_tab.dart';
import 'friends_tab.dart';
import 'trends_insights_screen.dart';
import 'personal_diary_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // NOTE: MainScreen deliberately does NOT listen to AppProvider. It used to
  // (to precache the avatar), which rebuilt this whole Scaffold on every
  // provider notification — and with the pedometer stream firing constantly on
  // a real device, those rebuilds interfered with SnackBar auto-dismiss timers
  // (e.g. the water "Undo" bar never went away). Base64 avatars render
  // instantly, so precaching is unnecessary.
  final List<Widget> _tabs = [
    const DashboardTab(),
    const TrendsInsightsScreen(),
    const DailyLogTab(),
    const HealthTasksTab(),
    const FriendsTab(),
    const PersonalDiaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderDefault, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.outline,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              label: 'Trends',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 28),
              label: 'Log',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Friends'),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Journal',
            ),
          ],
        ),
      ),
    );
  }
}
