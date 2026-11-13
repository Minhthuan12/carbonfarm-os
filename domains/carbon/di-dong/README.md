<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# App di động CarbonFarm

App Flutter (Android + iOS) cho miền carbon (Tầng 2). App chỉ gọi API có sẵn của gateway và không có backend riêng. Lý do chọn Flutter và phạm vi: [ADR 0009](../../../docs/adr/0009-app-di-dong-flutter.md).

| Màn hình | Ai dùng | API |
|---|---|---|
| **Hợp tác xã**: ví tín chỉ (đã cấp, đã bán, trong ví), danh sách lô đất, chi tiết lô và các kỳ đo MRV | Cán bộ hợp tác xã (xã viên chỉ xem) | `POST /graphql` với token Keycloak; quyền theo RLS |
| **Kiểm chứng**: gõ sê-ri hoặc quét QR, xem chuỗi bản ghi sổ cái và SHA-256 khớp hay không | Ai cũng dùng được, không cần đăng nhập | `GET /kiem-chung/api/seri/...` |

Đăng nhập dùng OIDC Authorization Code + PKCE qua trình duyệt hệ thống, trang Keycloak tiếng Việt, client công khai `carbon-di-dong` (`domains/carbon/keycloak/client-di-dong.json`). App không thấy mật khẩu.

## Chuẩn bị
- Flutter 3.50 trở lên (`brew install --cask flutter`), kiểm bằng `flutter doctor`.
- Android: Android SDK (Android Studio hoặc command-line tools), JDK 17.
- iOS: Xcode 27, chỉ trên macOS.

```bash
cd domains/carbon/di-dong
flutter pub get
```

## Chạy
Mặc định app nối tới bản demo công khai https://carbonfarm.dzfullstack.com:

```bash
flutter run
```

Chạy với stack cục bộ của đội (`task up` ở thư mục gốc repo, gateway ở cổng 9080):

```bash
# iOS Simulator: localhost của máy Mac
flutter run --dart-define=API_URL=http://localhost:9080
# Máy ảo Android: chuyển cổng 9080 của máy ảo về máy thật trước (Keycloak cấp token cho đúng địa chỉ localhost:9080)
adb reverse tcp:9080 tcp:9080
flutter run --dart-define=API_URL=http://localhost:9080
```

Tài khoản mẫu và cách lấy mật khẩu (do OpenBao sinh): [`docs/thu-nghiem.md`](../../../docs/thu-nghiem.md). App chỉ cho HTTP thường với `localhost`; mọi địa chỉ khác phải là HTTPS.

## Kiểm thử và build
```bash
flutter analyze
flutter test                                   # API với HTTP giả, màn kiểm chứng và hợp tác xã
flutter build apk --release                    # build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release --no-codesign      # chỉ trên macOS
```

Muốn APK hay bản iOS trỏ tới gateway khác thì thêm `--dart-define=API_URL=https://...` vào lệnh build.

- APK release đang ký bằng khóa debug: cài thử được, chưa lên được Google Play.
- Lên TestFlight cần đặt DEVELOPMENT_TEAM của đội trong Xcode; trong repo để trống.

## Cấu trúc
```text
lib/
├── main.dart              # app, hai thẻ: Hợp tác xã · Kiểm chứng
├── cau_hinh.dart          # API_URL, client Keycloak, đường quay về
├── dang_nhap.dart         # phiên Keycloak (AppAuth), token, đăng xuất
├── giao_dien.dart         # màu thương hiệu #0b6351, chữ to, khung báo lỗi
├── api/                   # graphql.dart, hop_tac_xa.dart, kiem_chung.dart, loi.dart
└── man_hinh/              # hop_tac_xa.dart, chi_tiet_lo.dart, kiem_chung.dart, quet_qr.dart
test/                      # api_test.dart, man_hinh_test.dart, du_lieu_gia.dart
```

- Biểu tượng app sinh từ logo đội: `dart run flutter_launcher_icons`, ảnh nguồn `assets/icon-app.png` (1024×1024, nền trắng, không kênh alpha).
- Giấy phép thư viện: mục "App di động" trong [`DEPENDENCIES.md`](../../../DEPENDENCIES.md).
