// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Màn "Hợp tác xã": chưa đăng nhập thì hiện màn mở đầu có nút đăng nhập; đã đăng nhập thì hiện ví tín chỉ kiểu ví điện
// tử (số dư nổi bật, dải sê-ri dạng thẻ) và danh sách lô đất. Kéo xuống để tải lại. 401 → bỏ phiên, mời đăng nhập lại.
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../api/hop_tac_xa.dart';
import '../api/kiem_chung.dart';
import '../api/loi.dart';
import '../dang_nhap.dart';
import '../giao_dien.dart';
import 'chi_tiet_lo.dart';
import 'kiem_chung.dart';

class ManHopTacXa extends StatefulWidget {
  const ManHopTacXa({super.key, required this.phien, required this.api, required this.kiemChungApi});

  final PhienDangNhap phien;
  final HopTacXaApi api;
  final KiemChungApi kiemChungApi;

  @override
  State<ManHopTacXa> createState() => _ManHopTacXaState();
}

class _ManHopTacXaState extends State<ManHopTacXa> {
  TongQuanHtx? _du;
  Object? _loi;
  bool _dangTai = false;
  bool _dangDangNhap = false;
  String? _loiDangNhap;
  bool _daDangNhapTruoc = false;

  @override
  void initState() {
    super.initState();
    widget.phien.addListener(_doiPhien);
    _doiPhien();
  }

  @override
  void dispose() {
    widget.phien.removeListener(_doiPhien);
    super.dispose();
  }

  void _doiPhien() {
    final co = widget.phien.daDangNhap;
    if (co && !_daDangNhapTruoc) _tai();
    if (!co) setState(() => _du = null);
    _daDangNhapTruoc = co;
  }

  Future<void> _tai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final d = await widget.api.tongQuan();
      if (mounted) setState(() => _du = d);
    } on LoiHetPhien {
      _loiDangNhap = const LoiHetPhien().toString();
      await widget.phien.huyPhien();
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _dangNhap() async {
    setState(() {
      _dangDangNhap = true;
      _loiDangNhap = null;
    });
    try {
      await widget.phien.dangNhap();
    } on FlutterAppAuthUserCancelledException {
      // Người dùng đóng trang đăng nhập: không coi là lỗi.
    } catch (_) {
      _loiDangNhap = 'Không mở được trang đăng nhập. Kiểm tra mạng rồi thử lại.';
    } finally {
      if (mounted) setState(() => _dangDangNhap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nd = widget.phien.nguoiDung;
    if (nd == null) return _ManMoDau(dangMo: _dangDangNhap, loi: _loiDangNhap, onDangNhap: _dangNhap);
    return ColoredBox(
      color: mauNen,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FHeader(
              // Tên hợp tác xã có thể dài ("HTX Rừng ngập mặn Đất Mũi (dữ liệu giả)"): tối đa 2 dòng, không cắt cụt
              title: Text(
                _du?.tenHtx.isNotEmpty == true ? _du!.tenHtx : 'Hợp tác xã',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.chu.display.lg.copyWith(fontWeight: FontWeight.w700, color: mauChu, height: 1.2),
              ),
              suffixes: [
                FHeaderAction(
                  icon: const Icon(FLucideIcons.logOut),
                  semanticsLabel: 'Đăng xuất',
                  onPress: () => widget.phien.dangXuat(),
                ),
              ],
            ),
            Expanded(child: _noiDung(context, nd)),
          ],
        ),
      ),
    );
  }

  Widget _noiDung(BuildContext context, NguoiDung nd) {
    final du = _du;
    if (du == null && _dangTai) return const Center(child: FCircularProgress());
    if (du == null && _loi != null) {
      return KhungThongBao(
        icon: _loi is LoiMang ? FLucideIcons.wifiOff : FLucideIcons.triangleAlert,
        tieuDe: _loi is LoiMang ? 'Mất kết nối' : 'Không tải được dữ liệu',
        noiDung: _loi.toString(),
        nut: 'Thử lại',
        onNhan: _tai,
      );
    }
    if (du == null) return const SizedBox.shrink();
    final chu = context.chu;
    return RefreshIndicator(
      color: mauChinh,
      onRefresh: _tai,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(
            'Xin chào, ${nd.ten}',
            style: chu.body.lg.copyWith(fontWeight: FontWeight.w600, color: mauChu),
          ),
          const SizedBox(height: 2),
          Text(du.laCanBo ? 'Cán bộ hợp tác xã' : 'Xã viên (chỉ xem)', style: chu.body.sm.copyWith(color: mauChuPhu)),
          if (_loi != null) ...[
            const SizedBox(height: 12),
            FAlert(variant: .destructive, title: const Text('Chưa tải lại được'), subtitle: Text(_loi.toString())),
          ],
          const SizedBox(height: 16),
          _TheSoDu(du: du),
          const SizedBox(height: 22),
          _TieuDeMuc(du.vi.isEmpty ? 'Dải sê-ri' : 'Dải sê-ri đang nắm giữ (${du.vi.length})'),
          const SizedBox(height: 10),
          if (du.vi.isEmpty)
            const _OTrong(icon: FLucideIcons.walletCards, noiDung: 'Ví hiện chưa có tín chỉ khả dụng.')
          else
            for (final k in du.vi) ...[
              _TheSeri(khoi: k, onNhan: () => _moKiemChung(k.seriTu)),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 14),
          _TieuDeMuc('Lô đất (${du.lo.length})'),
          const SizedBox(height: 10),
          if (du.lo.isEmpty)
            const _OTrong(
              icon: FLucideIcons.landPlot,
              noiDung: 'Hợp tác xã chưa có lô đất nào. Cán bộ đăng ký lô mới trên web.',
            )
          else
            FTileGroup(
              children: [
                for (final lo in du.lo)
                  FTile(
                    prefix: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: mauNhat, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(FLucideIcons.trees, color: mauChinh, size: 22),
                    ),
                    title: Text(
                      lo.ten,
                      style: chu.body.md.copyWith(fontWeight: FontWeight.w600, color: mauChu),
                    ),
                    subtitle: Text(
                      [
                        '${soVn(lo.dienTichHa, le: 2)} ha',
                        if (lo.namTrong != null) 'trồng ${lo.namTrong}',
                        if (lo.xaVien != null) lo.xaVien!,
                      ].join(' · '),
                    ),
                    suffix: const Icon(FLucideIcons.chevronRight),
                    onPress: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ManChiTietLo(lo: lo, api: widget.api, onTraSeri: _moKiemChung),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _moKiemChung(String seri) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManKiemChung(api: widget.kiemChungApi, maBanDau: seri),
      ),
    );
  }
}

/// Màn mở đầu khi chưa đăng nhập: logo, lời giới thiệu ngắn, nút đăng nhập.
class _ManMoDau extends StatelessWidget {
  const _ManMoDau({required this.dangMo, required this.loi, required this.onDangNhap});

  final bool dangMo;
  final String? loi;
  final VoidCallback onDangNhap;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mauNhat, mauNen],
          stops: [0, 0.55],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x220B6351), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Image.asset('assets/logo.png'),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'CarbonFarm',
              textAlign: TextAlign.center,
              style: chu.display.xl2.copyWith(color: mauChinhDam, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Tín chỉ carbon cho hợp tác xã rừng ngập mặn',
              textAlign: TextAlign.center,
              style: chu.body.md.copyWith(color: mauChuPhu),
            ),
            const SizedBox(height: 30),
            const _DongLoiIch(icon: FLucideIcons.walletCards, noiDung: 'Xem số dư và các dải sê-ri trong ví'),
            const _DongLoiIch(icon: FLucideIcons.trees, noiDung: 'Theo dõi lô đất và các kỳ đo từ vệ tinh'),
            const _DongLoiIch(icon: FLucideIcons.shieldCheck, noiDung: 'Kiểm chứng tín chỉ trên sổ cái công khai'),
            const SizedBox(height: 26),
            if (loi != null) ...[
              FAlert(variant: .destructive, title: const Text('Chưa đăng nhập được'), subtitle: Text(loi!)),
              const SizedBox(height: 14),
            ],
            FButton(
              onPress: dangMo ? null : onDangNhap,
              prefix: const Icon(FLucideIcons.logIn),
              child: Text(dangMo ? 'Đang mở trang đăng nhập…' : 'Đăng nhập'),
            ),
            const SizedBox(height: 14),
            Text(
              'Dành cho cán bộ hợp tác xã. Kiểm chứng tín chỉ không cần đăng nhập: chọn thẻ "Kiểm chứng" bên dưới.',
              textAlign: TextAlign.center,
              style: chu.body.sm.copyWith(color: mauChuPhu),
            ),
          ],
        ),
      ),
    );
  }
}

class _DongLoiIch extends StatelessWidget {
  const _DongLoiIch({required this.icon, required this.noiDung});

  final IconData icon;
  final String noiDung;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 20, color: mauChinh),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(noiDung, style: context.chu.body.sm.copyWith(color: mauChu)),
        ),
      ],
    ),
  );
}

/// Thẻ số dư kiểu ví điện tử: số tín chỉ trong ví thật lớn, đã cấp / đã bán bên dưới.
class _TheSoDu extends StatelessWidget {
  const _TheSoDu({required this.du});

  final TongQuanHtx du;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    const trang = Colors.white;
    Widget phu(String nhan, int v, String khoa) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nhan, style: chu.body.sm.copyWith(color: const Color(0xCCFFFFFF))),
            const SizedBox(height: 2),
            Text(
              soVn(v),
              key: Key(khoa),
              style: chu.display.lg.copyWith(color: trang, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F7A63), mauChinh, mauChinhDam],
        ),
        boxShadow: const [BoxShadow(color: Color(0x330B6351), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FLucideIcons.walletCards, color: trang, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ví tín chỉ',
                style: chu.body.md.copyWith(color: trang, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('1 tín chỉ = 1 t CO₂e', style: chu.body.xs.copyWith(color: const Color(0xCCFFFFFF))),
            ],
          ),
          const SizedBox(height: 14),
          Text('Trong ví', style: chu.body.sm.copyWith(color: const Color(0xCCFFFFFF))),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                soVn(du.trongVi),
                key: const Key('so-trong-vi'),
                style: chu.display.xl5.copyWith(color: trang, fontWeight: FontWeight.w800, height: 1.05),
              ),
              const SizedBox(width: 8),
              Text('tín chỉ', style: chu.body.lg.copyWith(color: const Color(0xE6FFFFFF))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              phu('Đã cấp', du.daCap, 'so-da-cap'),
              const SizedBox(width: 10),
              phu('Đã bán', du.daBan, 'so-da-ban'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một dải sê-ri trong ví, dạng thẻ; chạm để kiểm chứng sê-ri đầu tiên.
class _TheSeri extends StatelessWidget {
  const _TheSeri({required this.khoi, required this.onNhan});

  final KhoiTinChi khoi;
  final VoidCallback onNhan;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    final mono = chu.body.sm.copyWith(fontFamily: 'monospace', color: mauChu, letterSpacing: 0.2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onNhan,
        child: TheNoiDung(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: mauNhat, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(
                      soVn(khoi.soLuong),
                      style: chu.display.lg.copyWith(color: mauChinhDam, fontWeight: FontWeight.w800),
                    ),
                    Text('tín chỉ', style: chu.body.xs.copyWith(color: mauChinhDam)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Mã sê-ri dài 22 ký tự: mỗi mã một dòng, thu nhỏ vừa khung chứ không xuống dòng giữa mã
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (nhan, ma) in [('Từ', khoi.seriTu), ('Đến', khoi.seriDen)])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(nhan, style: chu.body.xs.copyWith(color: mauChuPhu)),
                            ),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(ma, maxLines: 1, style: mono),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(FLucideIcons.shieldCheck, color: mauChinh, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _TieuDeMuc extends StatelessWidget {
  const _TieuDeMuc(this.nhan);
  final String nhan;

  @override
  Widget build(BuildContext context) => Text(
    nhan,
    style: context.chu.display.md.copyWith(fontWeight: FontWeight.w700, color: mauChu),
  );
}

class _OTrong extends StatelessWidget {
  const _OTrong({required this.icon, required this.noiDung});

  final IconData icon;
  final String noiDung;

  @override
  Widget build(BuildContext context) => TheNoiDung(
    child: Row(
      children: [
        Icon(icon, color: mauChuPhu),
        const SizedBox(width: 12),
        Expanded(
          child: Text(noiDung, style: context.chu.body.md.copyWith(color: mauChuPhu)),
        ),
      ],
    ),
  );
}
