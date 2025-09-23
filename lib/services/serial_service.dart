import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// 串口通信服务类
/// 负责与光照度传感器设备进行串口通信
class SerialService {
  /// 串口对象
  SerialPort? _port;
  /// 串口数据读取器
  SerialPortReader? _reader;
  /// 数据流控制器，用于广播接收到的数据
  StreamController<String>? _controller;
  /// 连接状态标识
  bool _isConnected = false;

  /// 获取数据流，外部可监听此流获取串口数据
  Stream<String> get dataStream => _controller?.stream ?? const Stream.empty();
  /// 获取当前连接状态
  bool get isConnected => _isConnected;

  /// 获取系统中所有可用的串口列表
  static List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// 连接到指定的串口
  /// [portName] 串口名称（如 COM3, /dev/ttyUSB0）
  /// 返回连接是否成功
  bool connect(String portName) {
    try {
      _port = SerialPort(portName);

      if (!_port!.openReadWrite()) {
        print('Failed to open port: ${SerialPort.lastError}');
        return false;
      }

      // 配置串口参数
      final config = SerialPortConfig();
      config.baudRate = 9600;  // 波特率
      config.bits = 8;         // 数据位
      config.parity = SerialPortParity.none;  // 无校验位
      config.stopBits = 1;     // 停止位
      config.setFlowControl(SerialPortFlowControl.none);  // 无流控制

      _port!.config = config;

      _controller = StreamController<String>.broadcast();
      _reader = SerialPortReader(_port!);
      _isConnected = true;

      // 监听串口数据
      _reader!.stream.listen(
        (data) {
          final message = String.fromCharCodes(data);
          _processIncomingData(message);
        },
        onError: (error) {
          print('Serial read error: $error');
          disconnect();
        },
      );

      print('Connected to port: $portName');
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  /// 处理接收到的串口数据
  /// 将数据按行分割，去除空行后发送到数据流
  void _processIncomingData(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _controller?.add(trimmed);
      }
    }
  }

  /// 断开串口连接
  /// 关闭所有相关资源并重置状态
  void disconnect() {
    _isConnected = false;
    _reader?.close();
    _port?.close();
    _controller?.close();

    _reader = null;
    _port = null;
    _controller = null;

    print('Disconnected from serial port');
  }

  /// 释放资源，通常在服务销毁时调用
  void dispose() {
    disconnect();
  }
}