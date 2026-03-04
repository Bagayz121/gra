import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

// --- КОНСТАНТЫ И НАСТРОЙКИ ---
const String boxName = 'games_box';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(boxName);
  runApp(const GameReviewApp());
}

class GameReviewApp extends StatelessWidget {
  const GameReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameReviewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- ГЛАВНЫЙ ЭКРАН ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isGridView = true;
  final Box box = Hive.box(boxName);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Игры'),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          final games = box.values.toList().reversed.toList();

          if (games.isEmpty) {
            return const Center(child: Text('Пока нет добавленных игр'));
          }

          return isGridView ? _buildGrid(games) : _buildList(games);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddGameSheet(context),
        label: const Text('Добавить игру'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // --- ГРИД (2 игры в ряд) ---
  Widget _buildGrid(List<dynamic> games) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 300, // Фиксированная высота для выравнивания
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = Map<String, dynamic>.from(games[index]);
        return GestureDetector(
          onTap: () => _openGameDetails(context, games[index], index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.grey[850],
                    width: double.infinity,
                    child: const Icon(
                      Icons.videogame_asset,
                      size: 50,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game['title'] ?? 'Без названия',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
              _getStatusIcon(game['status'], small: true),
            ],
          ),
        );
      },
    );
  }

  // --- СПИСОК (1 игра в ряд) ---
  Widget _buildList(List<dynamic> games) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = Map<String, dynamic>.from(games[index]);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _openGameDetails(context, games[index], index),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 80,
                color: Colors.grey[850],
                child: const Icon(Icons.videogame_asset, color: Colors.white24),
              ),
            ),
            title: Text(game['title'] ?? 'N/A'),
            subtitle: Text(game['genres'] ?? 'Жанры не указаны'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(game['playTime'] ?? '-- ч.'),
                _getStatusIcon(game['status']),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getStatusIcon(String? status, {bool small = false}) {
    IconData icon;
    Color color;
    switch (status) {
      case 'Like':
        icon = Icons.thumb_up;
        color = Colors.green;
        break;
      case 'Dislike':
        icon = Icons.thumb_down;
        color = Colors.red;
        break;
      default:
        icon = Icons.sentiment_neutral;
        color = Colors.orange;
    }
    return Icon(icon, color: color, size: small ? 18 : 24);
  }

  // --- ЛОГИКА ДОБАВЛЕНИЯ ---
  void _openAddGameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const AddGameForm(),
    );
  }

  void _openGameDetails(BuildContext context, dynamic gameData, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GameDetailScreen(gameData: gameData, gameIndex: index),
      ),
    );
  }
}

// --- ФОРМА ДОБАВЛЕНИЯ ИГРЫ ---
class AddGameForm extends StatefulWidget {
  const AddGameForm({super.key});

  @override
  State<AddGameForm> createState() => _AddGameFormState();
}

class _AddGameFormState extends State<AddGameForm> {
  final _titleController = TextEditingController();
  final _genresController = TextEditingController();
  final _timeController = TextEditingController();
  String status = 'Neutral';

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
            'Добавить новую игру',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Название игры *'),
          ),
          TextField(
            controller: _genresController,
            decoration: const InputDecoration(labelText: 'Жанры'),
          ),
          TextField(
            controller: _timeController,
            decoration: const InputDecoration(
              labelText: 'Время прохождения (напр. 20ч)',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statusBtn('Like', Icons.thumb_up, Colors.green),
              _statusBtn('Neutral', Icons.sentiment_neutral, Colors.orange),
              _statusBtn('Dislike', Icons.thumb_down, Colors.red),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isEmpty) return;
              final newGame = {
                'title': _titleController.text,
                'genres': _genresController.text,
                'playTime': _timeController.text,
                'status': status,
                'dateTime': DateTime.now().toString(),
                'criteria': [
                  {'name': 'Геймплей', 'score': ''},
                  {'name': 'Сюжет', 'score': ''},
                  {'name': 'Графика', 'score': ''},
                ],
                'notes': <String>[],
                'finalOpinion': '',
              };
              Hive.box(boxName).add(newGame);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statusBtn(String val, IconData icon, Color color) {
    bool active = status == val;
    return IconButton(
      icon: Icon(icon),
      color: active ? color : Colors.grey,
      iconSize: active ? 40 : 30,
      onPressed: () => setState(() => status = val),
    );
  }
}

// --- ЭКРАН ДЕТАЛЕЙ И ОТЗЫВА ---
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

  @override
  void initState() {
    super.initState();
    data = Map<String, dynamic>.from(widget.gameData);
  }

  void _save() {
    Hive.box(boxName).putAt(widget.gameIndex, data);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat(
      'dd.MM.yyyy HH:mm',
    ).format(DateTime.parse(data['dateTime']));

    return Scaffold(
      appBar: AppBar(title: Text(data['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Дата добавления: $dateStr",
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(),

            const Text(
              "Критерии оценки",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...List.generate(data['criteria'].length, (index) {
              final c = data['criteria'][index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        c['name'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Текстовая оценка...',
                          isDense: true,
                        ),
                        onChanged: (val) {
                          data['criteria'][index]['score'] = val;
                          _save();
                        },
                        controller: TextEditingController(text: c['score'])
                          ..selection = TextSelection.collapsed(
                            offset: c['score'].length,
                          ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(
                  () => data['criteria'].add({
                    'name': 'Новый критерий',
                    'score': '',
                  }),
                );
                _save();
              },
              icon: const Icon(Icons.add),
              label: const Text("Добавить свой критерий"),
            ),

            const SizedBox(height: 20),
            const Text(
              "Заметки",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...data['notes']
                .map(
                  (n) => Card(
                    child: ListTile(
                      title: Text(n),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        onPressed: () {
                          setState(() => data['notes'].remove(n));
                          _save();
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Написать заметку...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_noteController.text.isEmpty) return;
                    setState(() {
                      data['notes'].add(_noteController.text);
                      _noteController.clear();
                    });
                    _save();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              "Финальное мнение",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Что ты думаешь об этой игре в итоге?',
              ),
              onChanged: (val) {
                data['finalOpinion'] = val;
                _save();
              },
              controller: TextEditingController(text: data['finalOpinion'])
                ..selection = TextSelection.collapsed(
                  offset: data['finalOpinion'].length,
                ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
