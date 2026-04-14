import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/watermark_region.dart';
import '../services/video_service.dart';
import '../services/watermark_detector.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/region_selector.dart';
import 'processing_screen.dart';

/// 编辑页 - 预览视频 + 框选水印区域
class EditorScreen extends StatefulWidget {
  final File videoFile;

  const EditorScreen({super.key, required this.videoFile});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _videoService = VideoService();
  final _detector = WatermarkDetector();

  ui.Size? _videoSize;
  ui.Size? _displaySize; // 视频在屏幕上的实际显示尺寸
  bool _detecting = false;
  Rect? _selectedRegion;
  List<WatermarkRegion>? _detectedRegions;

  @override
  void initState() {
    super.initState();
    _loadVideoInfo();
  }

  Future<void> _loadVideoInfo() async {
    final size = await _videoService.getVideoSize(widget.videoFile.path);
    if (mounted) setState(() => _videoSize = size);
  }

  Future<void> _autoDetect() async {
    setState(() => _detecting = true);
    try {
      final regions = await _detector.detect(widget.videoFile.path);
      if (mounted) {
        setState(() {
          _detectedRegions = regions;
          _detecting = false;
        });
        if (regions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未检测到水印，请手动框选')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _detecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检测失败: $e')),
        );
      }
    }
  }

  void _startProcessing() {
    if (_selectedRegion == null || _videoSize == null || _displaySize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先框选水印区域')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          videoFile: widget.videoFile,
          region: _selectedRegion!,
          videoSize: _videoSize!,
          displaySize: _displaySize!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('框选水印区域'),
        actions: [
          if (_detecting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _autoDetect,
              child: const Text('自动检测'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: VideoPlayerWidget(
              videoFile: widget.videoFile,
              overlayBuilder: (displaySize) {
                // 保存 displaySize 供坐标转换使用
                _displaySize = displaySize;
                // 如果有检测结果且用户还没手动调整，用第一个检测结果初始化
                Rect? initial;
                if (_detectedRegions != null &&
                    _detectedRegions!.isNotEmpty &&
                    _selectedRegion == null &&
                    _videoSize != null) {
                  final r = _detectedRegions!.first;
                  initial = r.toScreenRect(displaySize, _videoSize!);
                }
                return RegionSelector(
                  containerSize: displaySize,
                  initialRegion: initial,
                  onRegionChanged: (rect) {
                    _selectedRegion = rect;
                  },
                );
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_detectedRegions != null && _detectedRegions!.length > 1)
              Text(
                '检测到 ${_detectedRegions!.length} 个候选区域，'
                '已选择置信度最高的',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 8),
            const Text(
              '拖拽移动选区，拖拽四角调整大小',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startProcessing,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('开始去除水印'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
