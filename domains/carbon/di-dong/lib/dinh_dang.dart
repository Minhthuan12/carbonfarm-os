// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Định dạng số cho người đọc tiếng Việt, dùng chung cho màn hình và phần tóm tắt bản ghi sổ cái.

/// Định dạng số kiểu Việt Nam: 1.234,5 (dấu chấm ngăn nghìn, dấu phẩy thập phân).
String soVn(num v, {int le = 0}) {
  final s = v.toStringAsFixed(le);
  final phan = s.split('.');
  final nguyen = phan[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  return phan.length > 1 ? '$nguyen,${phan[1]}' : nguyen;
}

/// Số đọc từ JSON (số hoặc chuỗi "15.543") định dạng kiểu Việt; không đọc được thì giữ nguyên.
String soVnTuJson(Object? v, {int le = 2}) {
  final so = v is num ? v : num.tryParse('$v');
  return so == null ? '$v' : soVn(so, le: le);
}

/// Ngày ISO (2026-04-01, có thể kèm giờ) → 01/04/2026. Chuỗi không đúng dạng thì giữ nguyên.
String ngayVn(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  return m == null ? iso : '${m[3]}/${m[2]}/${m[1]}';
}

/// Đổi gạch nối trong số sê-ri (MCK-DM01-26-0000000001) sang gạch nối không ngắt dòng (U+2011) để chữ không bị tách đôi
/// ở "MCK-" khi xuống dòng. Chỉ dùng khi hiển thị; giá trị gửi lên API giữ nguyên.
String giuSeriLien(String s) =>
    s.replaceAllMapped(RegExp(r'[A-Z0-9]{3}-[A-Z0-9]{4}-\d{2}-\d{10}'), (m) => m[0]!.replaceAll('-', '‑'));
