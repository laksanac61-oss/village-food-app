import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';

/// A video file the shop picked, already checked against the size and length limits.
typedef PickedVideo = ({Uint8List bytes, String ext, String contentType});

const _types = {'mp4': 'video/mp4', 'm4v': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm'};

/// Lets the shop pick a video from the phone. Returns null if they cancel;
/// throws [FormatException] with a Thai message when the file is too big, too long or unreadable.
Future<PickedVideo?> pickVideo() async {
  final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (x == null) return null;
  final name = x.name.toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : 'mp4';
  final contentType = _types[ext] ?? x.mimeType ?? 'video/mp4';
  if (!_types.values.contains(contentType)) {
    throw const FormatException('รองรับเฉพาะไฟล์วิดีโอ .mp4 .mov หรือ .webm');
  }
  final size = await x.length();
  if (size > Api.maxVideoBytes) {
    throw FormatException(
      'ไฟล์ใหญ่ ${(size / 1024 / 1024).toStringAsFixed(0)} MB เกินกำหนด 50 MB '
      'ลองตัดคลิปให้สั้นลง หรือตั้งกล้องเป็น 720p',
    );
  }
  final seconds = await _durationSeconds(x);
  if (seconds == null) {
    throw const FormatException('เปิดไฟล์วิดีโอนี้ไม่ได้ ลองใช้ไฟล์ .mp4');
  }
  if (seconds > Api.maxVideoSeconds + 1) {
    throw FormatException('วิดีโอยาว $seconds วินาที เกินกำหนด ${Api.maxVideoSeconds} วินาที');
  }
  return (bytes: await x.readAsBytes(), ext: ext == 'm4v' ? 'mp4' : ext, contentType: contentType);
}

/// Reads the length by opening the file in a player; null if the phone or browser cannot play it.
Future<int?> _durationSeconds(XFile x) async {
  // On the web the picked file is a blob: URL the browser can stream from.
  final c = kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse(x.path))
      : VideoPlayerController.file(File(x.path));
  try {
    await c.initialize().timeout(const Duration(seconds: 20));
    return c.value.duration.inSeconds;
  } catch (_) {
    return null;
  } finally {
    await c.dispose();
  }
}

/// Plays a video full screen; tap the picture to pause or play.
Future<void> showVideo(BuildContext context, String url, {String? title}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _VideoScreen(url: url, title: title),
  ),
);

class _VideoScreen extends StatefulWidget {
  const _VideoScreen({required this.url, this.title});
  final String url;
  final String? title;

  @override
  State<_VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<_VideoScreen> {
  late final _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _c.initialize().then((_) => _c.play()).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  Future<void> _toggle() async {
    final v = _c.value;
    if (v.isPlaying) return _c.pause();
    if (v.position >= v.duration) await _c.seekTo(Duration.zero); // play again from the start
    await _c.play();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'วิดีโอแนะนำร้าน'),
      ),
      body: SafeArea(
        child: _failed
            ? const Center(
                child: Text('เปิดวิดีโอไม่ได้ ลองใหม่อีกครั้ง', style: TextStyle(color: Colors.white)),
              )
            : !v.isInitialized
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggle,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_c)),
                          ),
                          if (!v.isPlaying)
                            const Icon(Icons.play_circle_fill, size: 80, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  VideoProgressIndicator(
                    _c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: Icon(v.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _toggle,
                      ),
                      Text(
                        '${_time(v.position)} / ${_time(v.duration)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        color: Colors.white,
                        icon: Icon(v.volume == 0 ? Icons.volume_off : Icons.volume_up),
                        onPressed: () => _c.setVolume(v.volume == 0 ? 1 : 0),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  static String _time(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

/// "Watch the shop's video" button for customers and the admin.
class WatchVideoButton extends StatelessWidget {
  const WatchVideoButton({super.key, required this.url, this.title});
  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    icon: const Icon(Icons.play_circle),
    label: const Text('ดูวิดีโอแนะนำร้าน'),
    onPressed: () => showVideo(context, url, title: title),
  );
}
