// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Màn kiểm chứng CÔNG KHAI, không cần đăng nhập: gõ số sê-ri (hoặc mã băm commit Dolt) hoặc quét QR, xem kết luận toàn
// vẹn và chuỗi bản ghi sổ cái MRV → cấp → bán, mỗi bản ghi có SHA-256 lưu và SHA-256 tính lại. Giống trang /kiem-chung.
import 'dart:convert';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../api/kiem_chung.dart';
import '../giao_dien.dart';
import 'quet_qr.dart';

class ManKiemChung extends StatefulWidget {
  const ManKiemChung({super.key, required this.api, this.maBanDau, this.quetQr});

  final KiemChungApi api;

  /// Mở sẵn kết quả cho sê-ri này (khi chạm sê-ri trong ví).
  final String? maBanDau;

  /// Mở máy quét, trả nội dung mã QR; kiểm thử thay bằng hàm giả để không cần máy ảnh.
  final Future<String?> Function(BuildContext context)? quetQr;

  @override
  State<ManKiemChung> createState() => _ManKiemChungState();
}

class _ManKiemChungState extends State<ManKiemChung> {
  final _o = TextEditingController();
  KetQuaKiemChung? _kq;
  String? _loi;
  bool _dangTra = false;

  @override
  void initState() {
    super.initState();
    final ma = widget.maBanDau;
    if (ma != null) {
      _o.text = ma;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tra());
    }
  }

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  Future<void> _tra() async {
    final ma = chuanHoaMa(_o.text);
    if (ma.isEmpty) {
      setState(() => _loi = 'Hãy nhập số sê-ri tín chỉ, ví dụ MCK-DM01-26-0000000001.');
      return;
    }
    _o.text = ma;
    FocusScope.of(context).unfocus();
    setState(() {
      _dangTra = true;
      _loi = null;
      _kq = null;
    });
    try {
      final kq = await widget.api.tra(ma);
      if (mounted) setState(() => _kq = kq);
    } catch (e) {
      if (mounted) setState(() => _loi = e.toString());
    } finally {
      if (mounted) setState(() => _dangTra = false);
    }
  }

  Future<void> _quet() async {
    final quet =
        widget.quetQr ?? (ctx) => Navigator.of(ctx).push<String>(MaterialPageRoute(builder: (_) => const ManQuetQr()));
    final noiDung = await quet(context);
    if (noiDung == null || !mounted) return;
    _o.text = chuanHoaMa(noiDung);
    await _tra();
  }

  void _xoa() => setState(() {
    _o.clear();
    _kq = null;
    _loi = null;
  });

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    final kq = _kq;
    final coTroVe = Navigator.of(context).canPop();
    return FScaffold(
      childPad: false,
      header: SafeArea(
        bottom: false,
        child: coTroVe
            ? FHeader.nested(
                title: const Text('Kiểm chứng tín chỉ'),
                prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).maybePop())],
              )
            : FHeader(
                title: Text(
                  'Kiểm chứng tín chỉ',
                  style: chu.display.lg.copyWith(fontWeight: FontWeight.w700, color: mauChu),
                ),
              ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          TheNoiDung(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(FLucideIcons.shieldCheck, color: mauChinh, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tra một tín chỉ trên sổ cái công khai. Không cần tài khoản.',
                        style: chu.body.sm.copyWith(color: mauChuPhu),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FTextField(
                  key: const Key('o-seri'),
                  control: .managed(controller: _o),
                  label: const Text('Số sê-ri tín chỉ'),
                  hint: 'MCK-DM01-26-0000000001',
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: .characters,
                  textInputAction: .search,
                  onSubmit: (_) => _tra(),
                  suffixBuilder: (context, style, variants) => IconButton(
                    key: const Key('nut-xoa'),
                    tooltip: 'Xóa',
                    icon: const Icon(FLucideIcons.x, size: 18, color: mauChuPhu),
                    onPressed: _xoa,
                  ),
                ),
                const SizedBox(height: 14),
                FButton(
                  key: const Key('nut-tra'),
                  onPress: _dangTra ? null : _tra,
                  prefix: _dangTra ? const FCircularProgress() : const Icon(FLucideIcons.search),
                  child: Text(_dangTra ? 'Đang đối chiếu sổ cái…' : 'Kiểm chứng'),
                ),
                const SizedBox(height: 10),
                FButton(
                  key: const Key('nut-quet'),
                  variant: .outline,
                  onPress: _dangTra ? null : _quet,
                  prefix: const Icon(FLucideIcons.scanQrCode),
                  child: const Text('Quét mã QR'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_loi != null)
            _KetLuan(
              icon: FLucideIcons.triangleAlert,
              tieuDe: 'Chưa tra được',
              noiDung: _loi!,
              mau: mauXau,
              nen: mauXauNhat,
            ),
          if (kq is KhongThay)
            _KetLuan(
              icon: FLucideIcons.searchX,
              tieuDe: 'Không có bản ghi.',
              noiDung: '${kq.thongBao}. Kiểm tra lại số sê-ri; tín chỉ chưa được cấp sẽ không có trên sổ cái.',
              mau: mauChu,
              nen: Colors.white,
              vien: mauVien,
            ),
          if (kq is TimThay) ...[
            _ketLuanTimThay(kq),
            const SizedBox(height: 22),
            Text(
              'Chuỗi bản ghi trên sổ cái (${kq.banGhi.length})',
              style: chu.display.md.copyWith(fontWeight: FontWeight.w700, color: mauChu),
            ),
            const SizedBox(height: 4),
            Text(
              'Mỗi bản ghi được băm lại từ JSON gốc (định danh người dùng đã ẩn).',
              style: chu.body.sm.copyWith(color: mauChuPhu),
            ),
            const SizedBox(height: 12),
            for (final (i, b) in kq.banGhi.indexed) _BuocSoCai(stt: i + 1, b: b, cuoi: i == kq.banGhi.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _ketLuanTimThay(TimThay kq) {
    final ok = kq.toanVen;
    final dem = '${kq.banGhi.where((b) => b.hopLe).length}/${kq.banGhi.length} bản ghi khớp SHA-256';
    return _KetLuan(
      icon: ok ? FLucideIcons.badgeCheck : FLucideIcons.circleX,
      tieuDe: ok ? 'Toàn vẹn.' : 'Có bản ghi không khớp.',
      noiDung: kq.laSeri
          ? 'Tín chỉ ${kq.ma} hiện thuộc ${kq.chuSoHuu ?? 'chưa rõ chủ sở hữu'}. $dem.'
          : 'Commit ${kq.ma}${kq.moTa != null ? ': ${kq.moTa}' : ''}. $dem.',
      mau: ok ? Colors.white : mauXau,
      nen: ok ? mauChinh : mauXauNhat,
      vien: ok ? mauChinh : const Color(0xFFF2C4BF),
      mauChuPhu: ok ? const Color(0xE6FFFFFF) : null,
    );
  }
}

/// Khối kết luận lớn: hợp lệ (nền xanh đậm), sai lệch hoặc lỗi (nền đỏ nhạt), không có bản ghi (nền trắng).
class _KetLuan extends StatelessWidget {
  const _KetLuan({
    required this.icon,
    required this.tieuDe,
    required this.noiDung,
    required this.mau,
    required this.nen,
    this.vien,
    this.mauChuPhu,
  });

  final IconData icon;
  final String tieuDe;
  final String noiDung;
  final Color mau;
  final Color nen;
  final Color? vien;
  final Color? mauChuPhu;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: nen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: vien ?? mau.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mau, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tieuDe,
                  style: chu.display.xl.copyWith(color: mau, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(giuSeriLien(noiDung), style: chu.body.md.copyWith(color: mauChuPhu ?? mau, height: 1.45)),
        ],
      ),
    );
  }
}

/// Một bước trong chuỗi sổ cái, dạng dòng thời gian; chạm để xem mã băm và bản ghi gốc.
class _BuocSoCai extends StatefulWidget {
  const _BuocSoCai({required this.stt, required this.b, required this.cuoi});

  final int stt;
  final BanGhiSoCai b;
  final bool cuoi;

  @override
  State<_BuocSoCai> createState() => _BuocSoCaiState();
}

class _BuocSoCaiState extends State<_BuocSoCai> {
  bool _mo = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final chu = context.chu;
    final nhan = b.hopLe ? 'SHA-256 khớp · Nguyên vẹn' : (b.sha256Khop ? 'Đã bị sửa sau' : 'SHA-256 không khớp');
    final mono = chu.body.xs.copyWith(fontFamily: 'monospace', color: mauChu);
    Widget nhanNho(String s) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        s,
        style: chu.body.xs.copyWith(color: mauChuPhu, fontWeight: FontWeight.w600),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.hopLe ? mauChinh : mauXau, shape: BoxShape.circle),
                  child: Text(
                    '${widget.stt}',
                    style: chu.body.sm.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                if (!widget.cuoi) Expanded(child: Container(width: 2, color: mauVien)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _mo = !_mo),
                  child: TheNoiDung(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Bước ${widget.stt} · ${b.tenLoai}',
                                style: chu.body.md.copyWith(fontWeight: FontWeight.w700, color: mauChu),
                              ),
                            ),
                            Icon(_mo ? FLucideIcons.chevronUp : FLucideIcons.chevronDown, color: mauChuPhu, size: 20),
                          ],
                        ),
                        if (b.tomTat.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(b.tomTat, style: chu.body.sm.copyWith(color: mauChuPhu)),
                        ],
                        const SizedBox(height: 10),
                        NhanTrangThai(
                          nhan,
                          xau: !b.hopLe,
                          icon: b.hopLe ? FLucideIcons.circleCheck : FLucideIcons.circleX,
                        ),
                        if (_mo) ...[
                          const SizedBox(height: 6),
                          nhanNho('Thời điểm ghi sổ'),
                          Text(b.luc, style: chu.body.sm.copyWith(color: mauChu)),
                          nhanNho('Commit Dolt'),
                          SelectableText(b.commit, style: mono),
                          nhanNho('SHA-256 lưu trong sổ cái'),
                          SelectableText(b.sha256SoCai, style: mono),
                          nhanNho('SHA-256 tính lại'),
                          SelectableText(b.sha256TinhLai, style: mono),
                          nhanNho('Bản ghi gốc'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: mauNen, borderRadius: BorderRadius.circular(12)),
                            child: SelectableText(const JsonEncoder.withIndent('  ').convert(b.duLieu), style: mono),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
