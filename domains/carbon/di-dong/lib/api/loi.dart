// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Các loại lỗi màn hình cần phân biệt: mất mạng (thử lại), hết phiên (đăng nhập lại), lỗi nghiệp vụ (hiện nguyên văn).

/// Không kết nối được máy chủ (mất mạng, hết thời gian chờ, sai địa chỉ).
class LoiMang implements Exception {
  const LoiMang();
  @override
  String toString() => 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
}

/// Gateway trả 401: token hết hạn hoặc bị thu hồi, cần đăng nhập lại.
class LoiHetPhien implements Exception {
  const LoiHetPhien();
  @override
  String toString() => 'Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.';
}

/// Lỗi do máy chủ trả. Lỗi nghiệp vụ (mã SQLSTATE bắt đầu bằng "U") giữ nguyên thông báo tiếng Việt của CSDL.
class LoiMayChu implements Exception {
  const LoiMayChu(this.thongBao, {this.ma});
  final String thongBao;
  final String? ma;
  @override
  String toString() => thongBao;
}
