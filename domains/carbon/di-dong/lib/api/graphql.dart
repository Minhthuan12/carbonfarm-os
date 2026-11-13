// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Gọi GraphQL của Tầng 1 (PostGraphile) qua gateway bằng access token của người dùng. Quyền xem dữ liệu do RLS trong
// CSDL quyết định, app không lọc thêm.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'loi.dart';

class GraphqlClient {
  GraphqlClient({required this.goc, required this.layToken, http.Client? client}) : _http = client ?? http.Client();

  final String goc;

  /// Trả access token còn hạn (tự làm mới nếu cần); null nghĩa là chưa đăng nhập.
  final Future<String?> Function() layToken;
  final http.Client _http;

  Future<Map<String, dynamic>> truyVan(String query, [Map<String, dynamic>? bien]) async {
    final token = await layToken();
    if (token == null) throw const LoiHetPhien();
    final http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$goc/graphql'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'query': query, 'variables': ?bien}),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const LoiMang();
    } on TimeoutException {
      throw const LoiMang();
    } on http.ClientException {
      throw const LoiMang();
    }
    if (res.statusCode == 401) throw const LoiHetPhien();
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>?;
    } on FormatException {
      j = null;
    }
    final loi = (j?['errors'] as List?)?.firstOrNull as Map<String, dynamic>?;
    if (loi != null) {
      final ma = (loi['extensions'] as Map?)?['code'];
      if (ma is String && ma.startsWith('U')) throw LoiMayChu(loi['message'] as String, ma: ma);
      throw const LoiMayChu('Máy chủ từ chối yêu cầu.');
    }
    if (res.statusCode != 200 || j == null) throw LoiMayChu('Máy chủ trả mã ${res.statusCode}.');
    return j['data'] as Map<String, dynamic>;
  }
}
