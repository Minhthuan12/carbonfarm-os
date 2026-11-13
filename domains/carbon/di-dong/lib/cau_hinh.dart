// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Cấu hình lúc build. Địa chỉ gateway đổi bằng --dart-define=API_URL=..., ví dụ stack cục bộ:
//   flutter run --dart-define=API_URL=http://localhost:9080
// Keycloak, GraphQL và API kiểm chứng đều đi qua cùng gateway nên chỉ cần một địa chỉ.

/// Gateway của CarbonFarm OS (không có dấu "/" ở cuối).
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://carbonfarm.dzfullstack.com');

/// Client công khai của app trong realm dxos (platform/keycloak/realm-dxos.json).
const String clientId = 'carbon-di-dong';

/// Đường quay về sau khi đăng nhập/đăng xuất; scheme khai trong Info.plist và build.gradle.kts.
const String duongQuayVe = 'vn.carbonfarmos.app:/oauth';

/// Đường dẫn OIDC của realm dxos trên gateway.
String get oidcGoc => '$apiUrl/auth/realms/dxos/protocol/openid-connect';
