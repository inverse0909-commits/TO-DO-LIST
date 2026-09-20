import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TaskStore();
  await store.load();
  runApp(TodoListApp(store: store));
}

class TodoTask {
  final String id;
  String title;
  String description;
  DateTime dueDate;
  Priority priority;
  bool completed;

  TodoTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.priority = Priority.low,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'priority': priority.name,
        'completed': completed,
      };

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
        id: json['id'] as String,
        title: json['title'] as String,
        description: (json['description'] ?? '') as String,
        dueDate: DateTime.parse(json['dueDate'] as String),
        priority: Priority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => Priority.low,
        ),
        completed: (json['completed'] ?? false) as bool,
      );
}

enum Priority { high, low }

class TaskStore extends ChangeNotifier {
  final List<TodoTask> tasks = [];
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString('todo_tasks');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        tasks
          ..clear()
          ..addAll(list.map((e) => TodoTask.fromJson(
                Map<String, dynamic>.from(e as Map),
              )));
      } catch (_) {}
    }
    if (tasks.isEmpty) {
      final now = DateTime.now();
      tasks.addAll([
        TodoTask(
          id: '1',
          title: 'Finish project report',
          description: 'Prepare the final report for submission.',
          dueDate: DateTime(now.year, now.month, now.day),
          priority: Priority.high,
        ),
        TodoTask(
          id: '2',
          title: 'Buy groceries',
          description: 'Pick up the essentials for this week.',
          dueDate: DateTime(now.year, now.month, now.day),
          priority: Priority.low,
        ),
        TodoTask(
          id: '3',
          title: 'Study Flutter',
          description: 'Practice Flutter widgets and state management.',
          dueDate: DateTime(now.year, now.month, now.day + 1),
          priority: Priority.high,
        ),
        TodoTask(
          id: '4',
          title: 'Workout',
          description: 'Short evening workout.',
          dueDate: DateTime(now.year, now.month, now.day - 1),
          priority: Priority.low,
          completed: true,
        ),
        TodoTask(
          id: '5',
          title: 'Read a book',
          description: 'Read at least one chapter.',
          dueDate: DateTime(now.year, now.month, now.day - 2),
          priority: Priority.low,
          completed: true,
        ),
      ]);
      await save();
    }
    notifyListeners();
  }

  Future<void> save() async {
    await _prefs?.setString(
      'todo_tasks',
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
    notifyListeners();
  }

  void add(TodoTask task) {
    tasks.insert(0, task);
    save();
  }

  void update(TodoTask task) {
    final i = tasks.indexWhere((t) => t.id == task.id);
    if (i != -1) {
      tasks[i] = task;
      save();
    }
  }

  void delete(String id) {
    tasks.removeWhere((t) => t.id == id);
    save();
  }

  void toggle(TodoTask task) {
    task.completed = !task.completed;
    save();
  }

  int get completedCount => tasks.where((t) => t.completed).length;
  int get remainingCount => tasks.where((t) => !t.completed).length;
  double get progress => tasks.isEmpty ? 0 : completedCount / tasks.length;
}

class TodoListApp extends StatelessWidget {
  final TaskStore store;
  const TodoListApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TO DO LIST',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF06172B),
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3D8BFF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: HomeScreen(store: store),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final TaskStore store;
  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum TaskFilter { all, today, high, completed }

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  TaskFilter filter = TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    if (tab == 1) return StatsScreen(store: widget.store, onHome: () => setState(() => tab = 0));
    if (tab == 2) return SettingsScreen(store: widget.store, onHome: () => setState(() => tab = 0));

    final visible = widget.store.tasks.where((t) {
      switch (filter) {
        case TaskFilter.all:
          return true;
        case TaskFilter.today:
          return isSameDay(t.dueDate, DateTime.now());
        case TaskFilter.high:
          return t.priority == Priority.high && !t.completed;
        case TaskFilter.completed:
          return t.completed;
      }
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(context)),
                  SliverToBoxAdapter(child: _summary()),
                  SliverToBoxAdapter(child: _filters()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        filter == TaskFilter.completed ? 'Completed' : 'Today',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => TaskCard(
                          task: visible[i],
                          onToggle: () => widget.store.toggle(visible[i]),
                          onMenu: () => showTaskOptions(context, visible[i], widget.store),
                          onOpen: () => openDetails(context, visible[i], widget.store),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _bottomNav(),
          ],
        ),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton(
              onPressed: () => showTaskForm(context, widget.store),
              backgroundColor: const Color(0xFF2E7CFF),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
    );
  }

  Widget _header(BuildContext context) {
    final date = DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: MountainPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7CFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To Do List', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      Text(date, style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => tab = 2),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 22,
            bottom: 18,
            child: Text(
              'Small steps every day\nlead to big results.',
              style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCC102A49),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _metric(Icons.assignment_outlined, '${widget.store.remainingCount}', 'Tasks Left', const Color(0xFF43A5FF)),
            _divider(),
            _metric(Icons.check_circle_outline, '${widget.store.completedCount}', 'Completed', const Color(0xFF35D99A)),
            _divider(),
            Expanded(
              child: Column(
                children: [
                  ProgressRing(progress: widget.store.progress, size: 54),
                  const SizedBox(height: 4),
                  const Text('Progress', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 50, color: Colors.white.withValues(alpha: .08));

  Widget _filters() {
    return SizedBox(
      height: 43,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          FilterPill(label: 'All', icon: Icons.tune_rounded, active: filter == TaskFilter.all, onTap: () => setState(() => filter = TaskFilter.all)),
          FilterPill(label: 'Today', active: filter == TaskFilter.today, onTap: () => setState(() => filter = TaskFilter.today)),
          FilterPill(label: 'High Priority', icon: Icons.priority_high_rounded, color: const Color(0xFFFF3F70), active: filter == TaskFilter.high, onTap: () => setState(() => filter = TaskFilter.high)),
          FilterPill(label: 'Completed', icon: Icons.check_circle, color: const Color(0xFF3BE09B), active: filter == TaskFilter.completed, onTap: () => setState(() => filter = TaskFilter.completed)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.nights_stay_rounded, size: 70, color: Color(0xFF5E9FFF)),
            const SizedBox(height: 15),
            const Text('No tasks yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Add something you want to\naccomplish.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => showTaskForm(context, widget.store),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF07182B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .06))),
      ),
      child: Row(
        children: [
          _nav(Icons.home_rounded, 'Home', 0),
          _nav(Icons.bar_chart_rounded, 'Stats', 1),
          _nav(Icons.settings_outlined, 'Settings', 2),
        ],
      ),
    );
  }

  Widget _nav(IconData icon, String label, int index) {
    final active = tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => tab = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? const Color(0xFF55A2FF) : Colors.white54),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, color: active ? const Color(0xFF55A2FF) : Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onToggle;
  final VoidCallback onMenu;
  final VoidCallback onOpen;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onMenu,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final accent = task.priority == Priority.high ? const Color(0xFFFF3D70) : const Color(0xFF188CFF);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xD9122942),
          borderRadius: BorderRadius.circular(15),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(5),
                  color: task.completed ? const Color(0xFF39D99B) : Colors.transparent,
                  border: Border.all(color: task.completed ? const Color(0xFF39D99B) : Colors.white70, width: 1.5),
                ),
                child: task.completed ? const Icon(Icons.check, size: 16, color: Colors.black87) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: task.completed ? TextDecoration.lineThrough : null,
                      color: task.completed ? Colors.white54 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(DateFormat('MMM d, yyyy').format(task.dueDate), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
            PriorityBadge(priority: task.priority),
            IconButton(onPressed: onMenu, icon: const Icon(Icons.more_vert_rounded, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final Priority priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final high = priority == Priority.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (high ? const Color(0xFFFF3569) : const Color(0xFF087FEA)).withValues(alpha: .18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: (high ? const Color(0xFFFF3569) : const Color(0xFF087FEA)).withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(high ? Icons.priority_high : Icons.download_rounded, size: 13, color: high ? const Color(0xFFFF4778) : const Color(0xFF3CA1FF)),
          const SizedBox(width: 3),
          Text(high ? 'High' : 'Low', style: TextStyle(fontSize: 10, color: high ? const Color(0xFFFF6A91) : const Color(0xFF4CA7FF), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool active;
  final VoidCallback onTap;

  const FilterPill({super.key, required this.label, this.icon, this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF4D9BFF);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.withValues(alpha: .25) : const Color(0xB3172B46),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? c : Colors.white.withValues(alpha: .04)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: active ? c : Colors.white54),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  const ProgressRing({super.key, required this.progress, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ProgressPainter(progress),
        child: Center(
          child: Text('${(progress * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * .19)),
        ),
      ),
    );
  }
}

class ProgressPainter extends CustomPainter {
  final double progress;
  ProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final base = Paint()
      ..color = const Color(0xFF21344A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = const Color(0xFF39D99B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, base);
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant ProgressPainter oldDelegate) => oldDelegate.progress != progress;
}

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF081A35), Color(0xFF0C2B51)],
    ).createShader(rect);
    canvas.drawRect(rect, bg);

    final moon = Paint()..color = const Color(0xFFFFA8D1).withValues(alpha: .55);
    canvas.drawCircle(Offset(size.width * .70, 70), 23, moon);

    Path back = Path()..moveTo(0, size.height * .84);
    back.lineTo(size.width * .18, size.height * .52);
    back.lineTo(size.width * .30, size.height * .70);
    back.lineTo(size.width * .48, size.height * .38);
    back.lineTo(size.width * .67, size.height * .70);
    back.lineTo(size.width * .82, size.height * .49);
    back.lineTo(size.width, size.height * .78);
    back.lineTo(size.width, size.height);
    back.lineTo(0, size.height);
    back.close();
    canvas.drawPath(back, Paint()..color = const Color(0xFF172D62).withValues(alpha: .8));

    Path front = Path()..moveTo(0, size.height * .90);
    front.lineTo(size.width * .24, size.height * .64);
    front.lineTo(size.width * .42, size.height * .82);
    front.lineTo(size.width * .58, size.height * .56);
    front.lineTo(size.width * .76, size.height * .84);
    front.lineTo(size.width, size.height * .62);
    front.lineTo(size.width, size.height);
    front.lineTo(0, size.height);
    front.close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF081D3A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> showTaskForm(BuildContext context, TaskStore store, {TodoTask? existing}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  DateTime date = existing?.dueDate ?? DateTime.now();
  Priority priority = existing?.priority ?? Priority.high;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A1D34),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 22),
              Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF3156B9), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.edit_rounded)),
                const SizedBox(width: 10),
                Text(existing == null ? 'Add New Task' : 'Edit Task', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 22),
              const Text('Task Name *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _input(title, existing == null ? 'e.g. Finish project report' : null),
              const SizedBox(height: 16),
              const Text('Description (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _input(description, 'Add more details...', maxLines: 3),
              const SizedBox(height: 16),
              const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: date,
                    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF398BFF))), child: child!),
                  );
                  if (d != null) setSheet(() => date = d);
                },
                child: _selectBox(Icons.calendar_month_rounded, DateFormat('MMM d, yyyy').format(date)),
              ),
              const SizedBox(height: 16),
              const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _priorityButton('High', Icons.priority_high_rounded, Priority.high, priority, (p) => setSheet(() => priority = p))),
                const SizedBox(width: 10),
                Expanded(child: _priorityButton('Low', Icons.download_rounded, Priority.low, priority, (p) => setSheet(() => priority = p))),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    final task = TodoTask(
                      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title.text.trim(),
                      description: description.text.trim(),
                      dueDate: date,
                      priority: priority,
                      completed: existing?.completed ?? false,
                    );
                    if (existing == null) {
                      store.add(task);
                    } else {
                      store.update(task);
                    }
                    Navigator.pop(context);
                  },
                  icon: Icon(existing == null ? Icons.add_rounded : Icons.save_rounded),
                  label: Text(existing == null ? 'Add Task' : 'Update Task'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _input(TextEditingController controller, String? hint, {int maxLines = 1}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF173456),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.all(14),
    ),
  );
}

Widget _selectBox(IconData icon, String text) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF173456), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(text), const Spacer(), const Icon(Icons.chevron_right_rounded)]),
  );
}

Widget _priorityButton(String text, IconData icon, Priority value, Priority selected, ValueChanged<Priority> onChanged) {
  final active = value == selected;
  final c = value == Priority.high ? const Color(0xFFFF3C6F) : const Color(0xFF238DFF);
  return InkWell(
    onTap: () => onChanged(value),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: active ? c.withValues(alpha: .22) : const Color(0xFF173456),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? c : Colors.transparent),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 18, color: active ? c : Colors.white70),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: active ? Colors.white : Colors.white70, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

Future<void> showTaskOptions(BuildContext context, TodoTask task, TaskStore store) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0A1D34),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          const Text('Task Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Edit'), onTap: () { Navigator.pop(context); showTaskForm(context, store, existing: task); }),
          ListTile(leading: const Icon(Icons.flag_rounded, color: Color(0xFFFFC45D)), title: const Text('Change Priority'), onTap: () { task.priority = task.priority == Priority.high ? Priority.low : Priority.high; store.update(task); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.delete_rounded, color: Color(0xFFFF3D70)), title: const Text('Delete'), onTap: () { store.delete(task.id); Navigator.pop(context); }),
        ]),
      ),
    ),
  );
}

Future<void> openDetails(BuildContext context, TodoTask task, TaskStore store) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task, store: store)));
}

class TaskDetailsScreen extends StatelessWidget {
  final TodoTask task;
  final TaskStore store;
  const TaskDetailsScreen({super.key, required this.task, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 180,
                    child: Stack(children: [
                      Positioned.fill(child: CustomPaint(painter: MountainPainter())),
                      Positioned(top: 10, left: 12, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back))),
                      Positioned(top: 10, right: 12, child: IconButton(onPressed: () => showTaskOptions(context, task, store), icon: const Icon(Icons.more_vert))),
                      Positioned(left: 22, bottom: 20, child: Row(children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFF445BC1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_rounded, size: 18)),
                        const SizedBox(width: 10),
                        Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ])),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      PriorityBadge(priority: task.priority),
                      const SizedBox(height: 18),
                      _detailBox(Icons.calendar_today_outlined, 'Due Date', DateFormat('MMM d, yyyy').format(task.dueDate)),
                      const SizedBox(height: 10),
                      _detailBox(Icons.description_outlined, 'Description', task.description.isEmpty ? 'No description.' : task.description),
                      const SizedBox(height: 10),
                      _detailBox(Icons.radio_button_checked, 'Status', task.completed ? 'Completed' : 'Not Completed'),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () { store.toggle(task); Navigator.pop(context); },
                  icon: Icon(task.completed ? Icons.undo_rounded : Icons.check_circle_outline),
                  label: Text(task.completed ? 'Mark as Not Completed' : 'Mark as Completed'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailBox(IconData icon, String title, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xCC122943), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF6EB3FF)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ])),
    ]),
  );
}

class StatsScreen extends StatelessWidget {
  final TaskStore store;
  final VoidCallback onHome;
  const StatsScreen({super.key, required this.store, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final high = store.tasks.where((t) => t.priority == Priority.high).length;
    final low = store.tasks.where((t) => t.priority == Priority.low).length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _titleBar('Your Progress', onHome),
          Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: const Color(0xCC102A49), borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                ProgressRing(progress: store.progress, size: 130),
                const SizedBox(width: 22),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _legend(const Color(0xFF3D9BFF), '${store.remainingCount} Tasks Left'),
                  const SizedBox(height: 12),
                  _legend(const Color(0xFF35D99A), '${store.completedCount} Completed'),
                  const SizedBox(height: 12),
                  _legend(Colors.white70, '${store.tasks.length} Total Tasks'),
                ])),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('Priority Breakdown', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statBox('High Priority', '$high', const Color(0xFFFF3D70), Icons.priority_high)),
              const SizedBox(width: 10),
              Expanded(child: _statBox('Low Priority', '$low', const Color(0xFF3D9BFF), Icons.download_rounded)),
            ]),
            const SizedBox(height: 25),
            const Text('This Week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              height: 190,
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
              decoration: BoxDecoration(color: const Color(0xCC102A49), borderRadius: BorderRadius.circular(16)),
              child: CustomPaint(painter: WeekChartPainter(store.tasks)),
            ),
          ])),
          _simpleBottom(onHome),
        ]),
      ),
    );
  }

  Widget _legend(Color c, String text) => Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 12))]);
  Widget _statBox(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: .3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color))]),
  );
}

class WeekChartPainter extends CustomPainter {
  final List<TodoTask> tasks;
  WeekChartPainter(this.tasks);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .08)..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final y = i * size.height / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final bar = Paint()..color = const Color(0xFF3D8BFF);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 0; i < 7; i++) {
      final x = (i + .5) * size.width / 7;
      final count = tasks.where((t) => t.dueDate.weekday == i + 1 && t.completed).length;
      final h = math.min(size.height * .72, 18.0 + count * 28.0);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 8, size.height - h - 22, 16, h), const Radius.circular(5)), bar);
      final tp = TextPainter(text: TextSpan(text: days[i], style: const TextStyle(fontSize: 9, color: Colors.white54)), textDirection: ui.TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 17));
    }
  }
  @override
  bool shouldRepaint(covariant WeekChartPainter oldDelegate) => true;
}

class SettingsScreen extends StatelessWidget {
  final TaskStore store;
  final VoidCallback onHome;
  const SettingsScreen({super.key, required this.store, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(children: [
        _titleBar('Settings', onHome),
        Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
          _setting('Dark Appearance', 'The app uses the dark blue theme.', Icons.dark_mode_outlined, null),
          _setting('Notifications', 'Reminders can be connected later.', Icons.notifications_none_rounded, null),
          _setting('Data', '${store.tasks.length} tasks stored on this device.', Icons.storage_outlined, null),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () => _confirmClear(context),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear All Tasks'),
          ),
        ])),
        _simpleBottom(onHome),
      ])),
    );
  }

  Widget _setting(String title, String subtitle, IconData icon, Widget? trailing) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xCC102A49), borderRadius: BorderRadius.circular(14)),
    child: Row(children: [Icon(icon, color: const Color(0xFF66AAFF)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))])), if (trailing != null) trailing]),
  );

  void _confirmClear(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Clear all tasks?'),
      content: const Text('This removes all saved tasks from this device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { store.tasks.clear(); store.save(); Navigator.pop(context); }, child: const Text('Clear')),
      ],
    ));
  }
}

Widget _titleBar(String title, VoidCallback onHome) => Container(
  height: 72,
  padding: const EdgeInsets.symmetric(horizontal: 18),
  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: .06)))),
  child: Row(children: [IconButton(onPressed: onHome, icon: const Icon(Icons.arrow_back_rounded)), Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))]),
);

Widget _simpleBottom(VoidCallback onHome) => SizedBox(
  height: 70,
  child: Row(children: [
    Expanded(child: InkWell(onTap: onHome, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.home_rounded, color: Color(0xFF55A2FF)), Text('Home', style: TextStyle(fontSize: 11, color: Color(0xFF55A2FF)))]))),
    const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bar_chart_rounded, color: Color(0xFF9B76FF)), Text('Stats', style: TextStyle(fontSize: 11, color: Color(0xFF9B76FF)))])),
    Expanded(child: InkWell(onTap: onHome, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.settings_outlined, color: Colors.white54), Text('Settings', style: TextStyle(fontSize: 11, color: Colors.white54))]))),
  ]),
);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
