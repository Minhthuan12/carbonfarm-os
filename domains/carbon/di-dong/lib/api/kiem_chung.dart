// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// API kiểm chứng CÔNG KHAI (/kiem-chung/api, chỉ GET, không cần đăng nhập): tra số sê-ri tín chỉ hoặc mã băm commit Dolt,
// nhận chuỗi bản ghi sổ cái kèm SHA-256 lưu và SHA-256 tính lại. App chỉ hiển thị kết luận do API trả về.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../dinh_dang.dart';
import 'loi.dart';

class BanGhiSoCai {
  const BanGhiSoCai({
    required this.loai,
    required this.commit,
    required this.luc,
    required this.sha256SoCai,
    required this.sha256TinhLai,
    required this.sha256Khop,
    required this.conNguyenVen,
    required this.duLieu,
  });

  factory BanGhiSoCai.tuJson(Map<String, dynamic> j) => BanGhiSoCai(
    loai: j['loai'] as String,
    commit: j['commit'] as String,
    luc: j['luc'] as String,
    sha256SoCai: j['sha256_so_cai'] as String,
    sha256TinhLai: j['sha256_tinh_lai'] as String,
    sha256Khop: j['sha256_khop'] as bool,
    conNguyenVen: j['con_nguyen_ven'] as bool,
    duLieu: (j['du_lieu'] as Map?)?.cast<String, dynamic>() ?? const {},
  );

  final String loai;
  final String commit;
  final String luc;
  final String sha256SoCai;
  final String sha256TinhLai;
  final bool sha256Khop;

  /// false: bản ghi đã bị sửa sau khi ghi sổ (SHA-256 hiện tại khác lúc ghi).
  final bool conNguyenVen;
  final Map<String, dynamic> duLieu;

  bool get hopLe => sha256Khop && conNguyenVen;

  String get tenLoai => switch (loai) {
    'ket_qua_mrv' => 'Đo từ vệ tinh, cán bộ đã duyệt',
    'cap_tin_chi' => 'Registry cấp tín chỉ',
    'ban_tin_chi' => 'Bán, chuyển quyền sở hữu',
    _ => loai,
  };

  /// Một dòng tóm tắt nội dung, giống trang /kiem-chung trên web.
  String get tomTat {
    final d = duLieu;
    Map? m(String k) => d[k] as Map?;
    return switch (loai) {
      'ket_qua_mrv' => '${soVnTuJson(d['co2e_tan'])} t CO₂e · tán ${soVnTuJson(d['dien_tich_tan_ha'])} ha',
      'cap_tin_chi' =>
        '${d['so_luong_tin_chi']} tín chỉ ${m('registry')?['seri_tu']} → ${m('registry')?['seri_den']} cho ${m('chu_so_huu')?['ten']}',
      'ban_tin_chi' => '${d['so_luong']} tín chỉ: ${m('ben_ban')?['ten']} → ${m('ben_mua')?['ten']}',
      _ => '',
    };
  }
}

sealed class KetQuaKiemChung {
  const KetQuaKiemChung();
}

/// Sổ cái có mã cần tra.
class TimThay extends KetQuaKiemChung {
  const TimThay({required this.ma, required this.laSeri, required this.banGhi, this.chuSoHuu, this.moTa});

  final String ma;
  final bool laSeri;
  final List<BanGhiSoCai> banGhi;

  /// Chủ sở hữu hiện tại theo sổ cái (chỉ khi tra sê-ri).
  final String? chuSoHuu;

  /// Thông điệp commit (chỉ khi tra commit).
  final String? moTa;

  bool get toanVen => banGhi.isNotEmpty && banGhi.every((b) => b.hopLe);
}

/// Sổ cái không có bản ghi cho mã này (404), ví dụ sê-ri giả hoặc chưa được cấp.
class KhongThay extends KetQuaKiemChung {
  const KhongThay(this.thongBao);
  final String thongBao;
}

/// Lấy mã cần tra từ nội dung gõ tay hoặc mã QR (có thể là đường link .../kiem-chung?q=...).
String chuanHoaMa(String vao) {
  final s = vao.trim();
  final uri = Uri.tryParse(s);
  if (uri != null && uri.hasScheme && uri.queryParameters['q'] != null) return uri.queryParameters['q']!.trim();
  return s;
}

class KiemChungApi {
  KiemChungApi({required this.goc, http.Client? client}) : _http = client ?? http.Client();

  final String goc;
  final http.Client _http;

  Future<KetQuaKiemChung> tra(String vao) async {
    final ma = chuanHoaMa(vao);
    if (ma.isEmpty) throw const LoiMayChu('Hãy nhập số sê-ri tín chỉ.');
    final laSeri = ma.contains('-');
    final http.Response res;
    try {
      res = await _http
          .get(Uri.parse('$goc/kiem-chung/api/${laSeri ? 'seri' : 'commit'}/${Uri.encodeComponent(ma)}'))
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const LoiMang();
    } on TimeoutException {
      throw const LoiMang();
    } on http.ClientException {
      throw const LoiMang();
    }
    Map<String, dynamic>? j;
    if ((res.headers['content-type'] ?? '').contains('application/json')) {
      try {
        j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>?;
      } on FormatException {
        j = null;
      }
    }
    if (res.statusCode == 404) {
      return KhongThay(j?['loi'] as String? ?? 'Sổ cái không có ${laSeri ? 'tín chỉ' : 'commit'} $ma');
    }
    if (res.statusCode == 429) throw const LoiMayChu('Tra quá nhiều lần. Hãy thử lại sau một phút.');
    if (res.statusCode >= 400 && res.statusCode < 500) {
      throw LoiMayChu(j?['loi'] as String? ?? 'Mã tra cứu không hợp lệ (mã ${res.statusCode}).');
    }
    if (res.statusCode != 200 || j == null) {
      throw LoiMayChu('Không đọc được sổ cái lúc này (máy chủ trả mã ${res.statusCode}). Hãy thử lại sau.');
    }
    final ds = ((laSeri ? j['su_kien'] : j['ban_ghi']) as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(BanGhiSoCai.tuJson)
        .toList();
    return TimThay(
      ma: laSeri ? j['so_seri'] as String : j['commit'] as String,
      laSeri: laSeri,
      banGhi: ds,
      chuSoHuu: (j['chu_so_huu_theo_so_cai'] as Map?)?['ten'] as String?,
      moTa: j['thong_diep'] as String?,
    );
  }
}
