import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:kelime/screens/game_board_screen.dart'; // Proje adını güncelledik

class NewGameScreen extends StatefulWidget {
  final String playerId;

  const NewGameScreen({Key? key, required this.playerId}) : super(key: key);

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  bool isLoading = false;

  final List<String> letterBag = [];

  final Map<String, int> fullLetterPool = {
    'A': 12, 'B': 2, 'C': 2, 'Ç': 2, 'D': 3, 'E': 8, 'F': 1, 'G': 1, 'Ğ': 1,
    'H': 1, 'I': 4, 'İ': 7, 'J': 1, 'K': 7, 'L': 7, 'M': 4, 'N': 5, 'O': 3,
    'Ö': 1, 'P': 1, 'R': 6, 'S': 3, 'Ş': 2, 'T': 5, 'U': 3, 'Ü': 2, 'V': 1,
    'Y': 3, 'Z': 2, '*': 2
  };

  void initializeLetterBag() {
    letterBag.clear();
    fullLetterPool.forEach((letter, count) {
      for (int i = 0; i < count; i++) {
        letterBag.add(letter);
      }
    });
    letterBag.shuffle();
  }

  List<String> drawLetters(int count) {
    if (letterBag.isEmpty) {
      initializeLetterBag();
    }

    List<String> drawn = [];
    for (int i = 0; i < count && letterBag.isNotEmpty; i++) {
      drawn.add(letterBag.removeLast());
    }
    return drawn;
  }


  Future<void> findOrCreateGame(int duration) async {
    setState(() => isLoading = true);
    final DatabaseReference gamesRef = FirebaseDatabase.instance.ref().child('games');

    try {
      final snapshot = await gamesRef
          .orderByChild('durationType')
          .equalTo(duration)
          .once();

      bool matched = false;

      if (snapshot.snapshot.exists) {
        final Map<dynamic, dynamic> allGames = snapshot.snapshot.value as Map;

        for (var entry in allGames.entries) {
          final key = entry.key;
          final game = entry.value;

          if (game['player2'] == null) {
            final playerIdStr = widget.playerId.toString();

            // ⚠️ Harf çek ve ekle
            final letters = drawLetters(7);

            await gamesRef.child(key).update({
              'player2': {
                'id': playerIdStr,
                'username': 'Player$playerIdStr',
              },
              'status': 'active',
              'letters/$playerIdStr': letters,
              'scores/$playerIdStr': 0,
            });

            matched = true;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GameBoardScreen(
                  gameId: key,
                  playerId: widget.playerId.toString(),
                  duration: duration,
                ),
              ),
            );
            break;
          }
        }
      }

      if (!matched) {
        final playerIdStr = widget.playerId.toString();
        final newGameRef = gamesRef.push();

        await newGameRef.set({
          'player1': {
            'id': playerIdStr,
            'username': 'Player$playerIdStr',
          },
          'player2': null,
          'durationType': duration,
          'status': 'waiting',
          'createdAt': DateTime.now().toIso8601String(),
          'board': List.generate(15, (_) => List.generate(15, (_) => '')),
          'letters': {
            playerIdStr: drawLetters(7),
          },
          'scores': {
            playerIdStr: 0,
          },
          'turn': playerIdStr,
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameBoardScreen(
              gameId: newGameRef.key!,
              playerId: playerIdStr,
              duration: duration,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Eşleştirme hatası: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }



  Widget buildButton(String label, int duration) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlue[200],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        onPressed: isLoading ? null : () => findOrCreateGame(duration),
        child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Oyun', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.lightBlue[200],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Oyun Süresini Seç',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 32),
            buildButton('Hızlı Oyun - 2 Dakika', 2),
            const SizedBox(height: 16),
            buildButton('Hızlı Oyun - 5 Dakika', 5),
            const SizedBox(height: 16),
            buildButton('Genişletilmiş Oyun - 12 Saat', 720),
            const SizedBox(height: 16),
            buildButton('Genişletilmiş Oyun - 24 Saat', 1440),
          ],
        ),
      ),
    );
  }
}
