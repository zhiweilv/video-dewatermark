import 'dart:collection';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import '../models/watermark_region.dart';

/// 水印自动检测服务
/// 原理：抽取多帧 → 计算帧间像素方差 → 方差极低区域为静止区域（可能是水印）
class WatermarkDetector {
  /// 检测视频中的静态水印区域
  Future<List<WatermarkRegion>> detect(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final framesDir = Directory('${tempDir.path}/wm_frames');
    if (await framesDir.exists()) {
      await framesDir.delete(recursive: true);
    }
    await framesDir.create();

    // 1. 抽取 8 帧均匀分布的画面
    await _extractFrames(videoPath, framesDir.path, 8);

    // 2. 加载帧图片
    final frames = await _loadFrames(framesDir.path);
    if (frames.length < 3) return [];

    // 3. 计算帧间方差图
    final varianceMap = _computeVarianceMap(frames);

    // 4. 从方差图中找低方差区域作为候选水印
    final regions = _findLowVarianceRegions(
      varianceMap,
      frames.first.width,
      frames.first.height,
    );

    // 清理临时文件
    await framesDir.delete(recursive: true);
    return regions;
  }

  /// 用 FFmpeg 从视频中均匀抽取指定数量的帧
  Future<void> _extractFrames(
    String videoPath, String outputDir, int count,
  ) async {
    // 使用 fps 滤镜均匀抽帧，select 每隔 N 帧取一帧
    final cmd = '-i "$videoPath" '
        '-vf "select=not(mod(n\\,30)),scale=320:-1" '
        '-frames:v $count '
        '-vsync vfr '
        '"$outputDir/frame_%03d.png"';
    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      throw Exception('抽帧失败');
    }
  }

  /// 加载目录下所有帧图片
  Future<List<img.Image>> _loadFrames(String dir) async {
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final images = <img.Image>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final decoded = img.decodePng(bytes);
      if (decoded != null) images.add(decoded);
    }
    return images;
  }

  /// 计算多帧之间每个像素的方差图
  /// 返回二维数组，值越小表示该像素越"静止"
  List<List<double>> _computeVarianceMap(List<img.Image> frames) {
    final h = frames.first.height;
    final w = frames.first.width;
    final n = frames.length;

    // 初始化均值和方差数组
    final mean = List.generate(h, (_) => List.filled(w, 0.0));
    final variance = List.generate(h, (_) => List.filled(w, 0.0));

    // 计算每个像素的灰度均值
    for (final frame in frames) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = frame.getPixel(x, y);
          final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          mean[y][x] += gray / n;
        }
      }
    }

    // 计算方差
    for (final frame in frames) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = frame.getPixel(x, y);
          final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          final diff = gray - mean[y][x];
          variance[y][x] += (diff * diff) / n;
        }
      }
    }

    return variance;
  }

  /// 从方差图中找到低方差的矩形区域（候选水印）
  List<WatermarkRegion> _findLowVarianceRegions(
    List<List<double>> variance, int imgW, int imgH,
  ) {
    // 计算方差阈值（取整体方差中位数的 10%）
    final allValues = <double>[];
    for (final row in variance) {
      allValues.addAll(row);
    }
    allValues.sort();
    final median = allValues[allValues.length ~/ 2];
    final threshold = median * 0.1;

    // 生成二值图：低方差区域标记为 true
    final mask = List.generate(
      imgH,
      (y) => List.generate(imgW, (x) => variance[y][x] < threshold),
    );

    // 用连通区域分析找矩形
    final visited = List.generate(
      imgH, (_) => List.filled(imgW, false),
    );
    final regions = <WatermarkRegion>[];

    for (int y = 0; y < imgH; y++) {
      for (int x = 0; x < imgW; x++) {
        if (mask[y][x] && !visited[y][x]) {
          // BFS 找连通区域的边界
          int minX = x, maxX = x, minY = y, maxY = y;
          int count = 0;
          final queue = Queue<List<int>>()..add([y, x]);
          visited[y][x] = true;

          while (queue.isNotEmpty) {
            final p = queue.removeFirst();
            final py = p[0], px = p[1];
            count++;
            if (px < minX) minX = px;
            if (px > maxX) maxX = px;
            if (py < minY) minY = py;
            if (py > maxY) maxY = py;

            for (final d in [[-1,0],[1,0],[0,-1],[0,1]]) {
              final ny = py + d[0], nx = px + d[1];
              if (ny >= 0 && ny < imgH && nx >= 0 && nx < imgW
                  && mask[ny][nx] && !visited[ny][nx]) {
                visited[ny][nx] = true;
                queue.add([ny, nx]);
              }
            }
          }

          // 过滤：面积太小或太大的区域不是水印
          final area = (maxX - minX) * (maxY - minY);
          final totalArea = imgW * imgH;
          if (area < totalArea * 0.001 || area > totalArea * 0.15) continue;
          // 过滤：填充率太低的不是水印（太稀疏）
          final fillRate = count / area;
          if (fillRate < 0.3) continue;

          regions.add(WatermarkRegion(
            x: minX.toDouble(),
            y: minY.toDouble(),
            width: (maxX - minX).toDouble(),
            height: (maxY - minY).toDouble(),
            confidence: fillRate,
          ));
        }
      }
    }

    // 按置信度排序，返回前 3 个候选
    regions.sort((a, b) => b.confidence.compareTo(a.confidence));
    return regions.take(3).toList();
  }
}
