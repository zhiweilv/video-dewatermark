import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/statistics.dart';
import 'package:gal/gal.dart';
import '../models/watermark_region.dart';

/// 水印去除服务，基于 FFmpeg delogo 滤镜
class WatermarkRemover {
  /// 去除水印
  /// [inputPath] 输入视频路径
  /// [regions] 要去除的水印区域列表
  /// [onProgress] 进度回调 (0.0 ~ 1.0)
  /// 返回输出视频路径
  Future<String> remove({
    required String inputPath,
    required List<WatermarkRegion> regions,
    required double totalDuration,
    void Function(double progress)? onProgress,
  }) async {
    if (regions.isEmpty) throw Exception('未指定水印区域');

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/dewatermark_$timestamp.mp4';

    // 构建 delogo 滤镜链，支持多个水印区域
    final filters = regions
        .map((r) => r.toDelogoFilter())
        .join(',');

    final cmd = '-i "$inputPath" '
        '-vf "$filters" '
        '-c:a copy '
        '-y "$outputPath"';

    // 注册进度回调
    if (onProgress != null && totalDuration > 0) {
      FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
        final time = stats.getTime() / 1000.0; // ms → s
        final progress = (time / totalDuration).clamp(0.0, 1.0);
        onProgress(progress);
      });
    }

    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();

    if (!ReturnCode.isSuccess(code)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('去水印失败: $logs');
    }

    return outputPath;
  }

  /// 保存处理后的视频到相册（兼容 Android 10+ 分区存储）
  /// 返回临时文件路径（gal 插件会自动写入 MediaStore）
  Future<String> saveToGallery(String tempPath) async {
    await Gal.putVideo(tempPath, album: '视频去水印');
    return tempPath;
  }
}
