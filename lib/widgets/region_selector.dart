import 'package:flutter/material.dart';

/// 水印区域框选组件
/// 支持拖拽移动和四角缩放
class RegionSelector extends StatefulWidget {
  final Size containerSize;
  final Rect? initialRegion;
  final ValueChanged<Rect> onRegionChanged;

  const RegionSelector({
    super.key,
    required this.containerSize,
    required this.onRegionChanged,
    this.initialRegion,
  });

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  late Rect _region;
  _DragMode _dragMode = _DragMode.none;
  Offset _dragStart = Offset.zero;
  Rect _regionAtDragStart = Rect.zero;

  static const double _handleSize = 24.0;
  static const double _minSize = 30.0;

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion ??
        Rect.fromCenter(
          center: Offset(
            widget.containerSize.width / 2,
            widget.containerSize.height / 2,
          ),
          width: 120,
          height: 60,
        );
  }

  @override
  void didUpdateWidget(RegionSelector old) {
    super.didUpdateWidget(old);
    if (widget.initialRegion != null && old.initialRegion == null) {
      setState(() => _region = widget.initialRegion!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => _dragMode = _DragMode.none,
      child: CustomPaint(
        size: widget.containerSize,
        painter: _RegionPainter(region: _region, handleSize: _handleSize),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    final pos = details.localPosition;
    _dragStart = pos;
    _regionAtDragStart = _region;

    // 判断触摸位置：四角手柄 or 区域内部
    final hs = _handleSize;
    if (_nearCorner(pos, _region.topLeft, hs)) {
      _dragMode = _DragMode.topLeft;
    } else if (_nearCorner(pos, _region.topRight, hs)) {
      _dragMode = _DragMode.topRight;
    } else if (_nearCorner(pos, _region.bottomLeft, hs)) {
      _dragMode = _DragMode.bottomLeft;
    } else if (_nearCorner(pos, _region.bottomRight, hs)) {
      _dragMode = _DragMode.bottomRight;
    } else if (_region.contains(pos)) {
      _dragMode = _DragMode.move;
    } else {
      _dragMode = _DragMode.none;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragMode == _DragMode.none) return;
    final delta = details.localPosition - _dragStart;
    final r = _regionAtDragStart;
    final maxW = widget.containerSize.width;
    final maxH = widget.containerSize.height;

    Rect newRegion;
    switch (_dragMode) {
      case _DragMode.move:
        var dx = delta.dx;
        var dy = delta.dy;
        if (r.left + dx < 0) dx = -r.left;
        if (r.top + dy < 0) dy = -r.top;
        if (r.right + dx > maxW) dx = maxW - r.right;
        if (r.bottom + dy > maxH) dy = maxH - r.bottom;
        newRegion = r.shift(Offset(dx, dy));
        break;
      case _DragMode.topLeft:
        newRegion = Rect.fromLTRB(
          (r.left + delta.dx).clamp(0, r.right - _minSize),
          (r.top + delta.dy).clamp(0, r.bottom - _minSize),
          r.right, r.bottom,
        );
        break;
      case _DragMode.topRight:
        newRegion = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(0, r.bottom - _minSize),
          (r.right + delta.dx).clamp(r.left + _minSize, maxW),
          r.bottom,
        );
        break;
      case _DragMode.bottomLeft:
        newRegion = Rect.fromLTRB(
          (r.left + delta.dx).clamp(0, r.right - _minSize),
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + _minSize, maxH),
        );
        break;
      case _DragMode.bottomRight:
        newRegion = Rect.fromLTRB(
          r.left, r.top,
          (r.right + delta.dx).clamp(r.left + _minSize, maxW),
          (r.bottom + delta.dy).clamp(r.top + _minSize, maxH),
        );
        break;
      default:
        return;
    }

    setState(() => _region = newRegion);
    widget.onRegionChanged(newRegion);
  }

  bool _nearCorner(Offset pos, Offset corner, double threshold) {
    return (pos - corner).distance < threshold;
  }
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

/// 绘制选区框和四角手柄
class _RegionPainter extends CustomPainter {
  final Rect region;
  final double handleSize;

  _RegionPainter({required this.region, required this.handleSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 半透明遮罩（选区外部变暗）
    final maskPaint = Paint()..color = Colors.black.withOpacity(0.4);
    // 上
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, region.top), maskPaint,
    );
    // 下
    canvas.drawRect(
      Rect.fromLTRB(0, region.bottom, size.width, size.height), maskPaint,
    );
    // 左
    canvas.drawRect(
      Rect.fromLTRB(0, region.top, region.left, region.bottom), maskPaint,
    );
    // 右
    canvas.drawRect(
      Rect.fromLTRB(region.right, region.top, size.width, region.bottom),
      maskPaint,
    );

    // 选区边框
    final borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(region, borderPaint);

    // 四角手柄
    final handlePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    final hs = handleSize / 2;
    for (final corner in [
      region.topLeft, region.topRight,
      region.bottomLeft, region.bottomRight,
    ]) {
      canvas.drawCircle(corner, hs, handlePaint);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter old) => old.region != region;
}

