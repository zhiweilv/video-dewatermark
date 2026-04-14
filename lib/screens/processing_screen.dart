import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_region.dart';
import '../services/video_service.dart';
import '../services/watermark_remover.dart';

/// 处理进度页 - 显示去水印进度和结果
class ProcessingScreen extends StatefulWidget {
  final File videoFile;
  final Rect region;          // 屏幕坐标的选区
  final ui.Size videoSize;    // 视频实际尺寸
  final ui.Size displaySize;  // 视频在屏幕上的显示尺寸（用于坐标映射）

  const ProcessingScreen({
    super.key,
    required this.videoFile,
    required this.region,
    required this.videoSize,
    required this.displaySize,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _remover = WatermarkRemover();
  final _videoService = VideoService();

  double _progress = 0.0;
  String _status = '准备中...';
  String? _outputPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    try {
      setState(() => _status = '正在获取视频信息...');
      final duration = await _videoService.getDuration(
        widget.videoFile.path,
      ) ?? 0.0;

      // 将屏幕坐标映射到视频实际像素坐标
      final region = WatermarkRegion.fromScreenCoords(
        screenRect: widget.region,
        displaySize: widget.displaySize,
        videoSize: widget.videoSize,
      );

      setState(() => _status = '正在去除水印...');
      final outputPath = await _remover.remove(
        inputPath: widget.videoFile.path,
        regions: [region],
        totalDuration: duration,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      setState(() => _status = '正在保存到相册...');
      final savedPath = await _remover.saveToGallery(outputPath);

      if (mounted) {
        setState(() {
          _outputPath = savedPath;
          _status = '完成';
          _progress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _status = '处理失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('处理中')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _error != null ? _buildError() : _buildProgress(),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final isDone = _outputPath != null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isDone)
          const Icon(Icons.check_circle, size: 80, color: Colors.green)
        else
          SizedBox(
            width: 80, height: 80,
            child: CircularProgressIndicator(
              value: _progress > 0 ? _progress : null,
              strokeWidth: 6,
            ),
          ),
        const SizedBox(height: 24),
        Text(
          _status,
          style: const TextStyle(fontSize: 18),
        ),
        if (!isDone) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(1)}%'),
        ],
        if (isDone) ...[
          const SizedBox(height: 8),
          Text(
            '已保存到: $_outputPath',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('返回首页'),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 80, color: Colors.red),
        const SizedBox(height: 24),
        const Text('处理失败', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          _error!,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回重试'),
        ),
      ],
    );
  }
}
