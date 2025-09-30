import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:kelime/screens/new_game_screen.dart';
import 'package:kelime/screens/active_games_screen.dart';
import 'package:kelime/screens/finished_games_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String playerId; // Firebase UID

  const HomeScreen({
    Key? key,
    required this.username,
    required this.playerId,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double successRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final snapshot = await FirebaseDatabase.instance.ref("users/${widget.playerId}").get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      int wins = data['wins'] ?? 0;
      int totalGames = data['totalGames'] ?? 0;

      setState(() {
        successRate = (totalGames > 0) ? (wins / totalGames) * 100 : 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.lightBlue[200],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildUserInfoCard(username: widget.username, successRate: successRate),
            const SizedBox(height: 30),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHomeButton(
                    context,
                    label: 'Yeni Oyun',
                    icon: Icons.play_arrow,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewGameScreen(playerId: widget.playerId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildHomeButton(
                    context,
                    label: 'Aktif Oyunlar',
                    icon: Icons.games,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ActiveGamesScreen(playerId: widget.playerId),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildHomeButton(
                    context,
                    label: 'Biten Oyunlar',
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FinishedGamesScreen(playerId: widget.playerId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard({
    required String username,
    required double successRate,
  }) {
    return Card(
      color: Colors.lightBlue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        leading: const Icon(Icons.account_circle, size: 48, color: Colors.grey),
        title: Text(
          'Kullanıcı: $username',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          'Başarı Yüzdesi: ${successRate.toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHomeButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightBlue[200],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        icon: Icon(icon, size: 28, color: Colors.black87),
        label: Text(
          label,
          style: const TextStyle(fontSize: 20, color: Colors.black87),
        ),
        onPressed: onTap,
      ),
    );
  }
}
