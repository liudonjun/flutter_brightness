import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/serial_service.dart';
import '../services/brightness_service.dart';
import '../services/database_service.dart';
import '../services/autostart_service.dart';
import '../models/lux_data.dart';
import '../utils/brightness_mapping.dart';

/// 亮度控制主屏幕
///
/// 这是应用的主界面，提供以下功能：
/// - 串口连接和数据接收
/// - 自动亮度调节（基于光照传感器）
/// - 手动亮度控制
/// - 校准数据管理
/// - 开机自启动设置
/// - 自动连接上次使用的串口
///
/// 工作流程：
/// 1. 连接光照传感器（通过串口）
/// 2. 接收LUX光照数据
/// 3. 根据校准数据计算目标亮度
/// 4. 自动调整系统亮度
/// 5. 用户可随时手动调节（会自动添加校准点）
class BrightnessControlScreen extends StatefulWidget {
  const BrightnessControlScreen({super.key});

  @override
  State<BrightnessControlScreen> createState() =>
      _BrightnessControlScreenState();
}

/// BrightnessControlScreen的状态管理类
///
/// 管理以下状态：
/// - 串口连接状态和数据处理
/// - 亮度控制和校准数据
/// - 用户设置（自启动、自动连接等）
/// - UI状态和日志管理
class _BrightnessControlScreenState extends State<BrightnessControlScreen> {
  static const String _lastPortKey = 'last_connected_port';
  static const String _autoConnectKey = 'auto_connect_enabled';

  final SerialService _serialService = SerialService();
  final WindowsBrightnessService _brightnessService =
      WindowsBrightnessService();

  StreamSubscription<String>? _serialSubscription;

  String? _selectedPort;
  bool _isConnected = false;
  bool _autoStartEnabled = false;
  bool _autoConnectEnabled = true;

  int _currentLux = 0;
  int _currentBrightness = 50;
  int _manualBrightness = 50;

  Timer? _brightnessDebounceTimer;
  bool _isProcessingData = false;

  final List<String> _logs = [];
  final List<CalibrationPoint> _calibrationPoints = [];

  @override
  void initState() {
    super.initState();
    _addLog('亮度控制应用已启动');
    _updateCurrentBrightness();
    _loadCalibrationData();
    _checkAutoStartStatus();
    _loadLastPortAndAutoConnect();
  }

  void _loadCalibrationData() async {
    try {
      final points = await DatabaseService.getAllCalibrationPoints();
      setState(() {
        _calibrationPoints.clear();
        _calibrationPoints.addAll(points);
      });
      _addLog('从数据库加载了 ${points.length} 个校准点');
    } catch (e) {
      _addLog('加载校准数据失败: $e');
    }
  }

  void _checkAutoStartStatus() {
    setState(() {
      _autoStartEnabled = AutoStartService.isAutoStartEnabled();
    });
    _addLog('自启动状态: ${_autoStartEnabled ? "已启用" : "已禁用"}');
  }

  void _toggleAutoStart() {
    final success = AutoStartService.toggleAutoStart();
    if (success) {
      setState(() {
        _autoStartEnabled = AutoStartService.isAutoStartEnabled();
      });
      _addLog('自启动已${_autoStartEnabled ? "启用" : "禁用"}');
    } else {
      _addLog('切换自启动状态失败');
    }
  }

  Future<void> _saveLastConnectedPort(String port) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPortKey, port);
      _addLog('已保存上次连接的端口: $port');
    } catch (e) {
      _addLog('保存端口失败: $e');
    }
  }

  Future<void> _saveAutoConnectSetting(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoConnectKey, enabled);
    } catch (e) {
      _addLog('保存自动连接设置失败: $e');
    }
  }

  Future<void> _loadLastPortAndAutoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPort = prefs.getString(_lastPortKey);
      final autoConnect = prefs.getBool(_autoConnectKey) ?? true;

      setState(() {
        _autoConnectEnabled = autoConnect;
        if (lastPort != null &&
            SerialService.getAvailablePorts().contains(lastPort)) {
          _selectedPort = lastPort;
        }
      });

      _addLog('自动连接设置: ${_autoConnectEnabled ? "启用" : "禁用"}');

      if (_autoConnectEnabled && _selectedPort != null) {
        _addLog('发现上次连接的端口: $_selectedPort，正在自动连接...');
        // 延迟一点再连接，确保UI已初始化
        Timer(const Duration(milliseconds: 500), () {
          _connectToPort();
        });
      } else if (_selectedPort == null && lastPort != null) {
        _addLog('上次连接的端口 $lastPort 不再可用');
      }
    } catch (e) {
      _addLog('加载连接设置失败: $e');
    }
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    _brightnessDebounceTimer?.cancel();
    _serialService.dispose();
    super.dispose();
  }

  void _updateCurrentBrightness() {
    final brightness = _brightnessService.getCurrentBrightness();
    if (brightness >= 0) {
      setState(() {
        _currentBrightness = brightness;
        _manualBrightness = brightness;
      });
    }
  }

  void _connectToPort() {
    if (_selectedPort == null) return;

    if (_serialService.connect(_selectedPort!)) {
      setState(() {
        _isConnected = true;
      });

      _serialSubscription = _serialService.dataStream.listen(
        (data) {
          _processSerialData(data);
        },
        onError: (error) {
          _addLog('串口错误: $error');
          setState(() {
            _isConnected = false;
          });
        },
      );

      _addLog('已连接到 $_selectedPort');
      _saveLastConnectedPort(_selectedPort!);
    } else {
      _addLog('连接 $_selectedPort 失败');
    }
  }

  void _disconnect() {
    _serialSubscription?.cancel();
    _serialService.disconnect();
    setState(() {
      _isConnected = false;
    });
    _addLog('已断开串口连接');
  }

  void _processSerialData(String data) {
    _addLog('原始数据: $data');

    try {
      // 尝试解析 LUX:xxx 格式
      final luxData = LuxData.fromSerial(data);
      setState(() {
        _currentLux = luxData.luxValue;
      });

      _addLog('解析结果: LUX:${luxData.luxValue}');

      // 计算目标亮度并自动设置
      final targetBrightness = BrightnessMapping.calculateBrightnessForward(
        luxData.luxValue,
        calibrationPoints: _calibrationPoints,
      );

      _addLog(
          '计算目标亮度: LUX:${luxData.luxValue} -> $targetBrightness% (校准点:${_calibrationPoints.length}个)');

      if (_brightnessService.setBrightness(targetBrightness)) {
        setState(() {
          _currentBrightness = targetBrightness;
          _manualBrightness = targetBrightness; // 同步更新手动滑条位置
        });
        _addLog('✓ 自动亮度已设置为: $targetBrightness%');
      } else {
        _addLog('✗ 设置亮度失败: $targetBrightness%');
      }
    } catch (e) {
      // 尝试解析纯数字格式
      final numMatch = RegExp(r'(\d+)').firstMatch(data.trim());
      if (numMatch != null) {
        try {
          final luxValue = int.parse(numMatch.group(1)!);
          setState(() {
            _currentLux = luxValue;
          });

          _addLog('解析数字: $luxValue');

          // 计算目标亮度并自动设置
          final targetBrightness = BrightnessMapping.calculateBrightnessForward(
            luxValue,
            calibrationPoints: _calibrationPoints,
          );

          _addLog(
              '计算目标亮度: LUX:$luxValue -> $targetBrightness% (校准点:${_calibrationPoints.length}个)');

          if (_brightnessService.setBrightness(targetBrightness)) {
            setState(() {
              _currentBrightness = targetBrightness;
              _manualBrightness = targetBrightness; // 同步更新手动滑条位置
            });
            _addLog('✓ 自动亮度已设置为: $targetBrightness%');
          } else {
            _addLog('✗ 设置亮度失败: $targetBrightness%');
          }
        } catch (parseError) {
          _addLog('解析数据失败，数据: $data');
        }
      } else {
        _addLog('数据格式无效: $data (期望格式: LUX:xxx 或数字)');
      }
    }
  }

  void _setManualBrightness(double value) {
    final brightness = value.round();
    setState(() {
      _manualBrightness = brightness;
    });

    _brightnessDebounceTimer?.cancel();
    _brightnessDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_brightnessService.setBrightness(brightness)) {
        setState(() {
          _currentBrightness = brightness;
        });
        _addLog('手动亮度已设置为: $brightness%');

        // 如果有当前光照值，自动添加校准点
        if (_currentLux > 0) {
          _addCalibrationPointAuto(_currentLux, brightness);
          _addLog('手动调节触发校准点添加: LUX:$_currentLux -> $brightness%');
        } else {
          _addLog('无法添加校准点：当前LUX值为0，请先连接光照传感器');
        }
      }
    });
  }

  void _addCalibrationPointAuto(int luxValue, int brightnessValue) async {
    final point = CalibrationPoint(
      luxValue: luxValue,
      brightnessValue: brightnessValue,
      timestamp: DateTime.now(),
    );

    try {
      await DatabaseService.deleteCalibrationPoint(luxValue);
      await DatabaseService.insertCalibrationPoint(point);

      setState(() {
        _calibrationPoints
            .removeWhere((p) => (p.luxValue - luxValue).abs() < 10);
        _calibrationPoints.add(point);
      });

      _addLog('自动校准: LUX:$luxValue -> $brightnessValue%');
    } catch (e) {
      _addLog('保存校准点失败: $e');
    }
  }

  void _clearCalibration() async {
    try {
      await DatabaseService.clearAllCalibrationPoints();
      setState(() {
        _calibrationPoints.clear();
      });
      _addLog('校准数据已清除');
    } catch (e) {
      _addLog('清除校准数据失败: $e');
    }
  }

  void _optimizeCalibration() async {
    if (_calibrationPoints.length > 3) {
      try {
        final optimized =
            BrightnessMapping.adaptiveCurveFitting(_calibrationPoints);

        await DatabaseService.clearAllCalibrationPoints();
        await DatabaseService.insertCalibrationPoints(optimized);

        setState(() {
          _calibrationPoints.clear();
          _calibrationPoints.addAll(optimized);
        });

        _addLog('校准已优化: ${optimized.length} 个点');
      } catch (e) {
        _addLog('优化校准失败: $e');
      }
    }
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _logs.add('[$timestamp] $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });

    // 同时输出到控制台，方便调试
    print('[$timestamp] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('亮度控制'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusSection(),
            const SizedBox(height: 16),
            _buildConnectionSection(),
            const SizedBox(height: 16),
            _buildBrightnessSection(),
            const SizedBox(height: 16),
            _buildCalibrationSection(),
            const SizedBox(height: 16),
            _buildLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('串口连接',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPort,
                    hint: const Text('选择 COM 端口'),
                    items: SerialService.getAvailablePorts()
                        .map((port) =>
                            DropdownMenuItem(value: port, child: Text(port)))
                        .toList(),
                    onChanged: _isConnected
                        ? null
                        : (value) {
                            setState(() {
                              _selectedPort = value;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isConnected
                      ? _disconnect
                      : (_selectedPort != null ? _connectToPort : null),
                  child: Text(_isConnected ? '断开连接' : '连接'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('开机自启动: '),
                Switch(
                  value: _autoStartEnabled,
                  onChanged: (value) {
                    _toggleAutoStart();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('自动连接上次端口: '),
                Switch(
                  value: _autoConnectEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoConnectEnabled = value;
                    });
                    _saveAutoConnectSetting(value);
                    _addLog('自动连接已${value ? "启用" : "禁用"}');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('状态',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.light_mode, size: 32),
                    const Text('光照'),
                    Text('$_currentLux LUX',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Icon(Icons.brightness_6, size: 32),
                    const Text('亮度'),
                    Text('$_currentBrightness%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Icon(_isConnected ? Icons.link : Icons.link_off, size: 32),
                    const Text('连接'),
                    Text(_isConnected ? '已连接' : '未连接',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.red)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('手动亮度控制',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.brightness_low),
                Expanded(
                  child: Slider(
                    value: _manualBrightness.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${_manualBrightness}%',
                    onChanged: _setManualBrightness,
                  ),
                ),
                const Icon(Icons.brightness_high),
              ],
            ),
            Text('当前: ${_manualBrightness}%', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('校准',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('校准点数量: ${_calibrationPoints.length}'),
            const SizedBox(height: 4),
            const Text('提示: 拖动亮度滑条时会自动添加校准点',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _calibrationPoints.length > 3
                      ? _optimizeCalibration
                      : null,
                  child: const Text('优化'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _calibrationPoints.isNotEmpty ? _clearCalibration : null,
                  child: const Text('清除全部'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return SizedBox(
      height: 300, // 固定高度
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('日志',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final logIndex = _logs.length - 1 - index;
                      final logEntry = _logs[logIndex];

                      // 根据日志内容设置不同颜色
                      Color? textColor;
                      if (logEntry.contains('✓') ||
                          logEntry.contains('成功') ||
                          logEntry.contains('已连接')) {
                        textColor = Colors.green;
                      } else if (logEntry.contains('✗') ||
                          logEntry.contains('失败') ||
                          logEntry.contains('错误')) {
                        textColor = Colors.red;
                      } else if (logEntry.contains('警告')) {
                        textColor = Colors.orange;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        child: Text(
                          logEntry,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                            height: 1.3, // 增加行高，改善中文显示效果
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
