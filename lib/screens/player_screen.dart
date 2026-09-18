import 'package:flutter/material.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: widget.videoUrl.isNotEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_fill,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Memutar dari URL:\n${widget.videoUrl}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              )
            : const Text(
                'URL video tidak valid atau kosong.',
                style: TextStyle(color: Colors.white),
              ),
      ),
    );
  }
}
