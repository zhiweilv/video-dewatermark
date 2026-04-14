import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/media_information.dart';

/// 视频选择与信息获取服务
class VideoService {
  final ImagePicker _picker = ImagePicker();

  /// 从相册选择视频
  Future<File?> pickVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (file == null) return null;
    return File(file.path);
  }

  /// 获取视频尺寸信息
  Future<Size?> getVideoSize(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return null;

    final streams = info.getStreams();
    for (final stream in streams) {
      final w = stream.getWidth();
      final h = stream.getHeight();
      if (w != null && h != null) {
        return Size(w.toDouble(), h.toDouble());
      }
    }
    return null;
  }

  /// 获取视频时长（秒）
  Future<double?> getDuration(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return null;
    final duration = info.getDuration();
    if (duration == null) return null;
    return double.tryParse(duration);
  }
}
