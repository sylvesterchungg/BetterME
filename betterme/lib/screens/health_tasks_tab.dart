import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import 'notifications_screen.dart';

class _TaskCategoryUi {
  final String name;
  final String iconKey;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const _TaskCategoryUi({
    required this.name,
    required this.iconKey,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

IconData _taskIconForKey(String key) {
  switch (key) {
    case 'self_improvement':
      return Icons.self_improvement;
    case 'restaurant':
      return Icons.restaurant;
    case 'medication':
      return Icons.medication;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'water_drop':
      return Icons.water_drop;
    case 'book':
      return Icons.menu_book;
    case 'bedtime':
      return Icons.bedtime;
    case 'favorite':
      return Icons.favorite;
    case 'work':
      return Icons.work;
    case 'school':
      return Icons.school;
    case 'schedule':
      return Icons.schedule;
    case 'list':
    default:
      return Icons.list_alt;
  }
}

const List<_TaskCategoryUi> _builtInTaskCategories = [
  _TaskCategoryUi(
    name: 'Mindfulness',
    iconKey: 'self_improvement',
    icon: Icons.self_improvement,
    backgroundColor: AppTheme.secondaryFixed,
    iconColor: AppTheme.secondary,
  ),
  _TaskCategoryUi(
    name: 'Nutrition',
    iconKey: 'restaurant',
    icon: Icons.restaurant,
    backgroundColor: AppTheme.primaryFixed,
    iconColor: AppTheme.primary,
  ),
  _TaskCategoryUi(
    name: 'Medicines',
    iconKey: 'medication',
    icon: Icons.medication,
    backgroundColor: AppTheme.secondaryFixed,
    iconColor: AppTheme.secondary,
  ),
  _TaskCategoryUi(
    name: 'Exercise',
    iconKey: 'fitness_center',
    icon: Icons.fitness_center,
    backgroundColor: AppTheme.tertiaryFixed,
    iconColor: AppTheme.tertiary,
  ),
  _TaskCategoryUi(
    name: 'General',
    iconKey: 'list',
    icon: Icons.list_alt,
    backgroundColor: AppTheme.primaryFixed,
    iconColor: AppTheme.primary,
  ),
];

class HealthTasksTab extends StatefulWidget {
  const HealthTasksTab({super.key});

  @override
  State<HealthTasksTab> createState() => _HealthTasksTabState();
}

class _HealthTasksTabState extends State<HealthTasksTab> {
  final TextEditingController _waterController = TextEditingController();

  @override
  void dispose() {
    _waterController.dispose();
    super.dispose();
  }

  void _showAddTaskBottomSheet(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (context) {
        return AddTaskBottomSheet(provider: provider);
      },
    );
  }

  void _showUndoSnackbar(
    BuildContext context,
    AppProvider provider,
    int amount,
  ) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${amount}ml of water'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.addWaterIntake(-amount);
          },
        ),
      ),
    );
  }

  void _showEditGoalDialog(
    BuildContext context,
    AppProvider provider,
    int currentGoal,
  ) {
    final goalController = TextEditingController(text: currentGoal.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Daily Goal'),
          content: TextField(
            controller: goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Water Goal (ml)',
              suffixText: 'ml',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(goalController.text.trim());
                if (val != null && val > 0) {
                  provider.updateWaterGoal(val);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final customCategorySections = provider.taskCategories.map((category) {
          return _TaskCategoryUi(
            name: category.name,
            iconKey: category.iconKey,
            icon: _taskIconForKey(category.iconKey),
            backgroundColor: AppTheme.surfaceContainerLow,
            iconColor: AppTheme.primary,
          );
        }).toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: 24),
                  _buildDailyProgress(context, provider),
                  const SizedBox(height: 24),
                  _buildCategorySection(
                    context,
                    provider,
                    _builtInTaskCategories[0],
                  ),
                  const SizedBox(height: 16),
                  _buildHydrationCategory(context, provider),
                  const SizedBox(height: 16),
                  _buildPhysicalActivityCategory(context, provider),
                  ...[
                    ..._builtInTaskCategories.skip(1),
                    ...customCategorySections,
                  ].expand((category) sync* {
                    yield const SizedBox(height: 16);
                    yield _buildCategorySection(context, provider, category);
                  }),
                  const SizedBox(height: 24),
                  _buildAtmosphericBanner(context),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddTaskBottomSheet(context, provider),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    final user = provider.currentUser;
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outlineVariant, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                    ? Image.network(
                        user.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, color: AppTheme.outline),
                      )
                    : const Icon(Icons.person, color: AppTheme.outline),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyProgress(BuildContext context, AppProvider provider) {
    final total = provider.tasks.length;
    final completed = provider.tasks.where((t) => t.isCompleted).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Goals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You've completed $completed of $total tasks today",
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.surfaceContainer,
            color: AppTheme.primary,
            minHeight: 12,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    AppProvider provider,
    _TaskCategoryUi category,
  ) {
    final categoryTasks = provider.tasks
        .where((t) => t.category == category.name)
        .toList();
    if (categoryTasks.isEmpty)
      return const SizedBox.shrink(); // Don't show if empty

    final completed = categoryTasks.where((t) => t.isCompleted).length;
    final total = categoryTasks.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(category.icon, color: category.iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categoryTasks.map((t) => _buildTaskItem(context, provider, t)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: category.iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.surfaceContainer,
            color: category.iconColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, AppProvider provider, Task task) {
    return GestureDetector(
      onTap: () => provider.toggleTask(task.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isCompleted ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: task.isCompleted
                      ? AppTheme.primary
                      : AppTheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? AppTheme.outline
                          : AppTheme.onSurface,
                    ),
                  ),
                  if (task.dueDate != null || task.reminderTime != null)
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        if (task.dueDate != null)
                          Text(
                            'Due: ${DateFormat('MMM d, yyyy').format(task.dueDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.outline,
                            ),
                          ),
                        if (task.reminderTime != null)
                          Text(
                            'Reminder: ${task.reminderTime}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.outline,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => provider.deleteTask(task.id),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHydrationCategory(BuildContext context, AppProvider provider) {
    final waterIntakeMl = provider.currentUser?.waterIntake ?? 0;
    final waterGoal = provider.currentUser?.waterGoal ?? 2500;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Hydration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppTheme.primary,
                ),
                onPressed: () =>
                    _showEditGoalDialog(context, provider, waterGoal),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: waterGoal > 0 ? waterIntakeMl / waterGoal : 0.0,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.surfaceContainer,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${(waterIntakeMl / 1000).toStringAsFixed(1)}L',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of ${(waterGoal / 1000).toStringAsFixed(1)}L',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.addWaterIntake(250);
                    _showUndoSnackbar(context, provider, 250);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('250ml'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6264f2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.addWaterIntake(1000);
                    _showUndoSnackbar(context, provider, 1000);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('1L'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6264f2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _waterController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Custom amount (ml)',
                    filled: true,
                    fillColor: AppTheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (_waterController.text.isNotEmpty) {
                    final val = int.tryParse(_waterController.text);
                    if (val != null && val > 0) {
                      provider.addWaterIntake(val);
                      _showUndoSnackbar(context, provider, val);
                      _waterController.clear();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6264f2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalActivityCategory(
    BuildContext context,
    AppProvider provider,
  ) {
    final steps = provider.currentSteps;
    final stepGoal = 10000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_run,
                        color: AppTheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Physical Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryFixed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Goal: ${stepGoal ~/ 1000}k steps',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onTertiaryFixed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat('#,###').format(steps),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'steps today',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dummy graph
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildGraphBar(40, false),
                  _buildGraphBar(60, false),
                  _buildGraphBar(80, false),
                  _buildGraphBar(50, false),
                  _buildGraphBar(30, false),
                  _buildGraphBar(70, false),
                  _buildGraphBar(64, true), // Today
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'M',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'T',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'W',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'T',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'F',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'S',
                    style: TextStyle(fontSize: 10, color: AppTheme.outline),
                  ),
                  Text(
                    'S',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCategorySection(
          context,
          provider,
          const _TaskCategoryUi(
            name: 'Physical Activity',
            iconKey: 'fitness_center',
            icon: Icons.directions_run,
            backgroundColor: AppTheme.tertiaryFixed,
            iconColor: AppTheme.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildGraphBar(double height, bool isToday) {
    return Container(
      width: 32,
      height: height,
      decoration: BoxDecoration(
        color: isToday ? AppTheme.primaryContainer : AppTheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  Widget _buildAtmosphericBanner(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.8),
            AppTheme.primaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Small steps lead to great health shifts.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Replaced ElevatedButton with a pill-shaped Container
          // as per user request "the white is not a button"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Keep it up',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddTaskBottomSheet extends StatefulWidget {
  final AppProvider provider;

  const AddTaskBottomSheet({super.key, required this.provider});

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'Mindfulness';
  String _selectedCategoryIconKey = 'self_improvement';
  DateTime _selectedDate = DateTime.now();
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _repeatInterval = 'None';

  static const List<String> _repeatOptions = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Custom',
  ];
  static const List<String> _newCategoryIconKeys = [
    'self_improvement',
    'restaurant',
    'medication',
    'fitness_center',
    'water_drop',
    'book',
    'bedtime',
    'favorite',
    'work',
    'school',
    'schedule',
    'list',
  ];

  List<_TaskCategoryUi> get _categoryOptions {
    return [
      ..._builtInTaskCategories.take(4),
      ...widget.provider.taskCategories.map((category) {
        return _TaskCategoryUi(
          name: category.name,
          iconKey: category.iconKey,
          icon: _taskIconForKey(category.iconKey),
          backgroundColor: AppTheme.surfaceContainerLow,
          iconColor: AppTheme.primary,
        );
      }),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    String? reminderStr = _reminderEnabled
        ? '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}'
        : null;

    await widget.provider.addTask(
      _titleController.text.trim(),
      category: _selectedCategory,
      categoryIconKey: _selectedCategoryIconKey,
      dueDate: _selectedDate,
      reminderTime: reminderStr,
      repeatInterval: _repeatInterval,
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _showNewCategoryDialog() async {
    final controller = TextEditingController();
    String selectedIconKey = 'list';

    final created = await showDialog<TaskCategory>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Category name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Icon',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _newCategoryIconKeys.map((key) {
                      final isSelected = selectedIconKey == key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setDialogState(() => selectedIconKey = key),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.outlineVariant,
                            ),
                          ),
                          child: Icon(
                            _taskIconForKey(key),
                            color: isSelected
                                ? Colors.white
                                : AppTheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final category = await widget.provider.addTaskCategory(
                      controller.text,
                      selectedIconKey,
                    );
                    if (category != null && dialogContext.mounted) {
                      Navigator.pop(dialogContext, category);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (!mounted || created == null) return;

    setState(() {
      _selectedCategory = created.name;
      _selectedCategoryIconKey = created.iconKey;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (time != null) setState(() => _reminderTime = time);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: keyboardInset + 20,
      ),
      child: Column(
        children: [
          _buildSheetHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleInput(),
                  const SizedBox(height: 24),
                  _buildCategoryPicker(),
                  const SizedBox(height: 24),
                  _buildDueDateCard(),
                  const SizedBox(height: 16),
                  _buildReminderCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'Repeat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildRepeatGrid(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 5,
                shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader() {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryContainer,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.close,
                  color: AppTheme.onSurface,
                  size: 22,
                ),
              ),
            ),
          ),
          const Text(
            'Add New Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: TextField(
        controller: _titleController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Description of task',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          filled: true,
          contentPadding: EdgeInsets.zero,
          hintStyle: TextStyle(
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._categoryOptions.map(_buildCategoryChip),
            _buildNewCategoryChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(_TaskCategoryUi category) {
    final isSelected = _selectedCategory == category.name;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        setState(() {
          _selectedCategory = category.name;
          _selectedCategoryIconKey = category.iconKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryFixed : AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon, size: 16, color: AppTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCategoryChip() {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: _showNewCategoryDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_box_outlined, size: 20, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'New\nCategory',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickDueDate,
      child: _buildSettingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DUE DATE',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MM/dd/yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month, size: 18, color: Colors.black),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'REMINDER',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: _reminderEnabled,
                  onChanged: (val) => setState(() => _reminderEnabled = val),
                  activeThumbColor: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _reminderEnabled ? _pickReminderTime : null,
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 22,
                  color: _reminderEnabled
                      ? AppTheme.primary
                      : AppTheme.outlineVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  _reminderTime.format(context),
                  style: TextStyle(
                    fontSize: 15,
                    color: _reminderEnabled
                        ? AppTheme.onSurface
                        : AppTheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }

  Widget _buildRepeatGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _repeatOptions.map(_buildRepeatChip).toList(),
    );
  }

  Widget _buildRepeatChip(String option) {
    final isSelected = _repeatInterval == option;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => setState(() => _repeatInterval = option),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppTheme.primaryContainer, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option == 'Custom') ...[
              Icon(
                Icons.settings_outlined,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              option,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
