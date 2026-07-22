import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../utils/image_helpers.dart';
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

  // Tracks the avatar URL already warmed into the image cache so we only
  // precache once per URL change instead of on every rebuild.
  String? _preloadedAvatarUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadAvatar();
  }

  // Preload the user's avatar into Flutter's image cache as soon as it's
  // available, so the Profile/Dashboard/Friends tabs show it instantly
  // instead of fetching over the network when first opened.
  void _preloadAvatar() {
    final url = Provider.of<AppProvider>(context).currentUser?.avatarUrl;
    if (url == null || url.isEmpty || url == _preloadedAvatarUrl) return;
    _preloadedAvatarUrl = url;
    final provider = imageProviderFor(url);
    if (provider != null) precacheImage(provider, context);
  }

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
