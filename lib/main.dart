import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final isDark = _themeMode != ThemeMode.dark;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مهامي',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: TodoPage(onToggleTheme: _toggleTheme),
    );
  }
}

class Task {
  String title;
  bool isDone;

  Task({required this.title, this.isDone = false});

  Map<String, dynamic> toJson() => {'title': title, 'isDone': isDone};

  factory Task.fromJson(Map<String, dynamic> json) =>
      Task(title: json['title'], isDone: json['isDone']);
}

enum TaskFilter { all, active, done }

class TodoPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const TodoPage({super.key, required this.onToggleTheme});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<Task> _tasks = [];
  final TextEditingController _controller = TextEditingController();
  TaskFilter _filter = TaskFilter.all;

  List<MapEntry<int, Task>> get _visibleTasks {
    final entries = _tasks.asMap().entries;
    switch (_filter) {
      case TaskFilter.active:
        return entries.where((e) => !e.value.isDone).toList();
      case TaskFilter.done:
        return entries.where((e) => e.value.isDone).toList();
      case TaskFilter.all:
        return entries.toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('tasks');
    if (data == null) return;

    final list = jsonDecode(data) as List;
    setState(() {
      _tasks.addAll(list.map((e) => Task.fromJson(e)));
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tasks',
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(Task(title: text));
    });
    _saveTasks();
    _controller.clear();
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isDone = !_tasks[index].isDone;
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _addTask(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب مهمة جديدة...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addTask,
                  child: const Text('إضافة'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TaskFilter>(
              segments: const [
                ButtonSegment(value: TaskFilter.all, label: Text('الكل')),
                ButtonSegment(
                    value: TaskFilter.active, label: Text('المتبقية')),
                ButtonSegment(value: TaskFilter.done, label: Text('المكتملة')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('مفيش مهام هنا 🎉'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final index = visible[i].key;
                      final task = visible[i].value;
                      return ListTile(
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (_) => _toggleTask(index),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isDone ? Colors.grey : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteTask(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}