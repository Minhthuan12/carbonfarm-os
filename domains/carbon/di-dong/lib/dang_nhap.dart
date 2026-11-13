// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Đăng nhập Keycloak (realm dxos, client công khai carbon-di-dong) bằng Authorization Code + PKCE qua trình duyệt hệ
// thống (AppAuth). App không bao giờ thấy mật khẩu. Access token chỉ giữ trong bộ nhớ; refresh token và id token cất
// trong Keychain (iOS) / Keystore (Android) để mở lại app không phải đăng nhập lại.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cau_hinh.dart';

class NguoiDung {
  const NguoiDung({required this.ten, required this.tenDangNhap});
  final String ten;
  final String tenDangNhap;

  /// Đọc tên hiển thị từ payload JWT (chữ ký do gateway và PostGraphile kiểm khi gọi API).
  factory NguoiDung.tuToken(String accessToken) {
    final phan = accessToken.split('.');
    final p = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(phan[1])))) as Map<String, dynamic>;
    final ten = [p['given_name'], p['family_name']].whereType<String>().join(' ');
    final tenDn = p['preferred_username'] as String? ?? '';
    return NguoiDung(ten: ten.isNotEmpty ? ten : (tenDn.isNotEmpty ? tenDn : 'Người dùng'), tenDangNhap: tenDn);
  }
}

/// Giao diện phiên đăng nhập; màn hình chỉ dùng giao diện này nên kiểm thử thay được bằng bản giả.
abstract class PhienDangNhap extends ChangeNotifier {
  NguoiDung? get nguoiDung;
  bool get daDangNhap => nguoiDung != null;

  /// Khôi phục phiên cũ từ refresh token đã cất (nếu còn hạn).
  Future<void> khoiPhuc();
  Future<void> dangNhap();
  Future<void> dangXuat();

  /// Access token còn hạn ít nhất 30 giây, tự làm mới khi cần; null nếu không còn phiên.
  Future<String?> layToken();

  /// Gọi khi API trả 401: bỏ phiên hiện tại để màn hình hiện nút đăng nhập lại.
  Future<void> huyPhien();
}

class PhienKeycloak extends PhienDangNhap {
  PhienKeycloak({FlutterAppAuth? appAuth, FlutterSecureStorage? kho})
    : _appAuth = appAuth ?? const FlutterAppAuth(),
      _kho = kho ?? const FlutterSecureStorage();

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _kho;

  static const _khoaRefresh = 'refresh_token';
  static const _khoaId = 'id_token';

  static final _cauHinh = AuthorizationServiceConfiguration(
    authorizationEndpoint: '$oidcGoc/auth',
    tokenEndpoint: '$oidcGoc/token',
    endSessionEndpoint: '$oidcGoc/logout',
  );

  String? _accessToken;
  DateTime? _hetHan;
  String? _idToken;
  NguoiDung? _nguoiDung;

  @override
  NguoiDung? get nguoiDung => _nguoiDung;

  void _nhan(TokenResponse r) {
    _accessToken = r.accessToken;
    _hetHan = r.accessTokenExpirationDateTime;
    _idToken = r.idToken ?? _idToken;
    _nguoiDung = _accessToken == null ? null : NguoiDung.tuToken(_accessToken!);
  }

  Future<void> _cat(TokenResponse r) async {
    if (r.refreshToken != null) await _kho.write(key: _khoaRefresh, value: r.refreshToken);
    if (r.idToken != null) await _kho.write(key: _khoaId, value: r.idToken);
  }

  @override
  Future<void> khoiPhuc() async {
    _idToken = await _kho.read(key: _khoaId);
    if (await _lamMoi()) notifyListeners();
  }

  Future<bool> _lamMoi() async {
    final refresh = await _kho.read(key: _khoaRefresh);
    if (refresh == null) return false;
    try {
      final r = await _appAuth.token(
        TokenRequest(
          clientId,
          duongQuayVe,
          refreshToken: refresh,
          serviceConfiguration: _cauHinh,
          scopes: const ['openid'],
        ),
      );
      _nhan(r);
      await _cat(r);
      return _accessToken != null;
    } on FlutterAppAuthPlatformException {
      // Refresh token hết hạn hoặc phiên đã bị đăng xuất ở máy chủ: coi như chưa đăng nhập.
      await _xoa();
      return false;
    }
  }

  @override
  Future<void> dangNhap() async {
    final r = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        duongQuayVe,
        serviceConfiguration: _cauHinh,
        scopes: const ['openid'],
        // Phiên trình duyệt riêng: không dùng chung cookie với Safari/Chrome, không hỏi "muốn dùng ... để đăng nhập".
        externalUserAgent: ExternalUserAgent.ephemeralAsWebAuthenticationSession,
        additionalParameters: const {'ui_locales': 'vi'},
      ),
    );
    _nhan(r);
    await _cat(r);
    notifyListeners();
  }

  @override
  Future<String?> layToken() async {
    final conHan = _hetHan != null && _hetHan!.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    if (_accessToken != null && conHan) return _accessToken;
    if (await _lamMoi()) return _accessToken;
    notifyListeners();
    return null;
  }

  @override
  Future<void> dangXuat() async {
    final id = _idToken;
    await _xoa();
    notifyListeners();
    if (id == null) return;
    try {
      await _appAuth.endSession(
        EndSessionRequest(
          idTokenHint: id,
          postLogoutRedirectUrl: duongQuayVe,
          serviceConfiguration: _cauHinh,
          externalUserAgent: ExternalUserAgent.ephemeralAsWebAuthenticationSession,
        ),
      );
    } on FlutterAppAuthPlatformException {
      // Người dùng đóng trình duyệt trước khi xong: phiên trong app đã xóa, refresh token không còn trên máy.
    }
  }

  @override
  Future<void> huyPhien() async {
    await _xoa();
    notifyListeners();
  }

  Future<void> _xoa() async {
    _accessToken = null;
    _hetHan = null;
    _nguoiDung = null;
    await _kho.delete(key: _khoaRefresh);
  }
}
