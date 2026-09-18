import 'dart:convert';
import 'package:http/http.dart' as http;

class AnikuPlayAnime {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String status;

  AnikuPlayAnime({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.status,
  });

  factory AnikuPlayAnime.fromJson(Map<String, dynamic> json) {
    return AnikuPlayAnime(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      status: json['status'] as String? ?? 'Ongoing',
    );
  }
}

class AnikuPlayEpisode {
  final int id;
  final int animeId;
  final int episodeNumber;
  final String title;
  final String videoUrl;

  AnikuPlayEpisode({
    required this.id,
    required this.animeId,
    required this.episodeNumber,
    required this.title,
    required this.videoUrl,
  });

  factory AnikuPlayEpisode.fromJson(Map<String, dynamic> json) {
    return AnikuPlayEpisode(
      id: json['id'] as int,
      animeId: json['anime_id'] as int,
      episodeNumber: json['episode_number'] as int,
      title: json['title'] as String? ?? 'Episode ${json['episode_number']}',
      videoUrl: json['video_url'] as String? ?? '',
    );
  }
}

class AnikuPlayApiService {
  final String baseUrl;

  AnikuPlayApiService({
    this.baseUrl = 'https://anikuplay-api.workers.dev',
  });

  Future<List<AnikuPlayAnime>> getAnimes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/animes'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          return list.map((item) => AnikuPlayAnime.fromJson(item)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<AnikuPlayAnime?> getAnimeDetail(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/animes/$id'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return AnikuPlayAnime.fromJson(data['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<AnikuPlayEpisode>> getEpisodes(int animeId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/episodes/$animeId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final list = data['data'] as List;
          return list.map((item) => AnikuPlayEpisode.fromJson(item)).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
