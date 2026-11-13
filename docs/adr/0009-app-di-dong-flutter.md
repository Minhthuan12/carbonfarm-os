<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# 0009 · App di động bằng Flutter, chỉ gọi API có sẵn

- Trạng thái: chấp nhận
- Ngày: 2026-11-13
- Người viết: @Minhthuan12
- Issue / PR: #

## Bối cảnh
Cán bộ hợp tác xã và xã viên ít khi ngồi máy tính. Họ cần xem nhanh lô đất và ví tín chỉ trên điện thoại. Người mua, kiểm toán viên thì cần quét mã trên giấy chứng nhận để kiểm chứng tín chỉ ngay tại chỗ. Web Tầng 2 đã làm được mọi việc nhưng gõ địa chỉ và đăng nhập trên điện thoại khá bất tiện.

Ràng buộc:
- trước mốc đóng băng 29/11/2026 không thêm backend hay thành phần hạ tầng mới;
- thư viện phải có giấy phép OSI, dùng được trong app GPL-3.0;
- không dùng lại stack hay mã của đội khác trong trường;
- người viết không có máy Android thật, chỉ có iOS Simulator.

## Các phương án
Giấy phép đọc từ tệp LICENSE trong gói pub/npm ngày 13/11/2026.

| Phương án | Giấy phép | Ưu | Nhược |
|---|---|---|---|
| Flutter 3.50 (Dart) | BSD-3-Clause | Một mã cho Android và iOS, build APK/IPA bằng lệnh `flutter`, kiểm thử widget không cần máy ảo | Thêm một ngôn ngữ (Dart) vào repo |
| Web hiện có, cài như PWA | — | Không thêm gì | Không quét QR ổn định trên iOS, không có biểu tượng trên cửa hàng, đăng nhập phải gõ địa chỉ |
| Native riêng (Kotlin + Swift) | — | Nhẹ nhất | Hai mã nguồn, gấp đôi công cho một đội 3 người |

Thư viện quét QR:
- `mobile_scanner` (BSD-3) dễ dùng, nhưng bản Android kéo Google ML Kit, là SDK đóng có điều khoản riêng.
- `flutter_zxing` (MIT) chạy zxing-cpp (Apache-2.0) ngay trên máy và đều là nguồn mở.

## Quyết định
Dùng Flutter trong `domains/carbon/di-dong/` (Tầng 2, miền carbon). Bundle/application ID là `vn.carbonfarmos.app`. Phạm vi giữ gọn ở ba việc, tất cả qua gateway đang có:
1. Đăng nhập Keycloak bằng OIDC Authorization Code + PKCE qua trình duyệt hệ thống (`flutter_appauth`). Client công khai `carbon-di-dong` được nạp vào realm `dxos` từ `domains/carbon/keycloak/client-di-dong.json` bằng partial import, cùng bước với người dùng mẫu (`nap-nguoi-dung.sh`), nên realm của bản demo đang chạy cũng nhận client mới. Client này không đặt trong `platform/keycloak/realm-dxos.json`, vì Tầng 1 không chứa thứ riêng của miền. Client `web` giữ nguyên.
2. Xem lô đất và ví tín chỉ (đã cấp, đã bán, đang trong ví) bằng GraphQL `/graphql`. Quyền xem do RLS trong CSDL quyết định, giống hệt web.
3. Kiểm chứng công khai bằng `/kiem-chung/api`: gõ sê-ri hoặc quét QR bằng `flutter_zxing`, không cần đăng nhập.

Đăng ký lô bằng bản đồ, duyệt MRV và bán tín chỉ vẫn chỉ làm trên web.

## Hệ quả
- Không thêm dịch vụ nào vào compose. Thay đổi phía máy chủ chỉ là một client Keycloak.
- App giữ access token trong bộ nhớ. Refresh token nằm trong Keychain/Keystore (`flutter_secure_storage`). App không thấy mật khẩu vì việc đăng nhập diễn ra trên trang Keycloak.
- Địa chỉ gateway đổi lúc build bằng `--dart-define=API_URL=...`; mặc định là bản demo công khai.
- Kiểm SPDX vẫn dùng `scripts/spdx.py`, nay hiểu thêm Dart/Kotlin/Swift/XML. Tệp do Flutter/Xcode sinh và tự ghi đè được bỏ qua và khai ở `NOTICE`.
- CI có job `di-dong`: `flutter analyze`, `flutter test`, build APK trên Ubuntu. Build iOS chỉ chạy trên máy macOS của đội (`flutter build ios --no-codesign`).
- APK release tạm ký bằng khóa debug, đủ để cài thử nhưng chưa lên được Google Play. Lên TestFlight cần tài khoản Apple Developer của đội và DEVELOPMENT_TEAM (đang để trống trong repo).
