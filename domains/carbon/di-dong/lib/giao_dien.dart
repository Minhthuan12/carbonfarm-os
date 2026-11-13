// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Giao diện chung của app: theme forui riêng của CarbonFarm (không dùng bảng màu shadcn mặc định), MaterialApp dùng
// chung cho app và kiểm thử, và vài khối dựng sẵn. Màu thương hiệu #0b6351 giống web (domains/carbon/web/src/app.css);
// chữ phóng to một bậc vì người dùng chính là nông dân, cán bộ hợp tác xã dùng điện thoại ngoài đồng.
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

export 'dinh_dang.dart';

const mauChinh = Color(0xFF0B6351);
const mauChinhDam = Color(0xFF07473A);
const mauNhat = Color(0xFFE1F4ED);
const mauVien = Color(0xFFD6E4DE);
const mauNen = Color(0xFFF4F8F6);
const mauChu = Color(0xFF14211D);
const mauChuPhu = Color(0xFF55665F);
const mauXau = Color(0xFFB3261E);
const mauXauNhat = Color(0xFFFDECEA);

/// Bảng màu forui của CarbonFarm: nền xanh rất nhạt, chữ xanh đen, nhấn bằng xanh rừng ngập mặn.
final mauForui = FColors(
  brightness: Brightness.light,
  systemOverlayStyle: SystemUiOverlayStyle.dark,
  barrier: Color(0x33000000),
  background: mauNen,
  foreground: mauChu,
  primary: mauChinh,
  primaryForeground: Color(0xFFFFFFFF),
  secondary: mauNhat,
  secondaryForeground: mauChinhDam,
  muted: Color(0xFFEAF1EE),
  mutedForeground: mauChuPhu,
  destructive: mauXau,
  destructiveForeground: Color(0xFFFFFFFF),
  error: mauXau,
  errorForeground: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  border: mauVien,
);

FThemeData? _chuDe;

/// Theme forui của app (dựng một lần). Chữ lớn hơn mặc định 12 %.
FThemeData chuDeForui() => _chuDe ??= FThemeData(
  colors: mauForui,
  touch: true,
  debugLabel: 'CarbonFarm',
  typography: _chuViet(FTypography.inherit(colors: mauForui, touch: true).scale(sizeScalar: 1.12)),
);

/// Khoảng cách dòng mặc định của forui rộng (1,5–2,25 lần cỡ chữ), làm đoạn tiếng Việt hai dòng tách rời và đẩy nút
/// xuống dưới màn hình. Đặt lại khoảng 1,4 cho chữ thường và hẹp dần cho tiêu đề lớn.
FTypography _chuViet(FTypography g) {
  FTypeface gon(FTypeface f, double h) => f.copyWith(
    xs: f.xs.copyWith(height: h),
    sm: f.sm.copyWith(height: h),
    md: f.md.copyWith(height: h),
    lg: f.lg.copyWith(height: h),
    xl: f.xl.copyWith(height: 1.25),
    xl2: f.xl2.copyWith(height: 1.2),
    xl3: f.xl3.copyWith(height: 1.15),
    xl4: f.xl4.copyWith(height: 1.1),
    xl5: f.xl5.copyWith(height: 1.05),
  );
  return g.copyWith(display: gon(g.display, 1.3), body: gon(g.body, 1.4));
}

/// Theme Material xấp xỉ theme forui, cho các widget Material còn dùng (ô nhập, thanh cuộn, trang trình duyệt).
ThemeData giaoDien() => chuDeForui().toApproximateMaterialTheme().copyWith(scaffoldBackgroundColor: mauNen);

/// MaterialApp dùng chung cho app và kiểm thử: theme forui, bản địa hóa tiếng Việt.
Widget ungDungCarbonFarm({required Widget home}) => MaterialApp(
  title: 'CarbonFarm',
  debugShowCheckedModeBanner: false,
  locale: const Locale('vi'),
  supportedLocales: const [Locale('vi')],
  localizationsDelegates: FLocalizations.localizationsDelegates,
  theme: giaoDien(),
  builder: (context, child) => FTheme(data: chuDeForui(), child: child!),
  home: home,
);

/// Kiểu chữ theo theme forui.
extension KieuChu on BuildContext {
  FTypography get chu => theme.typography;
  FColors get mau => theme.colors;
}

/// Thẻ nền trắng, viền mảnh, bo tròn: khối nội dung chính của mọi màn hình.
class TheNoiDung extends StatelessWidget {
  const TheNoiDung({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.mauNenThe,
    this.mauVienThe,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? mauNenThe;
  final Color? mauVienThe;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: mauNenThe ?? Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: mauVienThe ?? mauVien),
      boxShadow: const [BoxShadow(color: Color(0x0F0B6351), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

/// Khung báo lỗi/trống có nút hành động, dùng chung cho các màn hình.
class KhungThongBao extends StatelessWidget {
  const KhungThongBao({super.key, required this.icon, required this.tieuDe, this.noiDung, this.nut, this.onNhan});

  final IconData icon;
  final String tieuDe;
  final String? noiDung;
  final String? nut;
  final VoidCallback? onNhan;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: mauNhat, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: mauChinh),
            ),
            const SizedBox(height: 18),
            Text(
              tieuDe,
              style: chu.display.xl.copyWith(fontWeight: FontWeight.w700, color: mauChu),
              textAlign: TextAlign.center,
            ),
            if (noiDung != null) ...[
              const SizedBox(height: 8),
              Text(
                noiDung!,
                style: chu.body.md.copyWith(color: mauChuPhu),
                textAlign: TextAlign.center,
              ),
            ],
            if (nut != null) ...[const SizedBox(height: 24), FButton(onPress: onNhan, child: Text(nut!))],
          ],
        ),
      ),
    );
  }
}

/// Nhãn trạng thái dạng viên thuốc (pill).
class NhanTrangThai extends StatelessWidget {
  const NhanTrangThai(this.nhan, {super.key, this.xau = false, this.icon});

  final String nhan;
  final bool xau;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mau = xau ? mauXau : mauChinhDam;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: xau ? mauXauNhat : mauNhat, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: mau), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              nhan,
              style: context.chu.body.sm.copyWith(color: mau, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
