import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../tasks/providers/task_provider.dart';
import '../../tasks/screens/task_detail_screen.dart';

const _calendarBackground = Color(0xFF1B2A31);
const _calendarPanel = Color(0xFF1E3038);
const _calendarCell = Color(0xFF1A2B33);
const _calendarLine = Color(0xFF30444D);
const _calendarMuted = Color(0xFF71828A);
const _calendarBlue = Color(0xFF66B8FF);

class HomeCalendarScreen extends ConsumerStatefulWidget {
  const HomeCalendarScreen({super.key});

  @override
  ConsumerState<HomeCalendarScreen> createState() => _HomeCalendarScreenState();
}

class _HomeCalendarScreenState extends ConsumerState<HomeCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  List<TaskItemModel> _tasks = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    final generation = ++_generation;
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(taskRepositoryProvider);
      final from = _dateKey(DateTime(month.year, month.month));
      final to = _dateKey(DateTime(month.year, month.month + 1, 0));
      final all = <TaskItemModel>[];
      var page = 1;
      var lastPage = 1;
      do {
        final result = await repository.fetchTasks(
            status: 'all', from: from, to: to, page: page);
        all.addAll(result.tasks);
        lastPage = result.lastPage;
        page++;
      } while (page <= lastPage && page <= 20);
      if (!mounted || generation != _generation) return;
      setState(() {
        _tasks = all.where((task) => _taskDate(task) != null).toList()
          ..sort((a, b) => _taskDate(a)!.compareTo(_taskDate(b)!));
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = 'Unable to load calendar tasks.';
        _loading = false;
      });
    }
  }

  DateTime? _taskDate(TaskItemModel task) {
    final parsed = DateTime.tryParse(task.dueDate);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selected = DateTime(_month.year, _month.month, 1);
    });
    _loadMonth();
  }

  List<DateTime> get _calendarDays {
    final first = DateTime(_month.year, _month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }

  List<TaskItemModel> get _selectedTasks => _tasks
      .where((task) => DateUtils.isSameDay(_taskDate(task), _selected))
      .toList();

  @override
  Widget build(BuildContext context) {
    final tasksByDay = <DateTime, int>{};
    for (final task in _tasks) {
      final date = _taskDate(task);
      if (date != null) tasksByDay[date] = (tasksByDay[date] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: _calendarBackground,
      appBar: AppBar(
        backgroundColor: _calendarBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Calendar',
            style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              decoration: BoxDecoration(
                color: _calendarPanel,
                border: Border.all(color: _calendarLine),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left, size: 19),
                          color: _calendarMuted,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(DateFormat('MMMM yyyy').format(_month),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right, size: 19),
                          color: _calendarMuted,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      for (final day in const [
                        'MON',
                        'TUE',
                        'WED',
                        'THU',
                        'FRI',
                        'SAT',
                        'SUN'
                      ])
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: Center(
                              child: Text(day,
                                  style: const TextStyle(
                                      color: _calendarMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: .2)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _calendarDays.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.3,
                    ),
                    itemBuilder: (context, index) {
                      final date = _calendarDays[index];
                      final inMonth = date.month == _month.month;
                      final selected = DateUtils.isSameDay(date, _selected);
                      final today = DateUtils.isSameDay(date, DateTime.now());
                      final count = tasksByDay[date] ?? 0;
                      return InkWell(
                        onTap: () => setState(() => _selected = date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF293E49)
                                : _calendarCell,
                            border:
                                Border.all(color: _calendarLine, width: .45),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${date.day}',
                                  style: TextStyle(
                                      color: !inMonth
                                          ? _calendarMuted.withValues(
                                              alpha: .65)
                                          : today || selected
                                              ? Colors.white
                                              : const Color(0xFFD8E1E5),
                                      fontSize: 11,
                                      fontWeight: today || selected
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                              const SizedBox(height: 2),
                              if (count > 0)
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      color: _calendarBlue,
                                      shape: BoxShape.circle),
                                )
                              else
                                const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  color: _calendarBackground,
                  border: Border.all(color: _calendarLine),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAgenda(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgenda() {
    final tasks = _selectedTasks;
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Expanded(
            child: Center(
              child: TextButton.icon(
                onPressed: _loadMonth,
                icon: const Icon(Icons.refresh),
                label: Text(_error!),
              ),
            ),
          )
        else if (_loading && _tasks.isEmpty)
          const Expanded(
              child: Center(
                  child: CircularProgressIndicator(color: _calendarBlue)))
        else if (tasks.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No tasks for ${DateFormat('EEE, MMM d').format(_selected)}',
                style: const TextStyle(color: _calendarMuted, fontSize: 13),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final completed = task.status == 'completed';
                return InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(taskId: task.id))),
                  borderRadius: BorderRadius.circular(7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: _calendarBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Text(DateFormat('MMM').format(_selected),
                                style: const TextStyle(
                                    color: Color(0xFF143045),
                                    fontSize: 9,
                                    height: 1.1)),
                            Text('${_selected.day}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    height: 1.1)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        completed
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: completed ? _calendarBlue : Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : null)),
                              const SizedBox(height: 2),
                              Text(DateFormat('EEE, MMM d').format(_selected),
                                  style: const TextStyle(
                                      color: _calendarMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
