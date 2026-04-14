import 'dart:ui';

/// 水印区域数据模型
class WatermarkRegion {
  double x;
  double y;
  double width;
  double height;
  double confidence;

  WatermarkRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.confidence = 0.0,
  });

  /// 转换为 FFmpeg delogo 滤镜参数
  String toDelogoFilter() {
    return 'delogo=x=${x.round()}:y=${y.round()}'
        ':w=${width.round()}:h=${height.round()}:show=0';
  }

  /// 从屏幕坐标映射到视频实际像素坐标
  factory WatermarkRegion.fromScreenCoords({
    required Rect screenRect,
    required Size displaySize,
    required Size videoSize,
  }) {
    final scaleX = videoSize.width / displaySize.width;
    final scaleY = videoSize.height / displaySize.height;
    return WatermarkRegion(
      x: screenRect.left * scaleX,
      y: screenRect.top * scaleY,
      width: screenRect.width * scaleX,
      height: screenRect.height * scaleY,
    );
  }

  /// 转换为屏幕坐标用于显示
  Rect toScreenRect(Size displaySize, Size videoSize) {
    final scaleX = displaySize.width / videoSize.width;
    final scaleY = displaySize.height / videoSize.height;
    return Rect.fromLTWH(
      x * scaleX,
      y * scaleY,
      width * scaleX,
      height * scaleY,
    );
  }
}
