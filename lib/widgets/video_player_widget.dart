import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频预览组件，返回视频显示区域的实际尺寸
class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  final Widget Function(Size displaySize)? overlayBuilder;

  const VideoPlayerWidget({
    super.key,
    required this.videoFile,
    this.overlayBuilder,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(builder: (context, constraints) {
      final videoRatio = _controller.value.aspectRatio;
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      final containerRatio = maxW / maxH;

      double displayW, displayH;
      if (videoRatio > containerRatio) {
        displayW = maxW;
        displayH = maxW / videoRatio;
      } else {
        displayH = maxH;
        displayW = maxH * videoRatio;
      }

      final displaySize = Size(displayW, displayH);

      return Center(
        child: SizedBox(
          width: displayW,
          height: displayH,
          child: Stack(
            children: [
              VideoPlayer(_controller),
              if (widget.overlayBuilder != null)
                widget.overlayBuilder!(displaySize),
            ],
          ),
        ),
      );
    });
  }
}
