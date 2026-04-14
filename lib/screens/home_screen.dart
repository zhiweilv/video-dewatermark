import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/video_service.dart';
import 'editor_screen.dart';

/// 首页 - 选择视频
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _videoService = VideoService();
  bool _loading = false;

  Future<void> _pickVideo() async {
    // 请求存储权限
    final status = await Permission.videos.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能选择视频')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final file = await _videoService.pickVideo();
      if (file != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorScreen(videoFile: file),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频去水印'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              '选择一个视频开始去水印',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _loading
                ? const CircularProgressIndicator()
                : FilledButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('选择视频'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
