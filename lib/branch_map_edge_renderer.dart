import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart' as graphview;

/// 樹狀邊線（由上而下）：垂直／水平主幹為直線，兩個轉角以小半徑二次貝茲圓角；
/// 其餘方向與 [graphview.TreeEdgeRenderer] 相同之折線。
class SmoothTreeEdgeRenderer extends graphview.EdgeRenderer {
  SmoothTreeEdgeRenderer(this.configuration);

  final graphview.BuchheimWalkerConfiguration configuration;

  final Path _path = Path();

  @override
  void render(Canvas canvas, graphview.Graph graph, Paint paint) {
    final h = configuration.levelSeparation / 2;

    for (final node in graph.nodes) {
      for (final child in graph.successorsOf(node)) {
        final edge = graph.getEdgeBetween(node, child);
        final edgePaint = (edge?.paint ?? paint)..style = PaintingStyle.stroke;
        _path.reset();
        switch (configuration.orientation) {
          case graphview.BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM:
            _topBottom(node, child, h);
            break;
          case graphview.BuchheimWalkerConfiguration.ORIENTATION_BOTTOM_TOP:
            _bottomTopStraight(node, child, h);
            break;
          case graphview.BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT:
            _leftRight(node, child, h);
            break;
          case graphview.BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT:
            _rightLeftStraight(node, child, h);
            break;
        }
        canvas.drawPath(_path, edgePaint);
      }
    }
  }

  void _topBottom(graphview.Node node, graphview.Node child, double levelSeparationHalf) {
    final cx = child.x + child.width / 2;
    final cy = child.y;
    final px = node.x + node.width / 2;
    final py = node.y + node.height;
    final yMid = child.y - levelSeparationHalf;

    if ((px - cx).abs() < 0.5) {
      _path.moveTo(cx, cy);
      _path.lineTo(px, py);
      return;
    }

    final vertSpan = cy - yMid;
    final horizSpan = (px - cx).abs();
    final sign = px > cx ? 1.0 : -1.0;
    final parentGap = yMid - py;

    // 小半徑圓角：避免 cubic 控制點與終點共線造成在 yMid 處水平折返（淚滴／打結）。
    final rMax = math.min(
      12.0,
      math.min(
        horizSpan / 2 - 1.0,
        math.min(vertSpan - 1.5, parentGap - 1.5),
      ),
    );
    if (rMax < 2.0) {
      _path.moveTo(cx, cy);
      _path.lineTo(cx, yMid);
      _path.lineTo(px, yMid);
      _path.lineTo(px, py);
      return;
    }
    final r = rMax.clamp(2.0, 12.0);

    final yChildCorner = yMid + r;
    final yParentCorner = yMid - r;

    _path.moveTo(cx, cy);
    _path.lineTo(cx, yChildCorner);
    _path.quadraticBezierTo(cx, yMid, cx + sign * r, yMid);
    _path.lineTo(px - sign * r, yMid);
    _path.quadraticBezierTo(px, yMid, px, yParentCorner);
    _path.lineTo(px, py);
  }

  /// 左→右橫向圓角：與 [_topBottom] 相同邏輯旋轉 90°。
  /// [xMid] 為子節點左側與父節點右側之間的垂直分隔線，兩個轉角同樣以二次貝茲圓角處理。
  void _leftRight(graphview.Node node, graphview.Node child, double levelSeparationHalf) {
    final cx = child.x;                     // child 左側
    final cy = child.y + child.height / 2;  // child 中心 y
    final px = node.x + node.width;         // parent 右側
    final py = node.y + node.height / 2;    // parent 中心 y
    final xMid = child.x - levelSeparationHalf; // 垂直分隔線

    if ((py - cy).abs() < 0.5) {
      _path.moveTo(cx, cy);
      _path.lineTo(px, py);
      return;
    }

    final sign = py > cy ? 1.0 : -1.0;
    final vertSpan = (py - cy).abs();
    final horizChild = cx - xMid;          // child 左側 → 分隔線
    final horizParent = xMid - px;         // 分隔線 → parent 右側

    final rMax = math.min(
      12.0,
      math.min(
        vertSpan / 2 - 1.0,
        math.min(horizChild - 1.5, horizParent - 1.5),
      ),
    );
    if (rMax < 2.0) {
      _path.moveTo(cx, cy);
      _path.lineTo(xMid, cy);
      _path.lineTo(xMid, py);
      _path.lineTo(px, py);
      return;
    }
    final r = rMax.clamp(2.0, 12.0);

    _path.moveTo(cx, cy);
    _path.lineTo(xMid + r, cy);
    _path.quadraticBezierTo(xMid, cy, xMid, cy + sign * r);
    _path.lineTo(xMid, py - sign * r);
    _path.quadraticBezierTo(xMid, py, xMid + r, py);
    _path.lineTo(px, py);
  }

  /// 與 [graphview.TreeEdgeRenderer] 相同（本 app 目前僅使用由上而下）。
  void _bottomTopStraight(
    graphview.Node node,
    graphview.Node child,
    double levelSeparationHalf,
  ) {
    _path.moveTo(child.x + child.width / 2, child.y + child.height);
    _path.lineTo(
      child.x + child.width / 2,
      child.y + child.height + levelSeparationHalf,
    );
    _path.lineTo(
      node.x + node.width / 2,
      child.y + child.height + levelSeparationHalf,
    );
    _path.moveTo(
      node.x + node.width / 2,
      child.y + child.height + levelSeparationHalf,
    );
    _path.lineTo(node.x + node.width / 2, node.y + node.height);
  }

  void _rightLeftStraight(
    graphview.Node node,
    graphview.Node child,
    double levelSeparationHalf,
  ) {
    _path.moveTo(child.x + child.width, child.y + child.height / 2);
    _path.lineTo(
      child.x + child.width + levelSeparationHalf,
      child.y + child.height / 2,
    );
    _path.lineTo(
      child.x + child.width + levelSeparationHalf,
      node.y + node.height / 2,
    );
    _path.moveTo(
      child.x + child.width + levelSeparationHalf,
      node.y + node.height / 2,
    );
    _path.lineTo(node.x + node.width, node.y + node.height / 2);
  }
}
