import 'package:flutter/material.dart';
import '../services/anikuplay_api_service.dart';
import 'player_screen.dart';

class DetailScreen extends StatefulWidget {
  final AnikuPlayAnime anime;
  final AnikuPlayApiService apiService;

  const DetailScreen({
    super.key,
    required this.anime,
    required this.apiService,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<List<AnikuPlayEpisode>> _episodesFuture;

  @override
  void initState() {
    super.initState();
    _episodesFuture = widget.apiService.getEpisodes(widget.anime.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anime.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.anime.coverUrl.isNotEmpty)
              Image.network(
                widget.anime.coverUrl,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, size: 60),
                ),
              )
            else
              Container(
                height: 240,
                color: Colors.grey[800],
                child: const Icon(Icons.movie, size: 60),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.anime.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      widget.anime.status,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: widget.anime.status == 'Completed'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sinopsis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.anime.description.isNotEmpty
                        ? widget.anime.description
                        : 'Tidak ada deskripsi sinopsis.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Daftar Episode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<AnikuPlayEpisode>>(
                    future: _episodesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'Belum ada episode yang tersedia.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final episodes = snapshot.data!;
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: episodes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ep = episodes[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${ep.episodeNumber}'),
                            ),
                            title: Text(ep.title),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    title: '${widget.anime.title} - ${ep.title}',
                                    videoUrl: ep.videoUrl,
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
}
