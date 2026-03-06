import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- КОНСТАНТЫ ---
const String boxGames = 'games_box';
const String boxSettings = 'settings_box';
const String keyTemplate = 'default_criteria';

const List<String> allAvailableGenres = [
  'Action',
  'RPG',
  'Shooter',
  'Adventure',
  'Indie',
  'Strategy',
  'Simulation',
  'Horror',
  'Puzzle',
  'Platformer',
  'Racing',
  'Sports',
];

Future<void> migrateGenresIfNeeded() async {
  final box = Hive.box(boxGames);
  for (int i = 0; i < box.length; i++) {
    final game = box.getAt(i);
    if (game != null && game['genres'] is String) {
      String oldGenres = game['genres'] as String;

      List<String> newGenres = oldGenres
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedGame = Map<String, dynamic>.from(game);
      updatedGame['genres'] = newGenres;
      await box.putAt(i, updatedGame);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(boxGames);
  await Hive.openBox(boxSettings);

  await migrateGenresIfNeeded();

  final settings = Hive.box(boxSettings);
  if (settings.get(keyTemplate) == null) {
    settings.put(keyTemplate, ['Геймплей', 'Сюжет', 'Графика', 'Оптимизация']);
  }

  runApp(const GameReviewApp());
}

class GameReviewApp extends StatelessWidget {
  const GameReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- ENUM для сортировки ---
enum SortMode { dateDesc, dateAsc, liked, disliked, neutral }

// --- ГЛАВНЫЙ ЭКРАН ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isGridView = false;
  String searchQuery = "";
  SortMode sortMode = SortMode.dateDesc;
  final Box gamesBox = Hive.box(boxGames);
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _getSortedAndFiltered(List<dynamic> games) {
    // Фильтрация по поиску
    var result = games.where((g) {
      final title = (g['title'] ?? '').toString().toLowerCase();
      return title.contains(searchQuery.toLowerCase());
    }).toList();

    // Сортировка
    switch (sortMode) {
      case SortMode.dateDesc:
        result.sort((a, b) {
          final da = DateTime.tryParse(a['dateTime'] ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['dateTime'] ?? '') ?? DateTime(0);
          return db.compareTo(da);
        });
        break;
      case SortMode.dateAsc:
        result.sort((a, b) {
          final da = DateTime.tryParse(a['dateTime'] ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['dateTime'] ?? '') ?? DateTime(0);
          return da.compareTo(db);
        });
        break;
      case SortMode.liked:
        result = result.where((g) => g['status'] == 'Like').toList();
        break;
      case SortMode.disliked:
        result = result.where((g) => g['status'] == 'Dislike').toList();
        break;
      case SortMode.neutral:
        result = result.where((g) => g['status'] == 'Neutral').toList();
        break;
    }

    return result;
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Сортировка и фильтр',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _sortTile(
              ctx,
              SortMode.dateDesc,
              Icons.arrow_downward,
              'Сначала новые',
            ),
            _sortTile(
              ctx,
              SortMode.dateAsc,
              Icons.arrow_upward,
              'Сначала старые',
            ),
            _sortTile(
              ctx,
              SortMode.liked,
              Icons.sentiment_very_satisfied,
              'Только понравившиеся',
              Colors.greenAccent,
            ),
            _sortTile(
              ctx,
              SortMode.disliked,
              Icons.sentiment_very_dissatisfied,
              'Только не понравившиеся',
              Colors.redAccent,
            ),
            _sortTile(
              ctx,
              SortMode.neutral,
              Icons.sentiment_neutral,
              'Только нейтральные',
              Colors.orangeAccent,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(
    BuildContext ctx,
    SortMode mode,
    IconData icon,
    String label, [
    Color? color,
  ]) {
    final isSelected = sortMode == mode;
    return ListTile(
      leading: Icon(icon, color: color ?? (isSelected ? Colors.cyan : null)),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.cyan) : null,
      onTap: () {
        setState(() => sortMode = mode);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              sortMode != SortMode.dateDesc
                  ? Icons.filter_list
                  : Icons.filter_list_off,
              color: sortMode != SortMode.dateDesc ? Colors.cyan : null,
            ),
            onPressed: () => _showSortMenu(context),
            tooltip: 'Сортировка',
          ),
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск игры...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: gamesBox.listenable(),
        builder: (context, Box box, _) {
          final allGames = box.values.toList();
          final games = _getSortedAndFiltered(allGames);

          if (allGames.isEmpty) {
            return const Center(child: Text('Пусто... Добавь первую игру!'));
          }

          if (games.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.isNotEmpty
                        ? 'Игры не найдены по запросу "$searchQuery"'
                        : 'Нет игр в этой категории',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return isGridView
              ? _buildGrid(games, allGames)
              : _buildList(games, allGames);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddGameSheet(context),
        label: const Text('Добавить'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGrid(List<dynamic> games, List<dynamic> allGames) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 260,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = Map<String, dynamic>.from(games[index]);
        final realIndex = allGames.indexWhere(
          (g) =>
              g['title'] == game['title'] && g['dateTime'] == game['dateTime'],
        );
        return InkWell(
          onTap: () => _openGameDetails(context, games[index], realIndex),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Center(
                    child: _getStatusIcon(game['status'], size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  game['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  game['playTime']?.isNotEmpty == true
                      ? game['playTime']
                      : 'Время не указано',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<dynamic> games, List<dynamic> allGames) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = Map<String, dynamic>.from(games[index]);
        final realIndex = allGames.indexWhere(
          (g) =>
              g['title'] == game['title'] && g['dateTime'] == game['dateTime'],
        );
        return Card(
          child: ListTile(
            onTap: () => _openGameDetails(context, games[index], realIndex),
            leading: CircleAvatar(
              backgroundColor: Colors.black26,
              child: _getStatusIcon(game['status']),
            ),
            title: Text(game['title']),
            subtitle: Text(
              "${(game['genres'] as List).isEmpty ? 'Жанры не указаны' : (game['genres'] as List).join(', ')} • ${game['playTime']?.isNotEmpty == true ? game['playTime'] : 'Время не указано'}",
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(String? status, {double size = 24}) {
    switch (status) {
      case 'Like':
        return Icon(
          Icons.sentiment_very_satisfied,
          color: Colors.greenAccent,
          size: size,
        );
      case 'Dislike':
        return Icon(
          Icons.sentiment_very_dissatisfied,
          color: Colors.redAccent,
          size: size,
        );
      default:
        return Icon(
          Icons.sentiment_neutral,
          color: Colors.orangeAccent,
          size: size,
        );
    }
  }

  void _openAddGameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const AddGameForm(),
    );
  }

  void _openGameDetails(BuildContext context, dynamic data, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => GameDetailScreen(gameData: data, gameIndex: index),
      ),
    );
  }
}

// --- ЭКРАН НАСТРОЕК ШАБЛОНА ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Box settings = Hive.box(boxSettings);
  late List<String> currentCriteria;
  // Контроллеры для каждого поля
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    currentCriteria = List<String>.from(settings.get(keyTemplate) ?? []);
    _controllers = currentCriteria
        .map((c) => TextEditingController(text: c))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCriterion() {
    final newVal = "Новый критерий";
    setState(() {
      currentCriteria.add(newVal);
      _controllers.add(TextEditingController(text: newVal));
    });
    settings.put(keyTemplate, currentCriteria);
  }

  void _removeCriterion(int index) {
    _controllers[index].dispose();
    setState(() {
      currentCriteria.removeAt(index);
      _controllers.removeAt(index);
    });
    settings.put(keyTemplate, currentCriteria);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Шаблон критериев')),
      body: currentCriteria.isEmpty
          ? const Center(
              child: Text(
                'Нет критериев.\nНажмите + чтобы добавить.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentCriteria.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = currentCriteria.removeAt(oldIndex);
                  final ctrl = _controllers.removeAt(oldIndex);
                  currentCriteria.insert(newIndex, item);
                  _controllers.insert(newIndex, ctrl);
                });
                settings.put(keyTemplate, currentCriteria);
              },
              itemBuilder: (context, index) {
                return Card(
                  key: ValueKey('criterion_$index'),
                  child: ListTile(
                    leading: const Icon(Icons.drag_handle, color: Colors.grey),
                    title: TextField(
                      controller: _controllers[index],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Название критерия',
                      ),
                      onChanged: (v) {
                        currentCriteria[index] = v;
                        settings.put(keyTemplate, currentCriteria);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeCriterion(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCriterion,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- ФОРМА ДОБАВЛЕНИЯ ---
class AddGameForm extends StatefulWidget {
  const AddGameForm({super.key});

  @override
  State<AddGameForm> createState() => _AddGameFormState();
}

class _AddGameFormState extends State<AddGameForm> {
  final _titleController = TextEditingController();
  String status = 'Neutral';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Новая игра',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Название игры *'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statusButton(
                'Like',
                Icons.sentiment_very_satisfied,
                Colors.greenAccent,
              ),
              _statusButton(
                'Neutral',
                Icons.sentiment_neutral,
                Colors.orangeAccent,
              ),
              _statusButton(
                'Dislike',
                Icons.sentiment_very_dissatisfied,
                Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              if (_titleController.text.trim().isEmpty) return;
              final List<String> template = List<String>.from(
                Hive.box(boxSettings).get(keyTemplate) ??
                    ['Геймплей', 'Сюжет', 'Графика', 'Оптимизация'],
              );
              final newGame = {
                'title': _titleController.text.trim(),
                'genres': '',
                'playTime': '',
                'status': status,
                'dateTime': DateTime.now().toString(),
                'criteria': template
                    .map((name) => {'name': name, 'score': ''})
                    .toList(),
                'notes': <String>[],
                'finalOpinion': '',
              };
              Hive.box(boxGames).add(newGame);
              Navigator.pop(context);
            },
            child: const Text('Создать запись'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statusButton(String s, IconData icon, Color color) {
    final isSelected = status == s;
    return Column(
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: isSelected ? color : Colors.grey,
            size: isSelected ? 32 : 24,
          ),
          onPressed: () => setState(() => status = s),
        ),
        Text(
          s == 'Like'
              ? 'Нравится'
              : (s == 'Dislike' ? 'Не нравится' : 'Нейтрально'),
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? color : Colors.grey,
          ),
        ),
      ],
    );
  }
}

// --- ЭКРАН ДЕТАЛЕЙ ---
class GameDetailScreen extends StatefulWidget {
  final dynamic gameData;
  final int gameIndex;

  const GameDetailScreen({
    super.key,
    required this.gameData,
    required this.gameIndex,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Map<String, dynamic> data;
  final _noteController = TextEditingController();
  late TextEditingController _playTimeController;
  late TextEditingController _finalOpinionController;

  @override
  void initState() {
    super.initState();
    data = Map<String, dynamic>.from(widget.gameData);
    // Обеспечиваем наличие всех полей
    if (data['genres'] is String) {
      data['genres'] = data['genres'].toString().isEmpty
          ? <String>[]
          : [data['genres'].toString()];
    }
    data['genres'] ??= <String>[];
    data['playTime'] ??= '';
    data['finalOpinion'] ??= '';
    data['notes'] ??= <String>[];
    data['criteria'] ??= [];

    _playTimeController = TextEditingController(text: data['playTime']);
    _finalOpinionController = TextEditingController(text: data['finalOpinion']);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _playTimeController.dispose();
    _finalOpinionController.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.gameIndex >= 0) {
      Hive.box(boxGames).putAt(widget.gameIndex, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(data['title']),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Удалить игру?'),
                  content: Text('«${data['title']}» будет удалена.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        Hive.box(boxGames).deleteAt(widget.gameIndex);
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Удалить',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildCriteriaSection(),
            const SizedBox(height: 20),
            _buildNotesSection(),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Финальный вердикт",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Итоги прохождения...',
              ),
              controller: _finalOpinionController,
              onChanged: (v) {
                data['finalOpinion'] = v;
                _save();
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Статус
            Row(
              children: [
                const Text('Оценка: '),
                const SizedBox(width: 8),
                ...['Like', 'Neutral', 'Dislike'].map((s) {
                  final icons = {
                    'Like': Icons.sentiment_very_satisfied,
                    'Neutral': Icons.sentiment_neutral,
                    'Dislike': Icons.sentiment_very_dissatisfied,
                  };
                  final colors = {
                    'Like': Colors.greenAccent,
                    'Neutral': Colors.orangeAccent,
                    'Dislike': Colors.redAccent,
                  };
                  final isSelected = data['status'] == s;
                  return IconButton(
                    icon: Icon(
                      icons[s],
                      color: isSelected ? colors[s] : Colors.grey,
                      size: isSelected ? 28 : 22,
                    ),
                    onPressed: () {
                      setState(() => data['status'] = s);
                      _save();
                    },
                  );
                }),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Жанры:",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                ...List<String>.from(data['genres']).map(
                  (genre) => InputChip(
                    label: Text(genre),
                    onDeleted: () {
                      setState(() => data['genres'].remove(genre));
                      _save();
                    },
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text("Добавить"),
                  onPressed: () => _showGenrePicker(context),
                ),
              ],
            ),
            const Divider(),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Время прохождения',
                prefixIcon: Icon(Icons.timer),
              ),
              controller: _playTimeController,
              onChanged: (v) {
                data['playTime'] = v;
                _save();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGenrePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final currentGenres = List<String>.from(data['genres']);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Выберите жанр",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: allAvailableGenres.map((genre) {
                    final isSelected = currentGenres.contains(genre);
                    return ListTile(
                      title: Text(genre),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.cyan)
                          : null,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            data['genres'].remove(genre);
                          } else {
                            data['genres'].add(genre);
                          }
                        });
                        _save();
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCriteriaSection() {
    final criteria = List<dynamic>.from(data['criteria'] ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Критерии",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(criteria.length, (index) {
          final c = criteria[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '...',
                      border: InputBorder.none,
                    ),
                    controller: TextEditingController(text: c['score'] ?? '')
                      ..selection = TextSelection.collapsed(
                        offset: (c['score'] ?? '').length,
                      ),
                    onChanged: (v) {
                      data['criteria'][index]['score'] = v;
                      _save();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() {
            data['criteria'].add({'name': 'Новый критерий', 'score': ''});
            _save();
          }),
          icon: const Icon(Icons.add),
          label: const Text("Добавить критерий"),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    final notes = List<String>.from(data['notes'] ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Заметки",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...notes.asMap().entries.map((entry) {
          final note = entry.value;
          return Dismissible(
            key: Key('note_${entry.key}_$note'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            onDismissed: (_) {
              setState(() => data['notes'].removeAt(entry.key));
              _save();
            },
            child: Card(child: ListTile(title: Text(note))),
          );
        }),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            hintText: 'Добавить заметку...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                if (_noteController.text.trim().isEmpty) return;
                setState(() {
                  data['notes'].add(_noteController.text.trim());
                  _noteController.clear();
                });
                _save();
              },
            ),
          ),
        ),
      ],
    );
  }
}
