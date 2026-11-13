// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// App di động CarbonFarm (Tầng 2, miền carbon). Bước đầu: khung app và đăng nhập Keycloak (OIDC + PKCE).
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:material_ui/material_ui.dart';

import 'dang_nhap.dart';
import 'giao_dien.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final phien = PhienKeycloak();
  runApp(CarbonFarmApp(phien: phien));
  phien.khoiPhuc();
}

class CarbonFarmApp extends StatelessWidget {
  const CarbonFarmApp({super.key, required this.phien});

  final PhienDangNhap phien;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbonFarm',
      debugShowCheckedModeBanner: false,
      theme: giaoDien(),
      home: ManTaiKhoan(phien: phien),
    );
  }
}

/// Màn tài khoản tạm thời: đăng nhập, xem tên, đăng xuất. Các màn nghiệp vụ thêm ở bước sau.
class ManTaiKhoan extends StatelessWidget {
  const ManTaiKhoan({super.key, required this.phien});

  final PhienDangNhap phien;

  Future<void> _dangNhap(BuildContext context) async {
    try {
      await phien.dangNhap();
    } on FlutterAppAuthUserCancelledException {
      // Người dùng đóng trang đăng nhập: không coi là lỗi.
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Không mở được trang đăng nhập. Kiểm tra mạng rồi thử lại.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: phien,
      builder: (context, _) {
        final nd = phien.nguoiDung;
        return Scaffold(
          appBar: AppBar(title: const Text('CarbonFarm')),
          body: nd == null
              ? KhungThongBao(
                  icon: Icons.login,
                  tieuDe: 'Chưa đăng nhập',
                  noiDung: 'Cán bộ hợp tác xã đăng nhập bằng tài khoản CarbonFarm OS.',
                  nut: 'Đăng nhập',
                  onNhan: () => _dangNhap(context),
                )
              : KhungThongBao(
                  icon: Icons.verified_user,
                  tieuDe: 'Xin chào, ${nd.ten}',
                  noiDung: 'Tên đăng nhập: ${nd.tenDangNhap}',
                  nut: 'Đăng xuất',
                  onNhan: phien.dangXuat,
                ),
        );
      },
    );
  }
}
