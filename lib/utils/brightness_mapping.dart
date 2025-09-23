import 'dart:math';
import '../models/lux_data.dart';

/// 亮度映射模式枚举
///
/// 定义了不同的光照到亮度的映射方式：
/// - [inverse]: 反向映射，光照越强亮度越低（适合室内环境）
/// - [forward]: 正向映射，光照越强亮度越高（适合户外环境）
enum MappingMode {
  inverse, // 光照越强，亮度越低（适合室内环境）
  forward, // 光照越强，亮度越高（适合户外环境）
}

/// 亮度映射工具类
///
/// 提供将光照值（LUX）转换为屏幕亮度百分比的功能。
/// 支持两种映射模式和基于校准数据的智能调节。
///
/// 主要功能：
/// - 反向映射：环境越亮，屏幕越暗（模拟人眼适应）
/// - 正向映射：环境越亮，屏幕越亮（户外可视性）
/// - 校准数据插值：基于用户手动调节的历史数据
/// - 曲线优化：自动优化校准点，去除噪声
///
/// 使用示例：
/// ```dart
/// // 基本用法（反向映射）
/// int brightness = BrightnessMapping.calculateBrightness(500);
///
/// // 使用校准数据
/// int brightness = BrightnessMapping.calculateBrightness(
///   500,
///   calibrationPoints: calibrationData
/// );
///
/// // 正向映射
/// int brightness = BrightnessMapping.calculateBrightnessForward(500);
///
/// // 选择映射模式
/// int brightness = BrightnessMapping.calculateBrightnessWithMode(
///   500,
///   MappingMode.forward
/// );
/// ```
class BrightnessMapping {
  static const double _defaultMinBrightness = 10.0;
  static const double _defaultMaxBrightness = 100.0;
  static const double _defaultMinLux = 0.0;
  static const double _defaultMaxLux = 10000.0; // 增加到10000，更符合实际光照范围

  static int calculateBrightness(int luxValue,
      {List<CalibrationPoint>? calibrationPoints}) {
    if (calibrationPoints != null && calibrationPoints.isNotEmpty) {
      return _calculateWithCalibration(luxValue, calibrationPoints);
    } else {
      return _calculateDefault(luxValue);
    }
  }

  static int calculateBrightnessForward(int luxValue,
      {List<CalibrationPoint>? calibrationPoints}) {
    if (calibrationPoints != null && calibrationPoints.isNotEmpty) {
      return _calculateWithCalibration(luxValue, calibrationPoints);
    } else {
      return _calculateDefaultForward(luxValue);
    }
  }

  // 通用计算方法，支持选择映射模式
  static int calculateBrightnessWithMode(int luxValue, MappingMode mode,
      {List<CalibrationPoint>? calibrationPoints}) {
    switch (mode) {
      case MappingMode.inverse:
        return calculateBrightness(luxValue,
            calibrationPoints: calibrationPoints);
      case MappingMode.forward:
        return calculateBrightnessForward(luxValue,
            calibrationPoints: calibrationPoints);
    }
  }

  // 获取两种模式的对比结果
  static Map<String, int> getBrightnessComparison(int luxValue,
      {List<CalibrationPoint>? calibrationPoints}) {
    return {
      'inverse': calculateBrightness(luxValue, calibrationPoints: calibrationPoints),
      'forward': calculateBrightnessForward(luxValue, calibrationPoints: calibrationPoints),
    };
  }

  // 获取映射模式的描述
  static String getModeDescription(MappingMode mode) {
    switch (mode) {
      case MappingMode.inverse:
        return '反向模式：光照越强，亮度越低（适合室内环境）';
      case MappingMode.forward:
        return '正向模式：光照越强，亮度越高（适合户外环境）';
    }
  }

  static int _calculateDefault(int luxValue) {
    // 修复：反向映射 - 光照越强，亮度越低
    final normalizedLux =
        (luxValue.toDouble() / _defaultMaxLux).clamp(0.0, 1.0);

    // 使用对数函数使变化更自然
    final logNormalized = log(1 + normalizedLux * 9) / log(10); // log10(1 + 9x)

    // 反向映射：亮度 = 最大亮度 - (归一化光照 * 亮度范围)
    final brightness = _defaultMaxBrightness -
        (logNormalized * (_defaultMaxBrightness - _defaultMinBrightness));

    return brightness.round().clamp(10, 100); // 最小亮度不低于10%
  }

  static int _calculateDefaultForward(int luxValue) {
    // 正向映射 - 光照越强，亮度越高
    final normalizedLux =
        (luxValue.toDouble() / _defaultMaxLux).clamp(0.0, 1.0);

    // 使用对数函数使变化更自然
    final logNormalized = log(1 + normalizedLux * 9) / log(10); // log10(1 + 9x)

    // 正向映射：亮度 = 最小亮度 + (归一化光照 * 亮度范围)
    final brightness = _defaultMinBrightness +
        (logNormalized * (_defaultMaxBrightness - _defaultMinBrightness));

    return brightness.round().clamp(10, 100); // 最小亮度不低于10%
  }

  static int _calculateWithCalibration(
      int luxValue, List<CalibrationPoint> calibrationPoints) {
    if (calibrationPoints.isEmpty) {
      return _calculateDefault(luxValue);
    }

    // 确保校准点按LUX值排序
    calibrationPoints.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    // 如果LUX值小于等于第一个校准点，返回第一个校准点的亮度
    if (luxValue <= calibrationPoints.first.luxValue) {
      return calibrationPoints.first.brightnessValue;
    }

    // 如果LUX值大于等于最后一个校准点，返回最后一个校准点的亮度
    if (luxValue >= calibrationPoints.last.luxValue) {
      return calibrationPoints.last.brightnessValue;
    }

    // 在校准点之间进行线性插值
    for (int i = 0; i < calibrationPoints.length - 1; i++) {
      final p1 = calibrationPoints[i];
      final p2 = calibrationPoints[i + 1];

      if (luxValue >= p1.luxValue && luxValue <= p2.luxValue) {
        // 修复：防止除零错误
        if (p2.luxValue == p1.luxValue) {
          return p1.brightnessValue;
        }

        final ratio = (luxValue - p1.luxValue) / (p2.luxValue - p1.luxValue);
        final brightness = p1.brightnessValue +
            (ratio * (p2.brightnessValue - p1.brightnessValue));
        return brightness.round().clamp(0, 100);
      }
    }

    // 如果没有找到合适的插值区间，使用默认算法
    return _calculateDefault(luxValue);
  }

  static List<CalibrationPoint> optimizeCalibration(
      List<CalibrationPoint> points) {
    if (points.length <= 3) return points;

    points.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    final optimized = <CalibrationPoint>[points.first];

    for (int i = 1; i < points.length - 1; i++) {
      final prev = optimized.last;
      final current = points[i];
      final next = points[i + 1];

      final expectedBrightness = _interpolate(
        prev.luxValue.toDouble(),
        prev.brightnessValue.toDouble(),
        next.luxValue.toDouble(),
        next.brightnessValue.toDouble(),
        current.luxValue.toDouble(),
      );

      final deviation = (current.brightnessValue - expectedBrightness).abs();

      if (deviation > 5.0) {
        optimized.add(current);
      }
    }

    optimized.add(points.last);
    return optimized;
  }

  static List<CalibrationPoint> adaptiveCurveFitting(
      List<CalibrationPoint> points) {
    if (points.length < 3) return points;

    points.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    final segments = _detectSegments(points);
    final fitted = <CalibrationPoint>[];

    for (final segment in segments) {
      fitted.addAll(_fitSegment(segment));
    }

    return fitted;
  }

  static List<List<CalibrationPoint>> _detectSegments(
      List<CalibrationPoint> points) {
    final segments = <List<CalibrationPoint>>[];
    var currentSegment = <CalibrationPoint>[points.first];

    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final prev = points[i - 1];

      final luxDiff = current.luxValue - prev.luxValue;
      final brightnessDiff =
          (current.brightnessValue - prev.brightnessValue).abs();

      if (luxDiff > 100 || brightnessDiff > 20) {
        if (currentSegment.length > 1) {
          segments.add(List.from(currentSegment));
        }
        currentSegment = [prev, current];
      } else {
        currentSegment.add(current);
      }
    }

    if (currentSegment.length > 1) {
      segments.add(currentSegment);
    }

    return segments;
  }

  static List<CalibrationPoint> _fitSegment(List<CalibrationPoint> segment) {
    if (segment.length <= 2) return segment;

    final fitted = <CalibrationPoint>[segment.first];

    for (int i = 1; i < segment.length - 1; i++) {
      final current = segment[i];
      final smoothed = _smoothPoint(segment, i);

      if ((current.brightnessValue - smoothed.brightnessValue).abs() > 3) {
        fitted.add(smoothed);
      } else {
        fitted.add(current);
      }
    }

    fitted.add(segment.last);
    return fitted;
  }

  static CalibrationPoint _smoothPoint(
      List<CalibrationPoint> segment, int index) {
    final current = segment[index];
    final windowSize = min(3, segment.length);
    final start = max(0, index - windowSize ~/ 2);
    final end = min(segment.length, start + windowSize);

    var totalBrightness = 0.0;
    var count = 0;

    for (int i = start; i < end; i++) {
      totalBrightness += segment[i].brightnessValue;
      count++;
    }

    final smoothedBrightness = (totalBrightness / count).round();

    return CalibrationPoint(
      luxValue: current.luxValue,
      brightnessValue: smoothedBrightness,
      timestamp: current.timestamp,
    );
  }

  static double _interpolate(
      double x1, double y1, double x2, double y2, double x) {
    // 修复：防止除零错误
    if ((x2 - x1).abs() < 1e-10) return y1;
    return y1 + (y2 - y1) * (x - x1) / (x2 - x1);
  }

  static Map<String, dynamic> getCalibrationStats(
      List<CalibrationPoint> points) {
    if (points.isEmpty) {
      return {
        'count': 0,
        'luxRange': [0, 0],
        'brightnessRange': [0, 0],
        'coverage': 0.0,
      };
    }

    points.sort((a, b) => a.luxValue.compareTo(b.luxValue));

    final luxValues = points.map((p) => p.luxValue).toList();
    final brightnessValues = points.map((p) => p.brightnessValue).toList();

    final luxRange = [luxValues.first, luxValues.last];
    final brightnessRange = [
      brightnessValues.reduce(min),
      brightnessValues.reduce(max),
    ];

    final coverage = (luxRange[1] - luxRange[0]) / _defaultMaxLux;

    return {
      'count': points.length,
      'luxRange': luxRange,
      'brightnessRange': brightnessRange,
      'coverage': coverage.clamp(0.0, 1.0),
    };
  }
}
