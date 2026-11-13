// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Chi tiết cơ bản một lô đất: diện tích đo và khai báo, năm trồng, xã viên, các kỳ đo MRV (CO₂e, trạng thái, lý do lỗi,
// tín chỉ đã cấp). Chạm sê-ri để kiểm chứng trên sổ cái. Chỉ đọc; chạy MRV và duyệt vẫn làm trên web.
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../api/hop_tac_xa.dart';
import '../api/loi.dart';
import '../giao_dien.dart';

const _trangThai = {
  'cho_chay': 'Đang chờ chạy',
  'dang_chay': 'Đang đo từ vệ tinh',
  'cho_duyet': 'Chờ cán bộ duyệt',
  'da_duyet': 'Đã duyệt, đang ghi sổ',
  'da_ghi_so': 'Đã ghi sổ cái',
  'tu_choi': 'Bị từ chối',
  'loi': 'Lỗi khi đo',
};

class ManChiTietLo extends StatefulWidget {
  const ManChiTietLo({super.key, required this.lo, required this.api, required this.onTraSeri});

  final LoDat lo;
  final HopTacXaApi api;
  final void Function(String seri) onTraSeri;

  @override
  State<ManChiTietLo> createState() => _ManChiTietLoState();
}

class _ManChiTietLoState extends State<ManChiTietLo> {
  late Future<List<KetQuaMrv>> _ketQua = widget.api.ketQuaMrv(widget.lo.id);

  @override
  Widget build(BuildContext context) {
    final lo = widget.lo;
    final chu = context.chu;
    return FScaffold(
      childPad: false,
      header: SafeArea(
        bottom: false,
        child: FHeader.nested(
          title: Text(lo.ten),
          prefixes: [FHeaderAction.back(onPress: () => Navigator.of(context).maybePop())],
        ),
      ),
      child: RefreshIndicator(
        color: mauChinh,
        onRefresh: () async {
          final f = widget.api.ketQuaMrv(lo.id);
          setState(() => _ketQua = f);
          await f.catchError((_) => <KetQuaMrv>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            TheNoiDung(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: mauNhat, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(FLucideIcons.trees, color: mauChinh),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Diện tích đo trên bản đồ', style: chu.body.sm.copyWith(color: mauChuPhu)),
                            Text(
                              '${soVn(lo.dienTichHa, le: 2)} ha',
                              style: chu.display.xl.copyWith(fontWeight: FontWeight.w800, color: mauChu),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const FDivider(),
                  if (lo.dienTichKhaiBaoHa != null)
                    _Dong('Diện tích khai báo', '${soVn(lo.dienTichKhaiBaoHa!, le: 2)} ha'),
                  _Dong('Năm trồng', lo.namTrong?.toString() ?? 'Chưa khai'),
                  if (lo.xaVien != null) _Dong('Xã viên', lo.xaVien!),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Các kỳ đo carbon',
              style: chu.display.md.copyWith(fontWeight: FontWeight.w700, color: mauChu),
            ),
            const SizedBox(height: 10),
            FutureBuilder(
              future: _ketQua,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: FCircularProgress()),
                  );
                }
                if (s.hasError) {
                  final e = s.error;
                  return FAlert(
                    variant: .destructive,
                    title: const Text('Không tải được các kỳ đo'),
                    subtitle: Text(
                      e is LoiHetPhien ? 'Phiên đăng nhập đã hết hạn. Quay lại và đăng nhập lại.' : e.toString(),
                    ),
                  );
                }
                final ds = s.data!;
                if (ds.isEmpty) {
                  return TheNoiDung(
                    child: Text('Lô này chưa có kỳ đo nào.', style: chu.body.md.copyWith(color: mauChuPhu)),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final k in ds) ...[_TheKy(k: k, onTraSeri: widget.onTraSeri), const SizedBox(height: 10)],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong(this.nhan, this.giaTri);
  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(nhan, style: context.chu.body.md.copyWith(color: mauChuPhu)),
        ),
        Text(
          giaTri,
          style: context.chu.body.md.copyWith(fontWeight: FontWeight.w600, color: mauChu),
        ),
      ],
    ),
  );
}

class _TheKy extends StatelessWidget {
  const _TheKy({required this.k, required this.onTraSeri});

  final KetQuaMrv k;
  final void Function(String seri) onTraSeri;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    return TheNoiDung(
      mauVienThe: k.laLoi ? const Color(0xFFF2C4BF) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FLucideIcons.calendar, size: 18, color: mauChuPhu),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ngayVn(k.kyTu)} → ${ngayVn(k.kyDen)}',
                  style: chu.body.md.copyWith(fontWeight: FontWeight.w600, color: mauChu),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: NhanTrangThai(
              _trangThai[k.trangThai] ?? k.trangThai,
              xau: k.laLoi,
              icon: k.laLoi
                  ? FLucideIcons.triangleAlert
                  : (k.trangThai == 'da_ghi_so' ? FLucideIcons.circleCheck : FLucideIcons.clock),
            ),
          ),
          if (k.laLoi && k.lyDo != null) ...[
            const SizedBox(height: 8),
            Text(k.lyDo!, style: chu.body.sm.copyWith(color: mauXau)),
          ],
          if (k.co2eTan != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  soVn(k.co2eTan!, le: 2),
                  style: chu.display.xl3.copyWith(fontWeight: FontWeight.w800, color: mauChu, height: 1.1),
                ),
                const SizedBox(width: 6),
                Text(
                  't CO₂e',
                  style: chu.body.md.copyWith(color: mauChuPhu, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (k.dienTichTanHa != null)
              Text('Tán rừng ${soVn(k.dienTichTanHa!, le: 2)} ha', style: chu.body.sm.copyWith(color: mauChuPhu)),
          ],
          if (k.seriTu != null) ...[
            const SizedBox(height: 14),
            FButton(
              variant: .secondary,
              onPress: () => onTraSeri(k.seriTu!),
              prefix: const Icon(FLucideIcons.shieldCheck),
              child: Text('Đã cấp ${soVn(k.soTinChi ?? 0)} tín chỉ · Kiểm chứng'),
            ),
          ],
        ],
      ),
    );
  }
}
