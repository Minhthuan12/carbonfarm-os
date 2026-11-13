// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Hợp tác xã với HTTP giả: GraphQL (ví, lô đất, kết quả MRV, lỗi 401/mạng/nghiệp vụ) và màn hợp tác xã.
import 'dart:convert';
import 'dart:io';

import 'package:carbonfarm/api/graphql.dart';
import 'package:carbonfarm/api/hop_tac_xa.dart';
import 'package:carbonfarm/api/kiem_chung.dart';
import 'package:carbonfarm/api/loi.dart';
import 'package:carbonfarm/giao_dien.dart';
import 'package:carbonfarm/man_hinh/chi_tiet_lo.dart';
import 'package:carbonfarm/man_hinh/hop_tac_xa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'du_lieu_gia.dart';

const goc = 'https://gateway.test';

Widget boc(Widget w) => MaterialApp(theme: giaoDien(), home: w);

HopTacXaApi htx(MockClientHandler xuLy, {String? token = 'tk'}) =>
    HopTacXaApi(GraphqlClient(goc: goc, layToken: () async => token, client: MockClient(xuLy)));

/// Bốn kỳ đo của một lô: đã cấp tín chỉ, lỗi do mây (lý do kèm danh sách cảnh kỹ thuật), đang đo (nội dung ngắn,
/// từng làm thẻ co hẹp), bị cán bộ từ chối.
Map<String, dynamic> kyDoGia() => {
  'data': {
    'allCarbonKetQuaMrvs': {
      'nodes': [
        {
          'kyTu': '2026-04-01',
          'kyDen': '2026-04-30',
          'trangThai': 'da_ghi_so',
          'co2ETan': '15.854',
          'dienTichTanHa': '8.87',
          'lyDoLoi': null,
          'ghiChuDuyet': 'Khớp ảnh thực địa',
          'carbonDeNghiCapByKetQuaMrvId': {'trangThai': 'da_cap', 'soLuong': 15, 'seriTu': seriThat},
        },
        {
          'kyTu': '2026-10-01',
          'kyDen': '2026-10-31',
          'trangThai': 'loi',
          'co2ETan': null,
          'dienTichTanHa': null,
          'lyDoLoi': "Không có cảnh nào đủ 80% điểm ảnh hợp lệ trong kỳ (đã thử [{'canh_id': 'S2C_T48PVQ', 'ti_le_hop_le': 0.1778}])",
          'ghiChuDuyet': null,
          'carbonDeNghiCapByKetQuaMrvId': null,
        },
        {
          'kyTu': '2026-06-01',
          'kyDen': '2026-06-30',
          'trangThai': 'dang_chay',
          'co2ETan': null,
          'dienTichTanHa': null,
          'lyDoLoi': null,
          'ghiChuDuyet': null,
          'carbonDeNghiCapByKetQuaMrvId': null,
        },
        {
          'kyTu': '2026-05-01',
          'kyDen': '2026-05-31',
          'trangThai': 'tu_choi',
          'co2ETan': '3.1',
          'dienTichTanHa': '2.0',
          'lyDoLoi': null,
          'ghiChuDuyet': 'Ranh giới lô cần vẽ lại',
          'carbonDeNghiCapByKetQuaMrvId': null,
        },
      ],
    },
  },
};

void main() {
  group('GraphQL hợp tác xã', () {
    test('gửi token, cộng đã cấp / đã bán / trong ví, sắp lô theo tên', () async {
      late http.Request yeuCau;
      final kq = await htx((r) async {
        yeuCau = r;
        return json(tongQuanGraphql());
      }).tongQuan();

      expect(yeuCau.url.toString(), '$goc/graphql');
      expect(yeuCau.headers['Authorization'], 'Bearer tk');
      expect(jsonDecode(yeuCau.body)['query'], contains('allCarbonLoDats'));
      expect(kq.tenHtx, 'HTX Mẫu Đất Mũi');
      expect(kq.laCanBo, isTrue);
      expect((kq.daCap, kq.daBan, kq.trongVi), (18, 8, 10));
      expect(kq.lo.map((l) => l.ten), ['Lô Đất Mũi 1', 'Lô Đất Mũi 2']);
      expect(kq.lo.last.dienTichHa, 8.8745, reason: 'numeric của PostGraphile là chuỗi');
      expect(kq.lo.last.xaVien, 'Xã viên Mẫu 2');
      expect(kq.lo.first.namTrong, isNull);
    });

    test('HTX chưa có gì: danh sách rỗng, tổng bằng 0', () async {
      final kq = await htx((_) async => json(tongQuanGraphql(rong: true))).tongQuan();
      expect(kq.lo, isEmpty);
      expect((kq.daCap, kq.daBan, kq.trongVi), (0, 0, 0));
    });

    test('401 → LoiHetPhien', () {
      expect(htx((_) async => http.Response('', 401)).tongQuan(), throwsA(isA<LoiHetPhien>()));
    });

    test('chưa có token → LoiHetPhien, không gọi mạng', () async {
      var daGoi = false;
      final f = htx((_) async {
        daGoi = true;
        return json({});
      }, token: null).tongQuan();
      await expectLater(f, throwsA(isA<LoiHetPhien>()));
      expect(daGoi, isFalse);
    });

    test('mất mạng → LoiMang', () {
      expect(htx((_) async => throw const SocketException('mất mạng')).tongQuan(), throwsA(isA<LoiMang>()));
    });

    test('lỗi nghiệp vụ mã U… giữ nguyên thông báo tiếng Việt; lỗi khác bị che', () async {
      await expectLater(
        htx(
          (_) async => json({
            'errors': [
              {
                'message': 'Không có quyền',
                'extensions': {'code': 'UC011'},
              },
            ],
          }),
        ).tongQuan(),
        throwsA(isA<LoiMayChu>().having((e) => e.ma, 'ma', 'UC011').having((e) => e.thongBao, 'tb', 'Không có quyền')),
      );
      await expectLater(
        htx(
          (_) async => json({
            'errors': [
              {
                'message': 'relation "x" does not exist',
                'extensions': {'code': '42P01'},
              },
            ],
          }),
        ).tongQuan(),
        throwsA(isA<LoiMayChu>().having((e) => e.thongBao, 'tb', 'Máy chủ từ chối yêu cầu.')),
      );
    });

    test('kết quả MRV của lô: mới nhất trước, chỉ lấy sê-ri khi đã cấp', () async {
      late Map<String, dynamic> bien;
      final ds = await htx((r) async {
        bien = jsonDecode(r.body)['variables'] as Map<String, dynamic>;
        return json({
          'data': {
            'allCarbonKetQuaMrvs': {
              'nodes': [
                {
                  'kyTu': '2026-03-01',
                  'kyDen': '2026-03-31',
                  'trangThai': 'da_ghi_so',
                  'co2ETan': '15.854',
                  'dienTichTanHa': '8.87',
                  'carbonDeNghiCapByKetQuaMrvId': {'trangThai': 'da_cap', 'soLuong': 15, 'seriTu': seriThat},
                },
                {
                  'kyTu': '2026-04-01',
                  'kyDen': '2026-04-30',
                  'trangThai': 'cho_duyet',
                  'co2ETan': null,
                  'dienTichTanHa': null,
                  'carbonDeNghiCapByKetQuaMrvId': {'trangThai': 'cho_dang_ky', 'soLuong': 15, 'seriTu': null},
                },
              ],
            },
          },
        });
      }).ketQuaMrv('lo-1');
      expect(bien, {'lo': 'lo-1'});
      expect(ds.map((k) => k.kyTu), ['2026-04-01', '2026-03-01']);
      expect(ds.first.seriTu, isNull);
      expect(ds.last.seriTu, seriThat);
      expect(ds.last.co2eTan, closeTo(15.854, 1e-9));
    });

    test('lý do: lỗi lấy lyDoLoi (bỏ phần kỹ thuật), từ chối lấy ghi chú duyệt, kỳ bình thường không có', () async {
      late String query;
      final ds = await htx((r) async {
        query = jsonDecode(r.body)['query'] as String;
        return json(kyDoGia());
      }).ketQuaMrv('lo-2');
      expect(query, allOf(contains('lyDoLoi'), contains('ghiChuDuyet')));
      final theoKy = {for (final k in ds) k.kyTu: k};
      expect(theoKy['2026-10-01']!.laLoi, isTrue);
      expect(theoKy['2026-10-01']!.lyDo, 'Không có cảnh nào đủ 80% điểm ảnh hợp lệ trong kỳ');
      expect(theoKy['2026-05-01']!.lyDo, 'Ranh giới lô cần vẽ lại');
      expect(theoKy['2026-04-01']!.laLoi, isFalse);
      expect(theoKy['2026-04-01']!.lyDo, isNull, reason: 'ghi chú duyệt của kỳ đã ghi sổ không phải lý do lỗi');
    });
  });

  test('ngày ISO hiển thị dd/mm/yyyy', () {
    expect(ngayVn('2026-04-01'), '01/04/2026');
    expect(ngayVn('2026-10-31T00:00:00+07:00'), '31/10/2026');
    expect(ngayVn('không phải ngày'), 'không phải ngày');
  });

  group('Màn chi tiết lô', () {
    const lo = LoDat(id: 'lo-2', ten: 'Lô Đất Mũi 2', dienTichHa: 8.8745, dienTichKhaiBaoHa: 8.9, namTrong: 2021);
    Widget man() => boc(ManChiTietLo(lo: lo, api: htx((_) async => json(kyDoGia())), onTraSeri: (_) {}));

    testWidgets('ngày dd/mm/yyyy; kỳ lỗi màu lỗi kèm lý do; các thẻ kỳ đo cùng chiều rộng', (t) async {
      // Màn rộng: font thử (Ahem) vẽ chữ rất to, màn hẹp thì thẻ nào cũng bị chữ đẩy ra hết chiều rộng
      await t.binding.setSurfaceSize(const Size(1000, 2000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(man());
      await t.pumpAndSettle();

      expect(find.text('01/10/2026 → 31/10/2026'), findsOneWidget);
      expect(find.text('01/04/2026 → 30/04/2026'), findsOneWidget);
      expect(find.textContaining('2026-'), findsNothing, reason: 'không còn ngày dạng ISO');

      final loi = t.widget<Text>(find.text('Lỗi khi đo'));
      expect(loi.style?.color, mauXau);
      expect(find.text('Không có cảnh nào đủ 80% điểm ảnh hợp lệ trong kỳ'), findsOneWidget);
      expect(find.textContaining('canh_id'), findsNothing);
      expect(t.widget<Text>(find.text('Bị từ chối')).style?.color, mauXau);
      expect(find.text('Ranh giới lô cần vẽ lại'), findsOneWidget);
      expect(t.widget<Text>(find.text('Đã ghi sổ cái')).style?.color, mauChinhDam);
      expect(find.text('Khớp ảnh thực địa'), findsNothing);

      final rong = find.byType(Card).evaluate().map((e) => e.size!.width).toList();
      expect(rong.toSet(), hasLength(1), reason: 'thẻ thông tin lô và mọi thẻ kỳ đo giãn hết chiều rộng: $rong');
    });
  });

  group('Màn hợp tác xã', () {
    Widget man(PhienGia phien, MockClientHandler xuLy) => boc(
      ManHopTacXa(
        phien: phien,
        api: HopTacXaApi(
          GraphqlClient(goc: 'https://gateway.test', layToken: phien.layToken, client: MockClient(xuLy)),
        ),
        kiemChungApi: KiemChungApi(goc: 'https://gateway.test', client: MockClient((_) async => json(seriToanVen()))),
      ),
    );

    testWidgets('chưa đăng nhập → nút Đăng nhập', (t) async {
      await t.pumpWidget(man(PhienGia(daDangNhap: false), (_) async => json(tongQuanGraphql())));
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('đã đăng nhập → ví (đã cấp/đã bán/trong ví) và lô đất', (t) async {
      await t.pumpWidget(man(PhienGia(), (_) async => json(tongQuanGraphql())));
      await t.pumpAndSettle();
      expect(find.text('HTX Mẫu Đất Mũi'), findsOneWidget);
      expect(
        t.widget<Text>(find.text('HTX Mẫu Đất Mũi')).maxLines,
        2,
        reason: 'tên dài xuống 2 dòng, không cắt ở 1 dòng',
      );
      expect(find.text('18'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Lô đất (2)'), findsOneWidget);
      expect(find.text('Lô Đất Mũi 2'), findsOneWidget);
      expect(find.textContaining('8,87 ha · trồng 2021 · Xã viên Mẫu 2'), findsOneWidget);
    });

    testWidgets('danh sách rỗng → thông báo ví trống và chưa có lô', (t) async {
      await t.pumpWidget(man(PhienGia(), (_) async => json(tongQuanGraphql(rong: true))));
      await t.pumpAndSettle();
      expect(find.text('Ví hiện chưa có tín chỉ khả dụng.'), findsOneWidget);
      expect(find.textContaining('chưa có lô đất nào'), findsOneWidget);
    });

    testWidgets('401 → bỏ phiên, quay về màn đăng nhập kèm lời nhắn', (t) async {
      final phien = PhienGia();
      await t.pumpWidget(man(phien, (_) async => http.Response('', 401)));
      await t.pumpAndSettle();
      expect(phien.soLanHuy, 1);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.textContaining('hết hạn'), findsOneWidget);
    });

    testWidgets('mất mạng → "Mất kết nối" và nút Thử lại tải lại được', (t) async {
      var lan = 0;
      await t.pumpWidget(
        man(PhienGia(), (_) async {
          if (lan++ == 0) throw const SocketException('mất mạng');
          return json(tongQuanGraphql());
        }),
      );
      await t.pumpAndSettle();
      expect(find.text('Mất kết nối'), findsOneWidget);
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('Lô đất (2)'), findsOneWidget);
    });
  });
}
