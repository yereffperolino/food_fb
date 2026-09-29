import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'food_crud.dart';
export 'food_crud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final TaskRepository repository;
  var firestoreEnabled = false;
  try {
    await Firebase.initializeApp();
    repository = FirestoreTaskRepository(FirebaseFirestore.instance);
    firestoreEnabled = true;
  } catch (_) {
    repository = LocalTaskRepository();
  }

  runApp(
      FoodListApp(repository: repository, firestoreEnabled: firestoreEnabled));
}

class FoodListApp extends StatelessWidget {
  const FoodListApp({
    super.key,
    required this.repository,
    required this.firestoreEnabled,
  });

  final TaskRepository repository;
  final bool firestoreEnabled;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF11758A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food List',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F8),
          foregroundColor: Color(0xFF252B2E),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF252B2E),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEEF2F4),
          hintStyle: const TextStyle(color: Color(0xFF899398)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: teal, width: 1.5),
          ),
        ),
      ),
      home: FoodListPage(
          repository: repository, firestoreEnabled: firestoreEnabled),
    );
  }
}

class FoodListPage extends StatefulWidget {
  const FoodListPage({
    super.key,
    required this.repository,
    required this.firestoreEnabled,
  });

  final TaskRepository repository;
  final bool firestoreEnabled;

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {
  final _taskController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) {
      _showMessage('Enter a task before adding it.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.repository.addTask(title);
      _taskController.clear();
    } catch (_) {
      _showMessage(
          'Could not save the task. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editTask(FoodTask task) async {
    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (_) => EditTaskDialog(initialTitle: task.title),
    );

    if (updatedTitle == null) return;
    if (updatedTitle.isEmpty) {
      _showMessage('A task cannot be empty.');
      return;
    }
    try {
      await widget.repository.updateTask(task.id, updatedTitle);
    } catch (_) {
      _showMessage('Could not update the task. Try again.');
    }
  }

  Future<void> _deleteTask(FoodTask task) async {
    try {
      await widget.repository.deleteTask(task.id);
    } catch (_) {
      _showMessage('Could not delete the task. Try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food List')),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.firestoreEnabled)
              const MaterialBanner(
                content: Text(
                    'Firebase is not configured. Changes are temporary on this device.'),
                leading: Icon(Icons.cloud_off_outlined),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                actions: [SizedBox.shrink()],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _taskController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTask(),
                        decoration: const InputDecoration(
                            hintText: 'Add a new task...'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 48,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _addTask,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF11758A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FoodTask>>(
                stream: widget.repository.watchTasks(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Tasks could not be loaded.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tasks = snapshot.data!;
                  if (tasks.isEmpty) {
                    return const Center(
                      child: Text(
                          'Your list is empty. Add a task to get started.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Container(
                        constraints: const BoxConstraints(minHeight: 50),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFCFD),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 10,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        padding: const EdgeInsets.only(left: 14, right: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF3B4144)),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit task',
                              onPressed: () => _editTask(task),
                              icon: const Icon(Icons.edit_outlined, size: 19),
                              color: const Color(0xFF758187),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              tooltip: 'Delete task',
                              onPressed: () => _deleteTask(task),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: const Color(0xFFD94343),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTaskDialog extends StatefulWidget {
  const EditTaskDialog({super.key, required this.initialTitle});

  final String initialTitle;

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit task'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Task name'),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

