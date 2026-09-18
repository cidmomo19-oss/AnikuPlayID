import 'package:flutter_test/flutter_test.dart';
import 'package:anikuplay/services/anikuplay_api_service.dart';

void main() {
  test('AnikuPlayAnime model deserialization test', () {
    final json = {
      'id': 1,
      'title': 'Test Anime',
      'description': 'Test Description',
      'cover_url': 'https://example.com/cover.jpg',
      'status': 'Ongoing',
    };

    final anime = AnikuPlayAnime.fromJson(json);
    expect(anime.id, 1);
    expect(anime.title, 'Test Anime');
    expect(anime.description, 'Test Description');
    expect(anime.coverUrl, 'https://example.com/cover.jpg');
    expect(anime.status, 'Ongoing');
  });

  test('AnikuPlayEpisode model deserialization test', () {
    final json = {
      'id': 10,
      'anime_id': 1,
      'episode_number': 1,
      'title': 'Episode 1',
      'video_url': 'https://example.com/video.mp4',
    };

    final ep = AnikuPlayEpisode.fromJson(json);
    expect(ep.id, 10);
    expect(ep.animeId, 1);
    expect(ep.episodeNumber, 1);
    expect(ep.title, 'Episode 1');
    expect(ep.videoUrl, 'https://example.com/video.mp4');
  });
}
