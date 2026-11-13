// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Màn "Hợp tác xã": chưa đăng nhập thì hiện nút đăng nhập; đã đăng nhập thì hiện ví tín chỉ (đã cấp, đã bán, trong ví)
// và danh sách lô đất của hợp tác xã. Kéo xuống để tải lại. 401 → bỏ phiên, mời đăng nhập lại.
import 'package:flutter_appauth/flutter_appauth.dart';
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
    return Scaffold(
      appBar: AppBar(
        // Tên hợp tác xã có thể dài ("HTX Rừng ngập mặn Đất Mũi (dữ liệu giả)"): cho xuống tối đa 2 dòng, chữ nhỏ hơn
        toolbarHeight: 72,
        title: Text(
          _du?.tenHtx.isNotEmpty == true ? _du!.tenHtx : 'Hợp tác xã',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 19, height: 1.25, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (nd != null)
            IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: () => widget.phien.dangXuat()),
        ],
      ),
      body: nd == null ? _manDangNhap(context) : _noiDung(context, nd),
    );
  }

  Widget _manDangNhap(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(child: Image.asset('assets/logo.png', width: 96, height: 96)),
        const SizedBox(height: 16),
        Text(
          'CarbonFarm',
          style: t.headlineMedium?.copyWith(color: mauChinh, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Cán bộ hợp tác xã đăng nhập để xem lô đất và ví tín chỉ carbon.',
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_loiDangNhap != null) ...[_BaoLoi(_loiDangNhap!), const SizedBox(height: 16)],
        FilledButton.icon(
          onPressed: _dangDangNhap ? null : _dangNhap,
          icon: const Icon(Icons.login),
          label: Text(_dangDangNhap ? 'Đang mở trang đăng nhập…' : 'Đăng nhập'),
        ),
        const SizedBox(height: 16),
        Text(
          'Kiểm chứng tín chỉ không cần đăng nhập: chọn thẻ "Kiểm chứng" bên dưới.',
          style: t.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _noiDung(BuildContext context, NguoiDung nd) {
    final du = _du;
    if (du == null && _dangTai) return const Center(child: CircularProgressIndicator());
    if (du == null && _loi != null) {
      return KhungThongBao(
        icon: _loi is LoiMang ? Icons.wifi_off : Icons.error_outline,
        tieuDe: _loi is LoiMang ? 'Mất kết nối' : 'Không tải được dữ liệu',
        noiDung: _loi.toString(),
        nut: 'Thử lại',
        onNhan: _tai,
      );
    }
    if (du == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _tai,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Xin chào, ${nd.ten}', style: t.titleMedium),
          Text(du.laCanBo ? 'Cán bộ hợp tác xã' : 'Xã viên (chỉ xem)', style: t.bodyMedium),
          if (_loi != null) ...[const SizedBox(height: 12), _BaoLoi(_loi.toString())],
          const SizedBox(height: 16),
          _TheVi(du: du, onTraSeri: _moKiemChung),
          const SizedBox(height: 24),
          Text('Lô đất (${du.lo.length})', style: t.titleLarge),
          const SizedBox(height: 8),
          if (du.lo.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Hợp tác xã chưa có lô đất nào. Cán bộ đăng ký lô mới trên web.'),
              ),
            )
          else
            for (final lo in du.lo) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: mauNhat,
                    child: Icon(Icons.forest, color: mauChinh),
                  ),
                  title: Text(lo.ten, style: t.titleMedium),
                  subtitle: Text(
                    [
                      '${soVn(lo.dienTichHa, le: 2)} ha',
                      if (lo.namTrong != null) 'trồng ${lo.namTrong}',
                      if (lo.xaVien != null) lo.xaVien!,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManChiTietLo(lo: lo, api: widget.api, onTraSeri: _moKiemChung),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
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

class _TheVi extends StatelessWidget {
  const _TheVi({required this.du, required this.onTraSeri});

  final TongQuanHtx du;
  final void Function(String seri) onTraSeri;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget so(String nhan, int v, {bool chinh = false}) => Expanded(
      child: Column(
        children: [
          Text(
            soVn(v),
            style: (chinh ? t.headlineMedium : t.headlineSmall)?.copyWith(
              color: chinh ? mauChinh : null,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(nhan, style: t.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Ví tín chỉ', style: t.titleLarge),
                const Spacer(),
                Text('1 tín chỉ = 1 t CO₂e', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [so('Đã cấp', du.daCap), so('Đã bán', du.daBan), so('Trong ví', du.trongVi, chinh: true)]),
            const Divider(height: 32),
            if (du.vi.isEmpty)
              Text('Ví hiện chưa có tín chỉ khả dụng.', style: t.bodyLarge)
            else ...[
              Text('Dải sê-ri đang nắm giữ', style: t.titleSmall),
              for (final k in du.vi)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(k.seriTu, style: const TextStyle(fontFamily: 'monospace', fontSize: 15)),
                  subtitle: Text('→ ${k.seriDen} · ${soVn(k.soLuong)} tín chỉ'),
                  trailing: const Icon(Icons.verified_outlined, color: mauChinh),
                  onTap: () => onTraSeri(k.seriTu),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BaoLoi extends StatelessWidget {
  const _BaoLoi(this.thongBao);
  final String thongBao;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: mauXauNhat, borderRadius: BorderRadius.circular(12)),
    child: Text(thongBao, style: const TextStyle(color: mauXau, fontSize: 16)),
  );
}
