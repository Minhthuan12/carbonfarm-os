// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// App di động CarbonFarm (Tầng 2, miền carbon): cán bộ hợp tác xã xem lô đất và ví tín chỉ; ai cũng kiểm chứng được
// sê-ri tín chỉ trên sổ cái công khai. Chỉ gọi API có sẵn của gateway, không có backend riêng. Giao diện dùng forui.
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import 'api/graphql.dart';
import 'api/hop_tac_xa.dart';
import 'api/kiem_chung.dart';
import 'cau_hinh.dart';
import 'dang_nhap.dart';
import 'giao_dien.dart';
import 'man_hinh/hop_tac_xa.dart';
import 'man_hinh/kiem_chung.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final phien = PhienKeycloak();
  runApp(
    CarbonFarmApp(
      phien: phien,
      htxApi: HopTacXaApi(GraphqlClient(goc: apiUrl, layToken: phien.layToken)),
      kiemChungApi: KiemChungApi(goc: apiUrl),
    ),
  );
  phien.khoiPhuc();
}

class CarbonFarmApp extends StatelessWidget {
  const CarbonFarmApp({super.key, required this.phien, required this.htxApi, required this.kiemChungApi});

  final PhienDangNhap phien;
  final HopTacXaApi htxApi;
  final KiemChungApi kiemChungApi;

  @override
  Widget build(BuildContext context) => ungDungCarbonFarm(
    home: TrangChinh(phien: phien, htxApi: htxApi, kiemChungApi: kiemChungApi),
  );
}

class TrangChinh extends StatefulWidget {
  const TrangChinh({super.key, required this.phien, required this.htxApi, required this.kiemChungApi});

  final PhienDangNhap phien;
  final HopTacXaApi htxApi;
  final KiemChungApi kiemChungApi;

  @override
  State<TrangChinh> createState() => _TrangChinhState();
}

class _TrangChinhState extends State<TrangChinh> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      childPad: false,
      footer: DecoratedBox(
        // Cùng màu nền với thanh điều hướng của forui, kéo xuống hết vùng an toàn dưới đáy máy
        decoration: const BoxDecoration(
          color: mauNen,
          border: Border(top: BorderSide(color: mauVien)),
        ),
        child: SafeArea(
          top: false,
          child: FBottomNavigationBar(
            index: _tab,
            onChange: (i) => setState(() => _tab = i),
            children: const [
              FBottomNavigationBarItem(icon: Icon(FLucideIcons.walletCards), label: Text('Hợp tác xã')),
              FBottomNavigationBarItem(icon: Icon(FLucideIcons.shieldCheck), label: Text('Kiểm chứng')),
            ],
          ),
        ),
      ),
      child: IndexedStack(
        index: _tab,
        children: [
          ManHopTacXa(phien: widget.phien, api: widget.htxApi, kiemChungApi: widget.kiemChungApi),
          ManKiemChung(api: widget.kiemChungApi),
        ],
      ),
    );
  }
}
