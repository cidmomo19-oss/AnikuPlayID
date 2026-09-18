import 'package:flutter/material.dart';
import '../services/anikuplay_api_service.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AnikuPlayApiService apiService;

  const HomeScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<AnikuPlayAnime>> _animesFuture;

  @override
  void initState() {
    super.initState();
    _refreshAnimes();
  }

  void _refreshAnimes() {
    setState(() {
      _animesFuture = widget.apiService.getAnimes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnikuPlay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnimes,
            tooltip: 'Perbarui Data',
          ),
        ],
      ),
      body: FutureBuilder<List<AnikuPlayAnime>>(
        future: _animesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Gagal memuat anime atau belum ada data.'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshAnimes,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final animes = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshAnimes(),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: animes.length,
              itemBuilder: (context, index) {
                final anime = animes[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(
                          anime: anime,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: anime.coverUrl.isNotEmpty
                              ? Image.network(
                                  anime.coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, size: 40),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.movie, size: 40),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                anime.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                anime.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: anime.status == 'Completed'
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
