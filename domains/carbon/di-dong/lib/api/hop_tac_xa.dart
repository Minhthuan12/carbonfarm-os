// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Dữ liệu hợp tác xã cho màn "Hợp tác xã": lô đất đang hoạt động, ví tín chỉ (đã cấp, đã bán, đang trong ví) và kết quả
// MRV của một lô. Chỉ đọc; các thao tác ghi (đăng ký lô, duyệt, bán) vẫn ở web.
import 'graphql.dart';

class LoDat {
  const LoDat({
    required this.id,
    required this.ten,
    required this.dienTichHa,
    this.dienTichKhaiBaoHa,
    this.namTrong,
    this.xaVien,
  });

  factory LoDat.tuJson(Map<String, dynamic> j) => LoDat(
    id: j['rowId'] as String,
    ten: j['ten'] as String,
    dienTichHa: _so(j['dienTichHa']),
    dienTichKhaiBaoHa: j['dienTichKhaiBaoHa'] == null ? null : _so(j['dienTichKhaiBaoHa']),
    namTrong: j['namTrong'] as int?,
    xaVien: (j['carbonXaVienByXaVienId'] as Map?)?['hoTen'] as String?,
  );

  final String id;
  final String ten;
  final double dienTichHa;
  final double? dienTichKhaiBaoHa;
  final int? namTrong;
  final String? xaVien;
}

class KhoiTinChi {
  const KhoiTinChi({required this.soLuong, required this.seriTu, required this.seriDen});

  factory KhoiTinChi.tuJson(Map<String, dynamic> j) =>
      KhoiTinChi(soLuong: j['soLuong'] as int, seriTu: j['seriTu'] as String, seriDen: j['seriDen'] as String);

  final int soLuong;
  final String seriTu;
  final String seriDen;
}

class TongQuanHtx {
  const TongQuanHtx({
    required this.tenHtx,
    required this.laCanBo,
    required this.lo,
    required this.vi,
    required this.daCap,
    required this.daBan,
  });

  final String tenHtx;
  final bool laCanBo;
  final List<LoDat> lo;
  final List<KhoiTinChi> vi;

  /// Tổng tín chỉ Registry đã cấp cho hợp tác xã (đề nghị cấp ở trạng thái "da_cap").
  final int daCap;

  /// Tổng tín chỉ đã bán xong (lệnh bán "hoan_tat").
  final int daBan;

  /// Tín chỉ đang nắm giữ = tổng các khối sê-ri trong ví.
  int get trongVi => vi.fold(0, (t, k) => t + k.soLuong);
}

class KetQuaMrv {
  const KetQuaMrv({
    required this.kyTu,
    required this.kyDen,
    required this.trangThai,
    this.co2eTan,
    this.dienTichTanHa,
    this.seriTu,
    this.soTinChi,
  });

  factory KetQuaMrv.tuJson(Map<String, dynamic> j) {
    final cap = j['carbonDeNghiCapByKetQuaMrvId'] as Map<String, dynamic>?;
    final daCap = cap?['trangThai'] == 'da_cap';
    return KetQuaMrv(
      kyTu: j['kyTu'] as String,
      kyDen: j['kyDen'] as String,
      trangThai: j['trangThai'] as String,
      co2eTan: j['co2ETan'] == null ? null : _so(j['co2ETan']),
      dienTichTanHa: j['dienTichTanHa'] == null ? null : _so(j['dienTichTanHa']),
      seriTu: daCap ? cap!['seriTu'] as String? : null,
      soTinChi: daCap ? cap!['soLuong'] as int? : null,
    );
  }

  final String kyTu;
  final String kyDen;
  final String trangThai;
  final double? co2eTan;
  final double? dienTichTanHa;

  /// Sê-ri đầu tiên nếu kết quả này đã được cấp tín chỉ (để mở màn kiểm chứng).
  final String? seriTu;
  final int? soTinChi;
}

/// PostGraphile trả numeric dạng chuỗi (BigFloat), số nguyên dạng số.
double _so(Object? v) => v is num ? v.toDouble() : double.parse(v as String);

const _truyVanTongQuan = '''
{
  allCarbonHopTacXas { nodes { ten } }
  allCarbonCanBoHtxes { totalCount }
  allCarbonLoDats(condition: { trangThai: "hoat_dong" }) {
    nodes { rowId ten dienTichHa dienTichKhaiBaoHa namTrong carbonXaVienByXaVienId { hoTen } }
  }
  allCarbonKhoiTinChis { nodes { soLuong seriTu seriDen } }
  allCarbonDeNghiCaps(condition: { trangThai: "da_cap" }) { nodes { soLuong } }
  allCarbonLenhBans(condition: { trangThai: "hoan_tat" }) { nodes { soLuong } }
}''';

const _truyVanLo = r'''
query($lo: UUID!) {
  allCarbonKetQuaMrvs(condition: { loDatId: $lo }) {
    nodes { kyTu kyDen trangThai co2ETan dienTichTanHa carbonDeNghiCapByKetQuaMrvId { trangThai soLuong seriTu } }
  }
}''';

class HopTacXaApi {
  HopTacXaApi(this._gql);
  final GraphqlClient _gql;

  Future<TongQuanHtx> tongQuan() async {
    final d = await _gql.truyVan(_truyVanTongQuan);
    List<Map<String, dynamic>> nodes(String k) => ((d[k] as Map)['nodes'] as List).cast<Map<String, dynamic>>();
    int tong(String k) => nodes(k).fold(0, (t, n) => t + (n['soLuong'] as int));

    final lo = nodes('allCarbonLoDats').map(LoDat.tuJson).toList()..sort((a, b) => a.ten.compareTo(b.ten));
    final vi = nodes('allCarbonKhoiTinChis').map(KhoiTinChi.tuJson).toList()
      ..sort((a, b) => a.seriTu.compareTo(b.seriTu));
    return TongQuanHtx(
      tenHtx: nodes('allCarbonHopTacXas').map((h) => h['ten'] as String).join(', '),
      laCanBo: ((d['allCarbonCanBoHtxes'] as Map)['totalCount'] as int) > 0,
      lo: lo,
      vi: vi,
      daCap: tong('allCarbonDeNghiCaps'),
      daBan: tong('allCarbonLenhBans'),
    );
  }

  Future<List<KetQuaMrv>> ketQuaMrv(String loId) async {
    final d = await _gql.truyVan(_truyVanLo, {'lo': loId});
    final ds =
        ((d['allCarbonKetQuaMrvs'] as Map)['nodes'] as List).cast<Map<String, dynamic>>().map(KetQuaMrv.tuJson).toList()
          ..sort((a, b) => b.kyTu.compareTo(a.kyTu));
    return ds;
  }
}
