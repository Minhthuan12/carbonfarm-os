# SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
# SPDX-License-Identifier: GPL-3.0-or-later
# Giữ lại hai sửa của #83 (PR #84):
#   1. Trang đăng nhập Keycloak luôn tiếng Việt, kể cả khi trình duyệt gửi Accept-Language tiếng Anh (realm dxos chỉ
#      hỗ trợ "vi"); tên đăng nhập từ login_hint vẫn được điền sẵn.
#   2. Form đăng ký lô trên web ghi cảnh báo lệch diện tích với mã UC004 (khớp ràng buộc trong 002_dang_ky_lo.sql;
#      UC006 là "không có quyền với xã viên"). Ràng buộc UC004 qua API đã kiểm ở carbon-dang-ky-lo.hurl; tệp này kiểm
#      chuỗi trong bundle của trang chủ / bàn làm việc.

# 1. Trang đăng nhập tiếng Việt
GET {{gateway}}/auth/realms/dxos/protocol/openid-connect/auth?client_id=web&response_type=code&scope=openid&state=tieng-viet&redirect_uri=http%3A%2F%2Flocalhost%3A9080%2Fdang-nhap%2Fxong&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&login_hint=xavien-mau-1
Accept-Language: en-US,en;q=0.9
HTTP 200
[Asserts]
xpath "string(/html/@lang)" == "vi"
xpath "string(//title)" contains "Đăng nhập"
xpath "normalize-space(//*[@id='kc-page-title'])" == "Đăng nhập vào tài khoản của bạn"
xpath "string(//input[@id='username']/@value)" == "xavien-mau-1"
body not contains "Sign in to your account"

# 2. Bundle trang chủ / bàn làm việc ghi "mã lỗi UC004" (web tắt SSR: HTML → entry app → node của route "/")
GET {{gateway}}/
HTTP 200
[Captures]
app: regex "(/_app/immutable/entry/app\\.[A-Za-z0-9_-]+\\.js)"

GET {{gateway}}{{app}}
HTTP 200
[Captures]
# Node 0 là layout, 1 là trang lỗi, 2 là route "/" (src/routes/+page.svelte)
trang_chu: regex "nodes/(2\\.[A-Za-z0-9_-]+\\.js)"

GET {{gateway}}/_app/immutable/nodes/{{trang_chu}}
HTTP 200
[Asserts]
body contains "mã lỗi UC004"
body not contains "mã lỗi UC006"
