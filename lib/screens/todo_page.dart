// lib/screens/todo_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  List<Todo> _todos = [];
  String _selectedCategory = 'All';

  // Default and custom categories combined
  List<String> _categories = [
    'All',
    'General',
    'Biology',
    'Computer Science',
    'Physics',
  ];

  // Preset colors for task tags
  final List<Color> _availableColors = const [
    Color(0xFF6C5CE7), // Default Purple
    Color(0xFF2E7D32), // Green
    Color(0xFF1565C0), // Blue
    Color(0xFFC62828), // Red
    Color(0xFFE67E22), // Orange
    Color(0xFF00838F), // Teal
    Color(0xFF8E24AA), // Magenta
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- Persistence Logic ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load custom categories
    final List<String>? customCats = prefs.getStringList('custom_categories');
    if (customCats != null) {
      setState(() {
        for (var cat in customCats) {
          if (!_categories.contains(cat)) {
            _categories.add(cat);
          }
        }
      });
    }

    // Load tasks
    final String? data = prefs.getString('todos');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _todos = decoded.map((item) => Todo.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_todos.map((t) => t.toJson()).toList());
    await prefs.setString('todos', data);
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final customList = _categories.where((c) => c != 'All').toList();
    await prefs.setStringList('custom_categories', customList);
  }

  // --- Action Handlers ---
  void _addTodo(String title, String category, Color taskColor) {
    if (title.trim().isEmpty) return;
    setState(() {
      _todos.add(
        Todo(
          title: title.trim(),
          category: category,
          colorHex: taskColor.value,
        ),
      );
    });
    _saveTodos();
  }

  void _toggleDone(String id) {
    setState(() {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index != -1) {
        _todos[index].done = !_todos[index].done;
      }
    });
    _saveTodos();
  }

  void _deleteTodo(String id) {
    setState(() {
      _todos.removeWhere((t) => t.id == id);
    });
    _saveTodos();
  }

  List<Todo> get _filteredTodos {
    if (_selectedCategory == 'All') return _todos;
    return _todos.where((t) => t.category == _selectedCategory).toList();
  }

  int get _completedCount => _todos.where((t) => t.done).length;

  // --- Color Helpers ---
  Color _getCategoryColor(Todo todo) {
    if (todo.colorHex != null) {
      return Color(todo.colorHex!);
    }
    switch (todo.category) {
      case 'Biology':
        return const Color(0xFF2E7D32);
      case 'Computer Science':
        return const Color(0xFF1565C0);
      case 'Physics':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  // --- Add Task Modal Sheet ---
  void _showAddTaskSheet() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController customCatController = TextEditingController();

    String chosenCategory =
        _selectedCategory == 'All' ? 'General' : _selectedCategory;
    Color chosenColor = _availableColors.first;
    bool isAddingCustomCat = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = Theme.of(context).colorScheme.onSurface;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Focus Task',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: TextStyle(fontSize: 16, color: textColor),
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Read Ch. 4 Cell Division or Solve 5 problems',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Theme.of(context).scaffoldBackgroundColor
                            : const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Category Section ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subject Group',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setModalState(() {
                              isAddingCustomCat = !isAddingCustomCat;
                            });
                          },
                          icon: Icon(
                            isAddingCustomCat ? Icons.close : Icons.add_rounded,
                            size: 16,
                            color: const Color(0xFF6C5CE7),
                          ),
                          label: Text(
                            isAddingCustomCat ? 'Cancel' : 'New Subject',
                            style: const TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (isAddingCustomCat) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customCatController,
                              style: TextStyle(fontSize: 14, color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Subject Name (e.g., History)',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF6C5CE7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final name = customCatController.text.trim();
                              if (name.isNotEmpty) {
                                setState(() {
                                  if (!_categories.contains(name)) {
                                    _categories.add(name);
                                  }
                                });
                                _saveCategories();
                                setModalState(() {
                                  chosenCategory = name;
                                  isAddingCustomCat = false;
                                });
                              }
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories
                          .where((c) => c != 'All')
                          .map((cat) {
                            final isSelected = chosenCategory == cat;
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor:
                                  chosenColor.withOpacity(isDark ? 0.25 : 0.15),
                              backgroundColor: isDark
                                  ? Theme.of(context).scaffoldBackgroundColor
                                  : const Color(0xFFF1F3F4),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? chosenColor
                                    : textColor.withOpacity(0.7),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? chosenColor.withOpacity(0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => chosenCategory = cat);
                                }
                              },
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 20),

                    // --- Custom Color Picker Section ---
                    Text(
                      'Task Color Tag',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: _availableColors.map((color) {
                        final isSelected = chosenColor.value == color.value;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => chosenColor = color);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: textColor, width: 2.5)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: chosenColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (titleController.text.trim().isNotEmpty) {
                            _addTodo(
                              titleController.text,
                              chosenCategory,
                              chosenColor,
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text(
                          'Add Task',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Text(
          'To-Do List',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 2,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Task',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // --- 1. Progress Summary Card ---
              _buildProgressCard(),

              // --- 2. Category Filter Pills ---
              _buildCategorySelector(),

              // --- 3. Task List View ---
              Expanded(
                child: _filteredTodos.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 80,
                        ),
                        itemCount: _filteredTodos.length,
                        itemBuilder: (context, index) {
                          final todo = _filteredTodos[index];
                          return _buildTaskTile(todo);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniStopwatchBar(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StopwatchPage()),
              );
            },
          ),
          const MiniAudioPlayer(),
        ],
      ),
    );
  }

  // --- Widget Builders ---
  Widget _buildProgressCard() {
    final total = _todos.length;
    final double progress = total == 0 ? 0 : _completedCount / total;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Study Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cognitive offloading for deep focus',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_completedCount / $total Done',
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(cat),
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : textColor.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              backgroundColor: Theme.of(context).cardColor,
              selectedColor: textColor,
              elevation: 0,
              pressElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? textColor
                      : Theme.of(context).dividerColor,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = cat;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskTile(Todo todo) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tagColor = _getCategoryColor(todo);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: todo.done,
            activeColor: tagColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(color: textColor.withOpacity(0.4), width: 1.5),
            onChanged: (_) => _toggleDone(todo.id),
          ),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: todo.done ? textColor.withOpacity(0.35) : textColor,
            decoration: todo.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: UnconstrainedBox(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                todo.category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tagColor,
                ),
              ),
            ),
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: textColor.withOpacity(0.35),
            size: 20,
          ),
          onPressed: () => _deleteTodo(todo.id),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'All'
                ? 'No focus tasks yet!'
                : 'No tasks in $_selectedCategory',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "+ New Task" to offload your thoughts.',
            style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}