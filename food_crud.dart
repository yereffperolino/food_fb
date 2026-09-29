import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodTask {
	const FoodTask({required this.id, required this.title});

	final String id;
	final String title;
}

abstract interface class TaskRepository {
	Stream<List<FoodTask>> watchTasks();
	Future<void> addTask(String title);
	Future<void> updateTask(String id, String title);
	Future<void> deleteTask(String id);
}

class FirestoreTaskRepository implements TaskRepository {
	FirestoreTaskRepository(FirebaseFirestore firestore)
			: _tasks = firestore.collection('tasks');

	final CollectionReference<Map<String, dynamic>> _tasks;

	@override
	Stream<List<FoodTask>> watchTasks() => _tasks
			.orderBy('createdAt', descending: true)
			.snapshots()
			.map((snapshot) => snapshot.docs
					.map((document) => FoodTask(
								id: document.id,
								title: document.data()['title'] as String? ?? '',
							))
					.toList());

	@override
	Future<void> addTask(String title) => _tasks.add({
				'title': title,
				'createdAt': FieldValue.serverTimestamp(),
			});

	@override
	Future<void> updateTask(String id, String title) =>
			_tasks.doc(id).update({'title': title});

	@override
	Future<void> deleteTask(String id) => _tasks.doc(id).delete();
}

class LocalTaskRepository implements TaskRepository {
	final List<FoodTask> _tasks = [];
	final StreamController<List<FoodTask>> _controller =
			StreamController<List<FoodTask>>.broadcast();
	var _nextId = 0;

	@override
	Stream<List<FoodTask>> watchTasks() async* {
		yield List.unmodifiable(_tasks);
		yield* _controller.stream;
	}

	void _publish() => _controller.add(List.unmodifiable(_tasks));

	@override
	Future<void> addTask(String title) async {
		_tasks.insert(0, FoodTask(id: '${_nextId++}', title: title));
		_publish();
	}

	@override
	Future<void> updateTask(String id, String title) async {
		final index = _tasks.indexWhere((task) => task.id == id);
		if (index != -1) _tasks[index] = FoodTask(id: id, title: title);
		_publish();
	}

	@override
	Future<void> deleteTask(String id) async {
		_tasks.removeWhere((task) => task.id == id);
		_publish();
	}
}
