<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Miền mẫu: thủy sản (ví dụ cắm–rút)

Miền nhỏ nhất để học cách viết miền mới trên Tầng 1 của CarbonFarm OS: hộ nuôi khai báo ao nuôi tôm, mỗi người chỉ thấy ao của mình, quản trị thấy tất cả. **Không thuộc sản phẩm** và không được bật mặc định.

| Tệp | Nội dung |
|---|---|
| `db/migrations/001_thuy_san.sql` | schema `thuy_san`, bảng `ao_nuoi`, quyền theo cột, RLS theo `nen_tang.nguoi_goi()` |
| `db/seed/001_ao_mau.sql` | 2 ao giả, chủ `he-thong` (chỉ quản trị thấy) |

Cắm vào: chép thư mục này thành `domains/thuy-san/`, thêm `thuy_san` vào `GRAPHQL_SCHEMAS` trong `.env`, rồi
`docker compose --env-file .env -f compose.yaml up -d --force-recreate migrate postgraphile`.

Hướng dẫn đầy đủ (cấu trúc, quyền, lỗi nghiệp vụ, cắm, rút, kiểm thử): [`docs/viet-mien.md`](../../docs/viet-mien.md).
