// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Phản hồi giả của gateway cho kiểm thử (dữ liệu giả, cùng dạng với PostGraphile và /kiem-chung/api thật).
import 'dart:convert';

import 'package:carbonfarm/dang_nhap.dart';
import 'package:http/http.dart' as http;

const seriThat = 'MCK-DM01-26-0000000001';

http.Response json(Object body, [int ma = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  ma,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> banGhi(String loai, {bool khop = true, bool nguyenVen = true}) => {
  'loai': loai,
  'ma_doi_tuong': 'x',
  'commit': 'a' * 32,
  'luc': '2026-11-01 08:00:00',
  'sha256_so_cai': 'b' * 64,
  'sha256_tinh_lai': khop ? 'b' * 64 : 'c' * 64,
  'sha256_khop': khop,
  'con_nguyen_ven': nguyenVen,
  'du_lieu': loai == 'cap_tin_chi'
      ? {
          'so_luong_tin_chi': 15,
          'registry': {'seri_tu': seriThat, 'seri_den': 'MCK-DM01-26-0000000015'},
          'chu_so_huu': {'ten': 'HTX Mẫu'},
        }
      : {'co2e_tan': 15.85, 'dien_tich_tan_ha': 8.87},
};

Map<String, dynamic> seriToanVen() => {
  'so_seri': seriThat,
  'chu_so_huu_theo_so_cai': {'ten': 'HTX Mẫu', 'ma_so_thue': '0000000000'},
  'toan_ven': true,
  'su_kien': [banGhi('ket_qua_mrv'), banGhi('cap_tin_chi')],
};

Map<String, dynamic> tongQuanGraphql({bool rong = false}) => {
  'data': {
    'allCarbonHopTacXas': {
      'nodes': [
        {'ten': 'HTX Mẫu Đất Mũi'},
      ],
    },
    'allCarbonCanBoHtxes': {'totalCount': 1},
    'allCarbonLoDats': {
      'nodes': rong
          ? []
          : [
              {
                'rowId': '00000000-0000-4000-8000-00000000a002',
                'ten': 'Lô Đất Mũi 2',
                'dienTichHa': '8.8745',
                'dienTichKhaiBaoHa': '9',
                'namTrong': 2021,
                'carbonXaVienByXaVienId': {'hoTen': 'Xã viên Mẫu 2'},
              },
              {
                'rowId': '00000000-0000-4000-8000-00000000a001',
                'ten': 'Lô Đất Mũi 1',
                'dienTichHa': '8.8746',
                'dienTichKhaiBaoHa': null,
                'namTrong': null,
                'carbonXaVienByXaVienId': null,
              },
            ],
    },
    'allCarbonKhoiTinChis': {
      'nodes': rong
          ? []
          : [
              {'soLuong': 10, 'seriTu': 'MCK-DM01-26-0000000006', 'seriDen': 'MCK-DM01-26-0000000015'},
            ],
    },
    'allCarbonDeNghiCaps': {
      'nodes': rong
          ? []
          : [
              {'soLuong': 15},
              {'soLuong': 3},
            ],
    },
    'allCarbonLenhBans': {
      'nodes': rong
          ? []
          : [
              {'soLuong': 5},
              {'soLuong': 3},
            ],
    },
  },
};

/// Phiên đăng nhập giả: không mở trình duyệt, token cố định.
class PhienGia extends PhienDangNhap {
  PhienGia({bool daDangNhap = true})
    : _nd = daDangNhap ? const NguoiDung(ten: 'Cán bộ Mẫu', tenDangNhap: 'canbo') : null;

  NguoiDung? _nd;
  int soLanHuy = 0;

  @override
  NguoiDung? get nguoiDung => _nd;

  @override
  Future<void> khoiPhuc() async {}

  @override
  Future<void> dangNhap() async {
    _nd = const NguoiDung(ten: 'Cán bộ Mẫu', tenDangNhap: 'canbo');
    notifyListeners();
  }

  @override
  Future<void> dangXuat() => huyPhien();

  @override
  Future<String?> layToken() async => _nd == null ? null : 'token-gia';

  @override
  Future<void> huyPhien() async {
    soLanHuy++;
    _nd = null;
    notifyListeners();
  }
}
