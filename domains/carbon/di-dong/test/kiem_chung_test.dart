// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Kiểm chứng công khai với HTTP giả (không cần mạng hay stack): API /kiem-chung/api và màn kiểm chứng (gõ sê-ri, sê-ri
// giả, quét QR, mất mạng).
import 'dart:io';

import 'package:carbonfarm/api/kiem_chung.dart';
import 'package:carbonfarm/api/loi.dart';
import 'package:carbonfarm/giao_dien.dart';
import 'package:carbonfarm/man_hinh/kiem_chung.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'du_lieu_gia.dart';

const goc = 'https://gateway.test';

Widget boc(Widget w) => ungDungCarbonFarm(home: w);

void main() {
  group('API kiểm chứng công khai', () {
    KiemChungApi kc(MockClientHandler xuLy) => KiemChungApi(goc: goc, client: MockClient(xuLy));

    test('sê-ri hợp lệ: gọi /kiem-chung/api/seri, không gửi token', () async {
      late http.Request yeuCau;
      final kq = await kc((r) async {
        yeuCau = r;
        return json(seriToanVen());
      }).tra('  $seriThat ');
      expect(yeuCau.url.toString(), '$goc/kiem-chung/api/seri/$seriThat');
      expect(yeuCau.headers.containsKey('Authorization'), isFalse);
      kq as TimThay;
      expect(kq.toanVen, isTrue);
      expect(kq.chuSoHuu, 'HTX Mẫu');
      expect(kq.banGhi.map((b) => b.tenLoai), ['Đo từ vệ tinh, cán bộ đã duyệt', 'Registry cấp tín chỉ']);
      expect(kq.banGhi.last.tomTat, contains('15 tín chỉ'));
      expect(kq.banGhi.first.tomTat, '15,85 t CO₂e · tán 8,87 ha', reason: 'số thập phân kiểu Việt');
    });

    test('một bản ghi lệch SHA-256 → không toàn vẹn', () async {
      final j = seriToanVen()
        ..['toan_ven'] = false
        ..['su_kien'] = [banGhi('ket_qua_mrv'), banGhi('cap_tin_chi', khop: false)];
      final kq = await kc((_) async => json(j)).tra(seriThat) as TimThay;
      expect(kq.toanVen, isFalse);
      expect(kq.banGhi.last.hopLe, isFalse);
    });

    test('sê-ri giả → KhongThay với thông báo của máy chủ', () async {
      final kq = await kc((_) async => json({'loi': 'Sổ cái không có bản ghi cấp cho tín chỉ X'}, 404))
          .tra('MCK-GIA0-26-0000000001');
      expect(kq, isA<KhongThay>().having((k) => k.thongBao, 'tb', 'Sổ cái không có bản ghi cấp cho tín chỉ X'));
    });

    test('mã không có dấu "-" coi là commit Dolt', () async {
      late Uri url;
      final kq = await kc((r) async {
        url = r.url;
        return json({
          'commit': 'a' * 32,
          'luc': '2026-11-01',
          'thong_diep': 'cấp tín chỉ',
          'ban_ghi': [banGhi('cap_tin_chi')],
        });
      }).tra('a' * 32);
      expect(url.path, '/kiem-chung/api/commit/${'a' * 32}');
      expect((kq as TimThay).laSeri, isFalse);
      expect(kq.moTa, 'cấp tín chỉ');
    });

    test('QR chứa đường link /kiem-chung?q=... → lấy sê-ri trong q', () {
      expect(chuanHoaMa('https://carbonfarm.dzfullstack.com/kiem-chung?q=$seriThat'), seriThat);
      expect(chuanHoaMa(' $seriThat\n'), seriThat);
    });

    test('400, 429, 5xx và mất mạng ra lỗi tiếng Việt', () async {
      await expectLater(
        kc((_) async => json({'loi': 'Số sê-ri sai định dạng'}, 400)).tra('A-B'),
        throwsA(isA<LoiMayChu>().having((e) => e.thongBao, 'tb', 'Số sê-ri sai định dạng')),
      );
      await expectLater(
        kc((_) async => http.Response('Too many', 429)).tra(seriThat),
        throwsA(isA<LoiMayChu>().having((e) => e.thongBao, 'tb', contains('một phút'))),
      );
      await expectLater(
        kc((_) async => http.Response('<html>', 502)).tra(seriThat),
        throwsA(isA<LoiMayChu>().having((e) => e.thongBao, 'tb', contains('mã 502'))),
      );
      await expectLater(kc((_) async => throw http.ClientException('x')).tra(seriThat), throwsA(isA<LoiMang>()));
    });
  });

  group('Màn kiểm chứng', () {
    final daGoi = <String>[];
    KiemChungApi api() => KiemChungApi(
      goc: 'https://gateway.test',
      client: MockClient((r) async {
        daGoi.add(r.url.path);
        final ma = Uri.decodeComponent(r.url.pathSegments.last);
        if (ma == seriThat) return json(seriToanVen());
        if (ma == 'MCK-MATM-26-0000000001') throw const SocketException('mất mạng');
        return json({'loi': 'Sổ cái không có bản ghi cấp cho tín chỉ $ma'}, 404);
      }),
    );
    setUp(daGoi.clear);

    testWidgets('gõ sê-ri thật → "Toàn vẹn." và chuỗi bản ghi', (t) async {
      await t.pumpWidget(boc(ManKiemChung(api: api())));
      await t.enterText(find.byKey(const Key('o-seri')), seriThat);
      await t.tap(find.byKey(const Key('nut-tra')));
      await t.pumpAndSettle();
      expect(find.text('Toàn vẹn.'), findsOneWidget);
      expect(find.textContaining('2/2 bản ghi khớp SHA-256'), findsOneWidget);
      expect(find.textContaining('HTX Mẫu'), findsWidgets);
      await t.scrollUntilVisible(
        find.text('Bước 2 · Registry cấp tín chỉ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Bước 1 · Đo từ vệ tinh, cán bộ đã duyệt'), findsOneWidget);
      expect(find.text('SHA-256 khớp · Nguyên vẹn'), findsNWidgets(2));
    });

    testWidgets('sê-ri giả → "Không có bản ghi."', (t) async {
      await t.pumpWidget(boc(ManKiemChung(api: api())));
      await t.enterText(find.byKey(const Key('o-seri')), 'MCK-GIA0-26-0000000001');
      await t.tap(find.byKey(const Key('nut-tra')));
      await t.pumpAndSettle();
      expect(find.text('Không có bản ghi.'), findsOneWidget);
      expect(
        find.textContaining('Sổ cái không có bản ghi cấp cho tín chỉ ${giuSeriLien('MCK-GIA0-26-0000000001')}'),
        findsOneWidget,
        reason: 'thông báo của máy chủ, số sê-ri hiển thị bằng gạch nối không ngắt dòng',
      );
      expect(find.text('Toàn vẹn.'), findsNothing);
      await t.tap(find.byKey(const Key('nut-xoa')));
      await t.pump();
      expect(find.text('Không có bản ghi.'), findsNothing, reason: 'nút xóa bỏ cả ô nhập lẫn kết quả');
      expect(find.text('MCK-GIA0-26-0000000001'), findsNothing);
    });

    testWidgets('quét QR chứa link /kiem-chung?q= → tự tra sê-ri trong link', (t) async {
      await t.pumpWidget(
        boc(ManKiemChung(api: api(), quetQr: (_) async => 'https://carbonfarm.dzfullstack.com/kiem-chung?q=$seriThat')),
      );
      await t.tap(find.byKey(const Key('nut-quet')));
      await t.pumpAndSettle();
      expect(daGoi, ['/kiem-chung/api/seri/$seriThat']);
      expect(find.text('Toàn vẹn.'), findsOneWidget);
    });

    testWidgets('mở từ ví với sê-ri sẵn → tự tra', (t) async {
      await t.pumpWidget(boc(ManKiemChung(api: api(), maBanDau: seriThat)));
      await t.pumpAndSettle();
      expect(find.text('Toàn vẹn.'), findsOneWidget);
    });

    testWidgets('ô trống → nhắc nhập, không gọi mạng; mất mạng → báo kiểm tra mạng', (t) async {
      await t.pumpWidget(boc(ManKiemChung(api: api())));
      await t.tap(find.byKey(const Key('nut-tra')));
      await t.pump();
      expect(find.textContaining('Hãy nhập số sê-ri'), findsOneWidget);
      expect(daGoi, isEmpty);
      await t.enterText(find.byKey(const Key('o-seri')), 'MCK-MATM-26-0000000001');
      await t.tap(find.byKey(const Key('nut-tra')));
      await t.pumpAndSettle();
      expect(find.text('Chưa tra được'), findsOneWidget);
      expect(find.textContaining('Kiểm tra mạng'), findsOneWidget);
    });
  });
}
