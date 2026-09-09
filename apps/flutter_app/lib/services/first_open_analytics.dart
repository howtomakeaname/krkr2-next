import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_info.dart';

/// 首次打开统计：向自建 Go 服务上报一次（匿名 id + 版本号）。
/// 本地调试时 [baseUrl] 设为 `http://127.0.0.1:8080`（iOS 模拟器 / macOS）
/// 或 `http://10.0.2.2:8080`（Android 模拟器）。
class FirstOpenAnalytics {
  FirstOpenAnalytics({
    required this.baseUrl,
    this.appToken,
  });

  final String baseUrl;
  final String? appToken;

  static const String _prefKey = 'first_open_reported';

  /// 若尚未上报过，则上报一次并标记；否则不请求。
  static Future<void> reportIfNeeded({
    required String baseUrl,
    String? appToken,
    String? version,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) return;

    final analytics = FirstOpenAnalytics(baseUrl: baseUrl, appToken: appToken);
    final ok = await analytics.report(version: version);
    if (ok) await prefs.setBool(_prefKey, true);
  }

  /// 发送一次首次打开上报。返回是否成功（不抛异常）。
  Future<bool> report({String? version}) async {
    final uri = Uri.parse('$baseUrl/api/first_open');
    if (uri.host.isEmpty) return false;

    final id = await _anonId();
    final body = jsonEncode(<String, String>{
      'id': id,
      'v': version ?? AppInfo.version,
    });

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (appToken != null && appToken!.isNotEmpty) 'X-App-Token': appToken!,
      };
      final r = await http
          .post(uri, body: body, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode >= 200 && r.statusCode < 300) return true;
      if (kDebugMode) {
        debugPrint('FirstOpenAnalytics: ${r.statusCode} ${r.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FirstOpenAnalytics: $e');
    }
    return false;
  }

  static Future<String> _anonId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'first_open_anon_id';
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await prefs.setString(key, id);
    }
    return id;
  }

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = (now * 0.1).floor() ^ (now % 0x7fffffff).toInt();
    return '${now.toRadixString(36)}-${r.toRadixString(36)}';
  }
}
