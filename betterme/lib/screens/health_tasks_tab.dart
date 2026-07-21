import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/app_page_header.dart';

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


const List<String> _kCategoryIconKeys = [
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

  // Task IDs that have been toggled to complete but are still animating out
  // of the active list. Removed from this set after the animation completes,
  // at which point they naturally appear in the Completed section.
  final Set<String> _animatingOut = {};

  void _completeTask(AppProvider provider, Task task) {
    if (task.isCompleted) {
      // Un-completing: instant, no animation needed
      provider.toggleTask(task.id);
      return;
    }
    if (_animatingOut.contains(task.id)) return; // already mid-animation
    setState(() => _animatingOut.add(task.id));
    provider.toggleTask(task.id);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _animatingOut.remove(task.id));
    });
  }

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
      builder: (context) => AddTaskBottomSheet(provider: provider),
    );
  }

  void _showEditTaskBottomSheet(BuildContext context, AppProvider provider, Task task) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (context) => AddTaskBottomSheet(provider: provider, initialTask: task),
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
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
            icon: TaskCategory.iconFromKey(category.iconKey),
            backgroundColor: AppTheme.surfaceContainerLow,
            iconColor: AppTheme.primary,
          );
        }).toList();

        final allCategories = [
          ..._builtInTaskCategories,
          ...customCategorySections,
        ];

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(title: 'Health Tasks', user: provider.currentUser),
                  const SizedBox(height: 24),
                  _buildDailyProgress(context, provider),
                  const SizedBox(height: 16),
                  _buildAllTasksSection(context, provider, allCategories),
                  const SizedBox(height: 16),
                  _buildHydrationCategory(context, provider),
                  const SizedBox(height: 24),
                  _buildAtmosphericBanner(context),
                  const SizedBox(height: 80),
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

  Widget _buildDailyProgress(BuildContext context, AppProvider provider) {
    final total = provider.tasks.length;
    final completed = provider.tasks.where((t) => t.isCompleted).length;
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
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

  Widget _buildAllTasksSection(
    BuildContext context,
    AppProvider provider,
    List<_TaskCategoryUi> allCategories,
  ) {
    final tasks = provider.tasks;
    final categoryMap = {for (final c in allCategories) c.name: c};

    // Active = not completed, OR completed but still mid-animation (fade out)
    final activeTasks = tasks
        .where((t) => !t.isCompleted || _animatingOut.contains(t.id))
        .toList();
    // Completed = done AND animation has settled
    final completedTasks = tasks
        .where((t) => t.isCompleted && !_animatingOut.contains(t.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: activeTasks.isEmpty && completedTasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.task_alt, size: 40, color: AppTheme.outlineVariant),
                        SizedBox(height: 8),
                        Text(
                          'No tasks yet. Tap + to add one.',
                          style: TextStyle(fontSize: 14, color: AppTheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Tasks',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (activeTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.celebration, size: 16, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text('All tasks done!',
                                style: TextStyle(fontSize: 14, color: AppTheme.outline)),
                          ],
                        ),
                      ),
                    ...activeTasks.map((t) {
                      final isAnimating = _animatingOut.contains(t.id);
                      return AnimatedOpacity(
                        opacity: isAnimating ? 0.35 : 1.0,
                        duration: const Duration(milliseconds: 1400),
                        child: _buildTaskItem(context, provider, t, categoryMap[t.category]),
                      );
                    }),
                  ],
                ),
        ),
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCompletedSection(context, provider, completedTasks, categoryMap),
        ],
      ],
    );
  }

  Widget _buildCompletedSection(
    BuildContext context,
    AppProvider provider,
    List<Task> tasks,
    Map<String, _TaskCategoryUi> categoryMap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Completed (${tasks.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: tasks
                    .map((t) => _buildTaskItem(context, provider, t, categoryMap[t.category]))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    AppProvider provider,
    Task task,
    _TaskCategoryUi? catUi,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isOverdue = !task.isCompleted &&
        task.dueDate != null &&
        task.dueDate!.isBefore(todayStart);

    return GestureDetector(
      onTap: () => _completeTask(provider, task),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: task.isCompleted
              ? AppTheme.surfaceContainerLow
              : isOverdue
                  ? const Color(0xFFFFF0EE)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOverdue ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.borderDefault,
          ),
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
                      : isOverdue
                          ? AppTheme.error
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
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? AppTheme.outline : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (catUi != null) _buildCategoryBadge(catUi),
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Overdue · ${DateFormat('MMM d').format(task.dueDate!)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (task.dueDate != null)
                        Text(
                          'Due: ${DateFormat('MMM d').format(task.dueDate!)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.outline),
                        ),
                      if (task.reminderTime != null)
                        Text(
                          'Reminder: ${task.reminderTime}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.outline),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showEditTaskBottomSheet(context, provider, task),
                  child: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => provider.deleteTask(task.id),
                  child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(_TaskCategoryUi catUi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: catUi.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(catUi.icon, size: 10, color: catUi.iconColor),
          const SizedBox(width: 3),
          Text(
            catUi.name,
            style: TextStyle(fontSize: 11, color: catUi.iconColor, fontWeight: FontWeight.w600),
          ),
        ],
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
        border: Border.all(color: AppTheme.borderDefault),
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
  final Task? initialTask;

  const AddTaskBottomSheet({super.key, required this.provider, this.initialTask});

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

  List<_TaskCategoryUi> get _categoryOptions {
    return [
      ..._builtInTaskCategories.take(4),
      ...widget.provider.taskCategories.map((category) {
        return _TaskCategoryUi(
          name: category.name,
          iconKey: category.iconKey,
          icon: TaskCategory.iconFromKey(category.iconKey),
          backgroundColor: AppTheme.surfaceContainerLow,
          iconColor: AppTheme.primary,
        );
      }),
    ];
  }

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _titleController.text = task.title;
      _selectedCategory = task.category;
      _selectedCategoryIconKey = task.categoryIconKey ?? 'list';
      _selectedDate = task.dueDate ?? DateTime.now();
      _reminderEnabled = task.reminderTime != null;
      if (task.reminderTime != null) {
        final parts = task.reminderTime!.split(':');
        if (parts.length == 2) {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _repeatInterval = task.repeatInterval;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final reminderStr = _reminderEnabled
        ? '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}'
        : null;

    if (widget.initialTask != null) {
      final updated = Task(
        id: widget.initialTask!.id,
        userId: widget.initialTask!.userId,
        title: _titleController.text.trim(),
        isCompleted: widget.initialTask!.isCompleted,
        category: _selectedCategory,
        categoryIconKey: _selectedCategoryIconKey,
        dueDate: _selectedDate,
        reminderTime: reminderStr,
        repeatInterval: _repeatInterval,
      );
      await widget.provider.updateTask(updated);
    } else {
      await widget.provider.addTask(
        _titleController.text.trim(),
        category: _selectedCategory,
        categoryIconKey: _selectedCategoryIconKey,
        dueDate: _selectedDate,
        reminderTime: reminderStr,
        repeatInterval: _repeatInterval,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _showNewCategoryDialog() async {
    final created = await showDialog<TaskCategory>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _NewCategoryDialog(provider: widget.provider),
    );

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
              child: Text(
                widget.initialTask != null ? 'Update Task' : 'Create Task',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          Text(
            widget.initialTask != null ? 'Edit Task' : 'Add New Task',
            style: const TextStyle(
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
              'DATE',
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

// Proper StatefulWidget for the new-category dialog.
// Using StatefulBuilder caused '_dependents.isEmpty' assertion failures because
// the Firestore stream fires notifyListeners() while the dialog context was
// still being torn down. A real StatefulWidget has a clean dispose lifecycle.
class _NewCategoryDialog extends StatefulWidget {
  final AppProvider provider;
  const _NewCategoryDialog({required this.provider});

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();
  String _selectedIconKey = 'list';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);

    final category = await widget.provider.addTaskCategory(name, _selectedIconKey);

    if (mounted) {
      Navigator.pop(context, category);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name'),
          ),
          const SizedBox(height: 16),
          const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kCategoryIconKeys.map((key) {
              final isSelected = _selectedIconKey == key;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selectedIconKey = key),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    TaskCategory.iconFromKey(key),
                    color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
