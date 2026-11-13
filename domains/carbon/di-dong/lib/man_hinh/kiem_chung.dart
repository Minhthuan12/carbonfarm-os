// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Màn kiểm chứng CÔNG KHAI, không cần đăng nhập: gõ số sê-ri (hoặc mã băm commit Dolt) hoặc quét QR, xem kết luận toàn
// vẹn và chuỗi bản ghi sổ cái MRV → cấp → bán, mỗi bản ghi có SHA-256 lưu và SHA-256 tính lại. Giống trang /kiem-chung.
import 'dart:convert';

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kq = _kq;
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm chứng tín chỉ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Tra một tín chỉ trên sổ cái công khai. Không cần tài khoản.', style: t.bodyLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('o-seri'),
            controller: _o,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _tra(),
            style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Số sê-ri tín chỉ',
              hintText: 'MCK-DM01-26-0000000001',
              suffixIcon: IconButton(
                key: const Key('nut-xoa'),
                tooltip: 'Xóa',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _o.clear();
                  _kq = null;
                  _loi = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('nut-tra'),
            onPressed: _dangTra ? null : _tra,
            icon: const Icon(Icons.search),
            label: Text(_dangTra ? 'Đang đối chiếu sổ cái…' : 'Kiểm chứng'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('nut-quet'),
            onPressed: _dangTra ? null : _quet,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Quét mã QR'),
          ),
          const SizedBox(height: 24),
          if (_dangTra) const Center(child: CircularProgressIndicator()),
          if (_loi != null) _KhungKetLuan.loi(_loi!),
          if (kq is KhongThay) _KhungKetLuan.khongThay(kq.thongBao),
          if (kq is TimThay) ...[
            _KhungKetLuan.timThay(kq),
            const SizedBox(height: 24),
            Text('Chuỗi bản ghi trên sổ cái (${kq.banGhi.length})', style: t.titleLarge),
            const SizedBox(height: 4),
            Text('Mỗi bản ghi được băm lại từ JSON gốc (định danh người dùng đã ẩn).', style: t.bodyMedium),
            const SizedBox(height: 12),
            for (final (i, b) in kq.banGhi.indexed) ...[_TheBanGhi(stt: i + 1, b: b), const SizedBox(height: 12)],
          ],
        ],
      ),
    );
  }
}

class _KhungKetLuan extends StatelessWidget {
  const _KhungKetLuan({required this.mau, required this.nen, required this.icon, required this.tieuDe, this.noiDung});

  factory _KhungKetLuan.loi(String thongBao) => _KhungKetLuan(
    mau: mauXau,
    nen: mauXauNhat,
    icon: Icons.error_outline,
    tieuDe: 'Chưa tra được',
    noiDung: thongBao,
  );

  factory _KhungKetLuan.khongThay(String thongBao) => _KhungKetLuan(
    mau: const Color(0xFF16201D),
    nen: Colors.white,
    icon: Icons.search_off,
    tieuDe: 'Không có bản ghi.',
    noiDung: '$thongBao. Kiểm tra lại số sê-ri; tín chỉ chưa được cấp sẽ không có trên sổ cái.',
  );

  factory _KhungKetLuan.timThay(TimThay kq) {
    final ok = kq.toanVen;
    final dem = '${kq.banGhi.where((b) => b.hopLe).length}/${kq.banGhi.length} bản ghi khớp SHA-256';
    return _KhungKetLuan(
      mau: ok ? mauChinhDam : mauXau,
      nen: ok ? mauNhat : mauXauNhat,
      icon: ok ? Icons.verified : Icons.warning_amber,
      tieuDe: ok ? 'Toàn vẹn.' : 'Có bản ghi không khớp.',
      noiDung: kq.laSeri
          ? 'Tín chỉ ${kq.ma} hiện thuộc ${kq.chuSoHuu ?? 'chưa rõ chủ sở hữu'}. $dem.'
          : 'Commit ${kq.ma}${kq.moTa != null ? ': ${kq.moTa}' : ''}. $dem.',
    );
  }

  final Color mau;
  final Color nen;
  final IconData icon;
  final String tieuDe;
  final String? noiDung;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: nen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mau.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: mau, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: t.headlineSmall?.copyWith(color: mau, fontWeight: FontWeight.w700),
                ),
                if (noiDung != null) ...[const SizedBox(height: 6), Text(noiDung!, style: t.bodyLarge)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TheBanGhi extends StatelessWidget {
  const _TheBanGhi({required this.stt, required this.b});

  final int stt;
  final BanGhiSoCai b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nhan = b.hopLe ? 'SHA-256 khớp · Nguyên vẹn' : (b.sha256Khop ? 'Đã bị sửa sau' : 'SHA-256 không khớp');
    final mono = t.bodySmall?.copyWith(fontFamily: 'monospace');
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('Bước $stt · ${b.tenLoai}', style: t.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.tomTat.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(b.tomTat)),
              const SizedBox(height: 6),
              Text(
                nhan,
                style: TextStyle(color: b.hopLe ? mauChinh : mauXau, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          children: [
            Text('Thời điểm ghi sổ: ${b.luc}', style: t.bodyMedium),
            const SizedBox(height: 8),
            Text('Commit Dolt', style: t.labelLarge),
            SelectableText(b.commit, style: mono),
            const SizedBox(height: 8),
            Text('SHA-256 lưu trong sổ cái', style: t.labelLarge),
            SelectableText(b.sha256SoCai, style: mono),
            const SizedBox(height: 8),
            Text('SHA-256 tính lại', style: t.labelLarge),
            SelectableText(b.sha256TinhLai, style: mono),
            const SizedBox(height: 8),
            Text('Bản ghi gốc', style: t.labelLarge),
            SelectableText(const JsonEncoder.withIndent('  ').convert(b.duLieu), style: mono),
          ],
        ),
      ),
    );
  }
}
