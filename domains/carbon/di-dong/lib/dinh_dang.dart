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
