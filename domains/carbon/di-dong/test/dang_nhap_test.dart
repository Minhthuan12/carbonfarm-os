// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Phần không cần trình duyệt của đăng nhập: đọc tên hiển thị từ access token.
import 'dart:convert';

import 'package:carbonfarm/dang_nhap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đọc tên người dùng từ access token (JWT)', () {
    String b64(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final tk =
        '${b64({'alg': 'RS256'})}.${b64({'given_name': 'Cán bộ', 'family_name': 'Mẫu', 'preferred_username': 'canbo-htx-mau'})}.ky';
    final nd = NguoiDung.tuToken(tk);
    expect(nd.ten, 'Cán bộ Mẫu');
    expect(nd.tenDangNhap, 'canbo-htx-mau');
  });
}
