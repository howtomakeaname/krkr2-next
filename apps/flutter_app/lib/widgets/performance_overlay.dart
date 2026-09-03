import 'dart:collection';

import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// A semi-transparent overlay that displays the current graphics API
/// (e.g. Metal, OpenGL ES) and a real-time FPS counter.
///
/// Place this in a [Stack] above the game surface.
class EnginePerformanceOverlay extends StatefulWidget {
  const EnginePerformanceOverlay({
    super.key,
    required this.rendererInfo,
    required this.engineName,
    required this.pacingMode,
    this.hidden = false,
  });

  /// The renderer info string from engine_get_renderer_info.
  final String rendererInfo;
  final String engineName;
  final String pacingMode;
  final bool hidden;

  @override
  State<EnginePerformanceOverlay> createState() =>
      EnginePerformanceOverlayState();
}

class EnginePerformanceOverlayState extends State<EnginePerformanceOverlay> {
  final Queue<double> _frameDurations = Queue<double>();
  static const int _sampleWindow = 60;
  double _fps = 0.0;
  double _averageFrameMs = 0.0;
  double _p95FrameMs = 0.0;
  DateTime _lastUpdate = DateTime.now();

  /// Call this from the tick loop with the delta time in milliseconds.
  void reportFrameDelta(double deltaMs) {
    _frameDurations.addLast(deltaMs);
    while (_frameDurations.length > _sampleWindow) {
      _frameDurations.removeFirst();
    }

    // Update displayed FPS at most once per 500ms to avoid jitter.
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds >= 500 &&
        _frameDurations.isNotEmpty) {
      final avgDelta =
          _frameDurations.reduce((a, b) => a + b) / _frameDurations.length;
      final sorted = _frameDurations.toList()..sort();
      final p95Index = ((sorted.length - 1) * 0.95).round();
      _lastUpdate = now;
      if (mounted) {
        setState(() {
          _fps = avgDelta > 0 ? 1000.0 / avgDelta : 0.0;
          _averageFrameMs = avgDelta;
          _p95FrameMs = sorted[p95Index];
        });
      }
    }
  }

  String _parseGraphicsApi(String rendererInfo) {
    if (rendererInfo.isEmpty) return 'Unknown';

    final lower = rendererInfo.toLowerCase();
    // ANGLE backend detection from GL_RENDERER string
    if (lower.contains('metal')) return 'Metal';
    if (lower.contains('vulkan')) return 'Vulkan';
    if (lower.contains('d3d11') || lower.contains('direct3d 11')) {
      return 'D3D11';
    }
    if (lower.contains('d3d9') || lower.contains('direct3d 9')) return 'D3D9';
    if (lower.contains('opengl es')) return 'OpenGL ES';
    if (lower.contains('opengl')) return 'OpenGL';

    // Fallback: return the first part before '|' if available
    final parts = rendererInfo.split('|');
    return parts.first.trim();
  }

  String _formatNumber(double value, {String suffix = ''}) {
    if (value <= 0) return '--';
    return '${value.toStringAsFixed(1)}$suffix';
  }

  String _shortGraphicsApi(String api) {
    if (api == 'OpenGL ES') return 'GLES';
    if (api == 'OpenGL') return 'GL';
    return api;
  }

  String _shortPacingMode(String mode) {
    if (mode == 'DisplaySync') return 'DSYNC';
    if (mode == 'VSync') return 'VSYNC';
    if (mode.startsWith('Cap ')) {
      return mode.replaceFirst('Cap ', 'CAP ').replaceFirst(' FPS', '');
    }
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    final graphicsApi = _parseGraphicsApi(widget.rendererInfo);
    final fpsText = _formatNumber(_fps);
    final averageFrameText = _formatNumber(_averageFrameMs, suffix: ' ms');
    final p95FrameText = _formatNumber(_p95FrameMs, suffix: ' ms');
    final engineText =
        '${widget.engineName} / ${_shortGraphicsApi(graphicsApi)}';
    final pacingText = _shortPacingMode(widget.pacingMode);

    return Positioned(
      left: UiSpacing.md,
      top: MediaQuery.paddingOf(context).top + UiSpacing.sm,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: widget.hidden ? 0 : 1,
          duration: UiDuration.fast,
          curve: UiCurves.iosSmooth,
          child: RepaintBoundary(
            child: Semantics(
              label:
                  '$fpsText FPS, $averageFrameText average frame time, '
                  '$p95FrameText 95th percentile frame time, '
                  '${widget.engineName}, $graphicsApi, ${widget.pacingMode}',
              child: Container(
                width: 148,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xD91C1C1E),
                  borderRadius: UiRadius.brSm,
                  border: Border.all(
                    color: const Color(0x24FFFFFF),
                    width: 0.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          fpsText,
                          style: const TextStyle(
                            color: Color(0xFFF2F2F7),
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                            height: 1.15,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const Text(' fps', style: _secondaryStyle),
                        const Spacer(),
                        Text(averageFrameText, style: _valueStyle),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text('p95 $p95FrameText', style: _secondaryStyle),
                        const Spacer(),
                        Text(pacingText, style: _detailStyle),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      engineText,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: _detailStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _secondaryStyle = TextStyle(
  color: Color(0xFF8E8E93),
  fontSize: 8.5,
  fontFamily: 'monospace',
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: 0.1,
  height: 1.25,
  decoration: TextDecoration.none,
);

const _valueStyle = TextStyle(
  color: Color(0xFFD1D1D6),
  fontSize: 9,
  fontFamily: 'monospace',
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
  height: 1.2,
  decoration: TextDecoration.none,
);

const _detailStyle = TextStyle(
  color: Color(0xFF8E8E93),
  fontSize: 8,
  fontFamily: 'monospace',
  fontWeight: FontWeight.w500,
  letterSpacing: 0.05,
  height: 1.25,
  decoration: TextDecoration.none,
);
