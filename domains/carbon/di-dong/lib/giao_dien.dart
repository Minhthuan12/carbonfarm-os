// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Màu và cỡ chữ dùng chung. Màu thương hiệu #0b6351 giống web (domains/carbon/web/src/app.css, --teal); chữ to hơn
// mặc định một bậc vì người dùng chính là nông dân, cán bộ hợp tác xã dùng điện thoại ngoài đồng.
import 'package:material_ui/material_ui.dart';

export 'dinh_dang.dart';

const mauChinh = Color(0xFF0B6351);
const mauChinhDam = Color(0xFF07473A);
const mauNhat = Color(0xFFE1F4ED);
const mauXau = Color(0xFFB3261E);
const mauXauNhat = Color(0xFFFDECEA);

ThemeData giaoDien() {
  final mau = ColorScheme.fromSeed(seedColor: mauChinh, primary: mauChinh, error: mauXau);
  final goc = ThemeData(colorScheme: mau, useMaterial3: true);
  // textTheme của ThemeData chưa có cỡ chữ (cỡ đến từ Typography lúc dựng), nên ghép englishLike2021 trước khi phóng to
  final chu = Typography.englishLike2021
      .merge(goc.textTheme)
      .apply(fontSizeFactor: 1.12, bodyColor: const Color(0xFF16201D));
  return goc.copyWith(
    textTheme: chu,
    scaffoldBackgroundColor: const Color(0xFFF6F8F7),
    appBarTheme: const AppBarTheme(backgroundColor: mauChinh, foregroundColor: Colors.white, centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDDE5E2)),
      ),
    ),
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
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: mauChinh),
            const SizedBox(height: 16),
            Text(tieuDe, style: t.titleLarge, textAlign: TextAlign.center),
            if (noiDung != null) ...[
              const SizedBox(height: 8),
              Text(noiDung!, style: t.bodyLarge, textAlign: TextAlign.center),
            ],
            if (nut != null) ...[const SizedBox(height: 24), FilledButton(onPressed: onNhan, child: Text(nut!))],
          ],
        ),
      ),
    );
  }
}
