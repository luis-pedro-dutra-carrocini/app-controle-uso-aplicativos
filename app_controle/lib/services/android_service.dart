import 'dart:convert';
import 'package:flutter/services.dart';

class AndroidService {
  static const _channel = MethodChannel('com.example.appcontrole/app_control');

  static Future<List<Map<String, String>>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (result ?? []).map((e) => Map<String, String>.from(e as Map)).toList();
  }

  static Future<void> setRules(List<dynamic> rulesJson) async {
    // Serializa para String antes de enviar
    final jsonString = jsonEncode(rulesJson);
    await _channel.invokeMethod('setRules', {'rules': jsonString});
  }

  static Future<bool> checkAccessibilityPermission() async {
    return await _channel.invokeMethod<bool>('checkAccessibilityPermission') ?? false;
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  static Future<bool> checkOverlayPermission() async {
    return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
  }

  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }
}