import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import '../widgets/stream_error_banner.dart';
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
  // provider notification. Base64 avatars render instantly, so precaching is
  // unnecessary — and keeping the Scaffold stable avoids disturbing SnackBars
  // hosted above it.
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
      // IndexedStack (not a plain widget swap) keeps every tab mounted, so
      // in-progress state — an unsaved Log-tab draft, journal text, scroll
      // position — survives switching tabs and back instead of being
      // silently discarded when the outgoing tab's State was disposed.
      // _AiConsentGate is the one narrowly-scoped exception to "MainScreen
      // doesn't watch AppProvider" above — it renders nothing and only
      // itself rebuilds, so the tab content's stability is unaffected.
      body: Stack(children: [
        IndexedStack(index: _currentIndex, children: _tabs),
        const _AiConsentGate(),
        const _StreamErrorBanner(),
      ]),
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

/// Tells the user when a background listener has failed, so stale data is
/// never presented as current. Like [_AiConsentGate], this watches
/// AppProvider on its own so MainScreen's Scaffold stays out of the rebuild
/// path; it renders nothing at all while every stream is healthy.
class _StreamErrorBanner extends StatelessWidget {
  const _StreamErrorBanner();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.hasStreamError) return const SizedBox.shrink();

    return StreamErrorBanner(
      summary: provider.streamErrorSummary,
      onRetry: provider.retryStreams,
    );
  }
}

/// Invisible gate that asks for AI-processing consent exactly once per
/// account (FR_1004-equivalent) — [User.aiInsightsEnabled] starts `null`
/// ("never asked"), and no AI call ever fires until it's `true` (see
/// AppProvider.ensureMorningNudge / TrendsInsightsScreen's consent gate).
class _AiConsentGate extends StatefulWidget {
  const _AiConsentGate();

  @override
  State<_AiConsentGate> createState() => _AiConsentGateState();
}

class _AiConsentGateState extends State<_AiConsentGate> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser;
    if (!_asked && user != null && user.aiInsightsEnabled == null) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showConsentDialog();
      });
    }
    return const SizedBox.shrink();
  }

  void _showConsentDialog() {
    final provider = context.read<AppProvider>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI Insights'),
        content: const Text(
          "BetterME can use Google's Gemini AI to turn your last 7 days of "
          "mood, sleep, symptoms and task data into a plain-language "
          "insight, a morning tip, and coping suggestions on hard days. "
          "That data is sent to Google to generate them.\n\n"
          "You can change this anytime in Profile > AI Insights.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.setAiInsightsEnabled(false);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              provider.setAiInsightsEnabled(true);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Enable AI Insights'),
          ),
        ],
      ),
    );
  }
}
