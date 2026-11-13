// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// App di động CarbonFarm (Tầng 2, miền carbon): đăng nhập Keycloak (OIDC + PKCE) và kiểm chứng sê-ri công khai.
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:material_ui/material_ui.dart';

import 'api/kiem_chung.dart';
import 'cau_hinh.dart';
import 'dang_nhap.dart';
import 'giao_dien.dart';
import 'man_hinh/kiem_chung.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final phien = PhienKeycloak();
  runApp(
    CarbonFarmApp(
      phien: phien,
      kiemChungApi: KiemChungApi(goc: apiUrl),
    ),
  );
  phien.khoiPhuc();
}

class CarbonFarmApp extends StatelessWidget {
  const CarbonFarmApp({super.key, required this.phien, required this.kiemChungApi});

  final PhienDangNhap phien;
  final KiemChungApi kiemChungApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbonFarm',
      debugShowCheckedModeBanner: false,
      theme: giaoDien(),
      home: TrangChinh(phien: phien, kiemChungApi: kiemChungApi),
    );
  }
}

class TrangChinh extends StatefulWidget {
  const TrangChinh({super.key, required this.phien, required this.kiemChungApi});

  final PhienDangNhap phien;
  final KiemChungApi kiemChungApi;

  @override
  State<TrangChinh> createState() => _TrangChinhState();
}

class _TrangChinhState extends State<TrangChinh> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ManTaiKhoan(phien: widget.phien),
          ManKiemChung(api: widget.kiemChungApi),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Kiểm chứng',
          ),
        ],
      ),
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
