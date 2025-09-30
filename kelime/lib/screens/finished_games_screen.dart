import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FinishedGamesScreen extends StatefulWidget {
  final String playerId;

  const FinishedGamesScreen({super.key, required this.playerId});

  @override
  State<FinishedGamesScreen> createState() => _FinishedGamesScreenState();
}

class _FinishedGamesScreenState extends State<FinishedGamesScreen> {
  List<Map<String, dynamic>> finishedGames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFinishedGames();
  }

  Future<void> fetchFinishedGames() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref("games").get();

      List<Map<String, dynamic>> games = [];

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        data.forEach((key, value) {
          final game = Map<String, dynamic>.from(value);
          game['id'] = key;

          final isFinished = game['status'] == 'finished';
          final isPlayer = game['player1'] == widget.playerId || game['player2'] == widget.playerId;

          if (isFinished && isPlayer) {
            games.add(game);
          }
        });
      }

      setState(() {
        finishedGames = games;
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
      appBar: AppBar(
        title: const Text('Biten Oyunlar', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.lightBlue[200],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : finishedGames.isEmpty
          ? const Center(
        child: Text(
          'Henüz biten oyun bulunmamaktadır. Çok yakında burası dolacak! ✨',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: finishedGames.length,
        itemBuilder: (context, index) {
          final game = finishedGames[index];
          final winner = game['winnerName'] ?? 'Belirtilmedi';
          final createdAt = game['createdAt'] ?? 'Bilinmiyor';
          final durationText = _durationToText(game['duration']);

          return Card(
            color: Colors.lightBlue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
              title: Text(
                'Kazanan: $winner',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              subtitle: Text(
                'Süre: $durationText\nTarih: $createdAt',
                style: const TextStyle(color: Colors.grey),
              ),
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
        return 'Bilinmiyor';
    }
  }
}
