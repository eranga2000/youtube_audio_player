import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Audio Player',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const YouTubeAudioPlayer(),
    );
  }
}

class YouTubeAudioPlayer extends StatefulWidget {
  const YouTubeAudioPlayer({super.key});

  @override
  State<YouTubeAudioPlayer> createState() => _YouTubeAudioPlayerState();
}

class _YouTubeAudioPlayerState extends State<YouTubeAudioPlayer> {
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controller = TextEditingController();

  String? _audioUrl;
  String? _thumbnailUrl;
  String? _videoTitle;
  bool _isLoading = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
      });
    });
    _audioPlayer.durationStream.listen((duration) {
      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });
  }

  Future<void> _fetchAndPlayAudio(String url) async {
    setState(() {
      _isLoading = true;
      _audioUrl = null;
      _thumbnailUrl = null;
      _videoTitle = null;
    });

    try {
      final videoId = Uri.parse(url).pathSegments.last;
      final video = await _youtubeExplode.videos.get(videoId);
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();

      // Use fallback logic for thumbnail URLs
      final thumbnailUrl = video.thumbnails.maxResUrl ??
          video.thumbnails.highResUrl ??
          video.thumbnails.mediumResUrl ??
          video.thumbnails.lowResUrl;

      setState(() {
        _audioUrl = audioStream.url.toString();
        _thumbnailUrl = thumbnailUrl.toString();
        _videoTitle = video.title;
      });

      // Play audio
      await _audioPlayer.setUrl(_audioUrl!);
      _audioPlayer.play();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    setState(() {});
  }

  Future<void> _replayAudio() async {
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.play();
    setState(() {});
  }

  @override
  void dispose() {
    _youtubeExplode.close();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Audio Player'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter YouTube Video URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _fetchAndPlayAudio(_controller.text.trim()),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Fetch and Play Audio'),
            ),
            const SizedBox(height: 16),
            if (_thumbnailUrl != null)
              Column(
                children: [
                  Image.network(
                    _thumbnailUrl!,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'Failed to load thumbnail',
                        style: TextStyle(color: Colors.red),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _videoTitle ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_audioUrl != null)
              Column(
                children: [
                  ProgressBar(
                    progress: _position,
                    total: _duration,
                    onSeek: (duration) async {
                      await _audioPlayer.seek(duration);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _replayAudio,
                        icon: const Icon(Icons.replay_10),
                        iconSize: 32,
                      ),
                      IconButton(
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                        ),
                        iconSize: 32,
                      ),
                      IconButton(
                        onPressed: () => _audioPlayer.seek(
                          _audioPlayer.position + const Duration(seconds: 10),
                        ),
                        icon: const Icon(Icons.forward_10),
                        iconSize: 32,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
