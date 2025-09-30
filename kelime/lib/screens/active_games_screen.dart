import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:kelime/screens/game_board_screen.dart';

class ActiveGamesScreen extends StatefulWidget {
  final String playerId; // Firebase UID

  const ActiveGamesScreen({Key? key, required this.playerId}) : super(key: key);

  @override
  State<ActiveGamesScreen> createState() => _ActiveGamesScreenState();
}

class _ActiveGamesScreenState extends State<ActiveGamesScreen> {
  List<Map> activeGames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActiveGames();
  }

  Future<void> fetchActiveGames() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("games").get();

      List<Map> games = [];

      if (snapshot.exists) {
        final data = snapshot.value as Map;

        data.forEach((key, value) {
          final game = Map<String, dynamic>.from(value);
          game['id'] = key;

          final isActive = game['status'] == 'active';
          final isPlayer = game['player1'] == widget.playerId || game['player2'] == widget.playerId;

          if (isActive && isPlayer) {
            games.add(game);
          }
        });
      }

      setState(() {
        activeGames = games;
        isLoading = false;
      });
    } catch (e) {
      print("Firebase'den veri alınamadı: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: const Text('Aktif Oyunlar', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.lightBlue[200],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeGames.isEmpty
          ? Center(
        child: Text(
          'Şu anda aktif bir oyununuz bulunmamaktadır.\nYeni bir oyun başlatabilirsiniz! 🎮',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey[700]),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activeGames.length,
        itemBuilder: (context, index) {
          final game = activeGames[index];
          final String gameId = game['id'];
          final int duration = game['duration'];
          final String rakip = game['player1'] == widget.playerId
              ? (game['player2Name'] ?? 'Henüz yok')
              : (game['player1Name'] ?? 'Henüz yok');

          return Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.sports_esports, color: Colors.blueAccent, size: 32),
              title: Text(
                'Rakip: $rakip',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Süre: ${_durationToText(duration)}'),
                  const SizedBox(height: 2),
                  Text('Durum: ${game['status']}'),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameBoardScreen(
                      gameId: gameId,
                      playerId: widget.playerId,
                      duration: duration,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _durationToText(int durationType) {
    switch (durationType) {
      case 2:
        return '2 Dakika';
      case 5:
        return '5 Dakika';
      case 720:
        return '12 Saat';
      case 1440:
        return '24 Saat';
      default:
        return 'Bilinmeyen';
    }
  }
}
