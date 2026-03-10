import 'package:flutter/services.dart';

class KioskService {
  static const MethodChannel _channel = MethodChannel('pos_kevin/kiosk_mode');

  Future<bool> isSupported() async {
    final value = await _channel.invokeMethod<bool>('isLockTaskSupported');
    return value ?? false;
  }

  Future<bool> isActive() async {
    final value = await _channel.invokeMethod<bool>('isLockTaskActive');
    return value ?? false;
  }

  Future<bool> start() async {
    final value = await _channel.invokeMethod<bool>('startLockTask');
    return value ?? false;
  }

  Future<bool> stop() async {
    final value = await _channel.invokeMethod<bool>('stopLockTask');
    return value ?? false;
  }
}
