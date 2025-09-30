import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:math';

class GameBoardScreen extends StatefulWidget {
  final String playerId;
  final String gameId;
  final int duration;

  const GameBoardScreen({
    Key? key,
    required this.playerId,
    required this.gameId,
    required this.duration,
  }) : super(key: key);

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class WordPlacement {
  final String word;
  final List<Point<int>> positions;

  WordPlacement(this.word, this.positions);
}


class _GameBoardScreenState extends State<GameBoardScreen> {
  List<List<String>> board = List.generate(15, (_) => List.generate(15, (_) => ''));
  List<List<String>> bonusMap = List.generate(15, (_) => List.generate(15, (_) => ''));
  List<List<String>> trapMap = List.generate(15, (_) => List.generate(15, (_) => ''));
  List<String> myLetters = [];
  List<Point<int>> placedThisTurn = [];
  String? selectedLetter;
  late int remainingSeconds;
  Timer? timer;
  bool isMyTurn = false;
  int myScore = 0;
  int opponentScore = 0;
  String? opponentId;
  bool isWaitingForOpponent = true;
  Set<String> turkishWords = {};
  final List<String> letterBag = [];

  final Map<String, int> letterPoints = {
    'A': 1, 'B': 3, 'C': 4, 'Ç': 4, 'D': 3, 'E': 1, 'F': 7, 'G': 5, 'Ğ': 8,
    'H': 5, 'I': 2, 'İ': 1, 'J': 10, 'K': 1, 'L': 1, 'M': 4, 'N': 1, 'O': 2,
    'Ö': 7, 'P': 5, 'R': 1, 'S': 2, 'Ş': 4, 'T': 1, 'U': 2, 'Ü': 3, 'V': 7,
    'Y': 3, 'Z': 4, '*': 0
  };

  final Map<String, int> fullLetterPool = {
    'A': 12, 'B': 2, 'C': 2, 'Ç': 2, 'D': 3, 'E': 8, 'F': 1, 'G': 1, 'Ğ': 1,
    'H': 1, 'I': 4, 'İ': 7, 'J': 1, 'K': 7, 'L': 7, 'M': 4, 'N': 5, 'O': 3,
    'Ö': 1, 'P': 1, 'R': 6, 'S': 3, 'Ş': 2, 'T': 5, 'U': 3, 'Ü': 2, 'V': 1,
    'Y': 3, 'Z': 2, '*': 2
  };

  @override
  void initState() {
    super.initState();
    initBonusMap();
    initTrapMap();
    initializeLetterBag();
    myLetters = drawLetters(7);
    loadWords();
    startTimer();
    listenToGame();
  }

  Future<void> loadWords() async {
    try {
      final content = await rootBundle.loadString('lib/assets/turkce_kelime_listesi.txt');
      turkishWords = content.split('\n').map((e) => e.trim().toLowerCase()).toSet();
      debugPrint('✅ ${turkishWords.length} kelime yüklendi');
    } catch (e) {
      debugPrint('❌ Kelime listesi yüklenemedi: $e');
    }
  }


  void initBonusMap() {
    bonusMap[7][7] = '★';
    for (var pos in [
      [2, 0], [0, 2], [2, 14], [0, 12],
      [12, 0], [14, 2], [14, 12], [12, 14]
    ]) {
      bonusMap[pos[0]][pos[1]] = 'K3';
    }
    for (var pos in [
      [0, 5], [0, 9], [1, 6], [1, 8], [5, 0], [9, 0],
      [6, 1], [8, 1], [5, 14], [9, 14], [6, 13], [8, 13],
      [5, 5], [6, 6], [8, 6], [9, 5], [5, 9], [6, 8], [8, 8], [9, 9],
      [13, 6], [13, 8], [14, 5], [14, 9]
    ]) {
      bonusMap[pos[0]][pos[1]] = 'H2';
    }
    for (var pos in [
      [1, 1], [13, 1], [1, 13], [13, 13],
      [4, 4], [4, 10], [10, 4], [10, 10]
    ]) {
      bonusMap[pos[0]][pos[1]] = 'H3';
    }
    for (var pos in [
      [2, 7], [3, 3], [7, 2], [11, 3],
      [11, 11], [3, 11], [7, 12], [12, 7]
    ]) {
      bonusMap[pos[0]][pos[1]] = 'K2';
    }
  }

  void initTrapMap() {
    final random = Random();
    final traps = ['HAMLE_ENGELI', 'PUAN_BOL', 'HARF_KAYBI'];
    for (int i = 0; i < 10; i++) {
      int x = random.nextInt(15);
      int y = random.nextInt(15);
      if (bonusMap[x][y] == '') trapMap[x][y] = traps[random.nextInt(traps.length)];
    }
  }

  void initializeLetterBag() {
    fullLetterPool.forEach((letter, count) {
      for (int i = 0; i < count; i++) {
        letterBag.add(letter);
      }
    });
    letterBag.shuffle();
  }

  List<String> drawLetters(int count) {
    List<String> drawn = [];
    for (int i = 0; i < count && letterBag.isNotEmpty; i++) {
      drawn.add(letterBag.removeLast());
    }
    return drawn;
  }

  void startTimer() {
    remainingSeconds = widget.duration * 60;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer?.cancel();
      }
    });
  }

  void listenToGame() {
    final gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
    gameRef.onValue.listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final player1Id = data['player1']?['id'];
      final player2Id = data['player2']?['id'];
      final boardData = List<List>.from(data['board'] ?? []);

      setState(() {
        board = boardData.map((row) => row.map((e) => e.toString()).toList()).toList();
        isMyTurn = data['turn'] == widget.playerId;
        myLetters = List<String>.from(data['letters']?[widget.playerId] ?? []);
        opponentId = widget.playerId == player1Id ? player2Id : player1Id;
        myScore = data['scores']?[widget.playerId] ?? 0;
        opponentScore = data['scores']?[opponentId] ?? 0;
        isWaitingForOpponent = opponentId == null || opponentId!.isEmpty;
      });
    });
  }

  void placeLetter(int x, int y) {
    if (!isMyTurn || selectedLetter == null || board[x][y].isNotEmpty) return;
    setState(() {
      board[x][y] = selectedLetter!;
      placedThisTurn.add(Point(x, y));
      myLetters.remove(selectedLetter);
      selectedLetter = null;
    });
  }

// Yeni kontrol kurallarini entegre eden guncellenmis submitMove fonksiyonu
  Future<void> submitMove() async {
    if (!isMyTurn || placedThisTurn.isEmpty) return;

    // Harfler sira halinde mi yerlestirilmis kontrol et
    if (!isStraightOrDiagonal(placedThisTurn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harfler sira halinde olmalidir (yatay, dikey veya capraz)!')),
      );
      return;
    }

    // Tahtada ilk kelime yaziliyor mu?
    bool isBoardEmpty = board.expand((e) => e).where((cell) => cell.isNotEmpty).length == placedThisTurn.length;

    if (isBoardEmpty) {
      if (!placedThisTurn.contains(const Point(7, 7))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ilk kelime ortadaki ★ yildiza temas etmeli!')),
        );
        return;
      }
    } else {
      // En az bir harf mevcut harflerle temas etmeli
      if (!isTouchingExistingLetters(placedThisTurn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni kelime tahtadaki mevcut harflerle temas etmeli!')),
        );
        return;
      }
    }

    // Tum yeni turetilen kelimeleri bul ve dogrula
    List<WordPlacement> newWords = extractWords(placedThisTurn);

    for (var wp in newWords) {
      final normalized = wp.word.toLowerCase().replaceAll('İ', 'i').replaceAll('I', 'ı');
      if (!turkishWords.contains(normalized)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gecersiz kelime: ${wp.word}')),
        );
        return;
      }
    }



    // Puan hesapla (simdilik sadece bir kelime icin hesapliyoruz)
    int totalScore = 0;
    for (var wp in newWords) {
      int wordScore = 0;
      int wordMultiplier = 1;

      for (var point in wp.positions) {
        String letter = board[point.x][point.y];
        int base = letterPoints[letter] ?? 0;
        String bonus = bonusMap[point.x][point.y];

        if (placedThisTurn.contains(point)) {
          if (bonus == 'H2') base *= 2;
          if (bonus == 'H3') base *= 3;
          if (bonus == 'K2') wordMultiplier *= 2;
          if (bonus == 'K3') wordMultiplier *= 3;
        }

        wordScore += base;
      }

      totalScore += wordScore * wordMultiplier;
    }


    myScore += totalScore;

    await FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'board': board,
      'letters/${widget.playerId}': [...myLetters, ...drawLetters(7 - myLetters.length)],
      'scores/${widget.playerId}': myScore,
      'turn': opponentId
    });




    setState(() => placedThisTurn.clear());
  }


  void removeLetter(int row, int col) {
    final letter = board[row][col];
    if (letter.isNotEmpty && placedThisTurn.contains(Point(row, col))) {
      setState(() {
        board[row][col] = '';
        myLetters.add(letter);
        placedThisTurn.remove(Point(row, col));
      });
    }
  }


  bool isStraightOrDiagonal(List<Point<int>> points) {
    if (points.length <= 1) return true;
    points.sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    int dx = points[1].x - points[0].x;
    int dy = points[1].y - points[0].y;
    for (int i = 1; i < points.length; i++) {
      int cx = points[i].x - points[i - 1].x;
      int cy = points[i].y - points[i - 1].y;
      if (dx == 0 && cy != 1) return false;
      if (dy == 0 && cx != 1) return false;
      if (dx != 0 && dy != 0 && (cx != dx || cy != dy)) return false;
    }
    return true;
  }

  bool isTouchingExistingLetters(List<Point<int>> placed) {
    for (var p in placed) {
      for (var dir in [Point(0, 1), Point(1, 0), Point(0, -1), Point(-1, 0)]) {
        int nx = p.x + dir.x;
        int ny = p.y + dir.y;
        if (nx >= 0 && nx < 15 && ny >= 0 && ny < 15) {
          if (board[nx][ny].isNotEmpty && !placed.contains(Point(nx, ny))) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<WordPlacement> extractWords(List<Point<int>> placed) {
    Set<Point<int>> visited = {};
    List<WordPlacement> foundWords = [];

    for (var p in placed) {
      // Yatay kelime
      List<Point<int>> hPoints = [];
      int y = p.y;
      while (y >= 0 && board[p.x][y].isNotEmpty) y--;
      y++;
      String hWord = '';
      while (y < 15 && board[p.x][y].isNotEmpty) {
        hWord += board[p.x][y];
        hPoints.add(Point(p.x, y));
        y++;
      }
      if (hWord.length > 1 && hPoints.any((pt) => placed.contains(pt)) && !visited.containsAll(hPoints)) {
        foundWords.add(WordPlacement(hWord, List.from(hPoints)));
        visited.addAll(hPoints);
      }

      // Dikey kelime
      List<Point<int>> vPoints = [];
      int x = p.x;
      while (x >= 0 && board[x][p.y].isNotEmpty) x--;
      x++;
      String vWord = '';
      while (x < 15 && board[x][p.y].isNotEmpty) {
        vWord += board[x][p.y];
        vPoints.add(Point(x, p.y));
        x++;
      }
      if (vWord.length > 1 && vPoints.any((pt) => placed.contains(pt)) && !visited.containsAll(vPoints)) {
        foundWords.add(WordPlacement(vWord, List.from(vPoints)));
        visited.addAll(vPoints);
      }
    }

    return foundWords;
  }



  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget buildBoardCell(int row, int col) {
    final String letter = board[row][col];
    final String bonus = bonusMap[row][col];
    Color? bg;
    String text = letter;
    String? scoreText;

    if (letter.isNotEmpty) {
      bg = Colors.yellow[100];
      scoreText = letterPoints[letter]?.toString();
    } else if (bonus.isNotEmpty) {
      switch (bonus) {
        case 'H2': bg = Colors.cyan[100]; text = 'H²'; break;
        case 'H3': bg = Colors.purple[100]; text = 'H³'; break;
        case 'K2': bg = Colors.green[100]; text = 'K²'; break;
        case 'K3': bg = Colors.brown[200]; text = 'K³'; break;
        case '★': bg = Colors.orange[200]; text = '★'; break;
      }
    } else {
      bg = Colors.grey[200];
    }

    return GestureDetector(
      onTap: () {
        if (placedThisTurn.contains(Point(row, col))) {
          removeLetter(row, col);
        } else {
          placeLetter(row, col);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: Colors.grey.shade400, width: 0.4),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            if (scoreText != null)
              Positioned(
                right: 2,
                top: 2,
                child: Text(
                  scoreText,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isWaitingForOpponent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rakip Bekleniyor')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Mayınları')),
      body: Column(
        children: [
          Text('Sen: $myScore | Rakip: $opponentScore'),
          Text('Süre: $remainingSeconds sn'),
          Expanded(
            child: GridView.builder(
              itemCount: 225,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 15),
              itemBuilder: (context, index) {
                int row = index ~/ 15;
                int col = index % 15;
                return buildBoardCell(row, col);
              },
            ),
          ),
          Wrap(
            children: myLetters.map((l) => GestureDetector(
              onTap: () => setState(() => selectedLetter = l),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selectedLetter == l ? Colors.green : Colors.yellow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
                child: Text('$l (${letterPoints[l]})'),
              ),
            )).toList(),
          ),
          ElevatedButton(
            onPressed: submitMove,
            child: const Text('Kelimeyi Gönder'),
          )
        ],
      ),
    );
  }
}
