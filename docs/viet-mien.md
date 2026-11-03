<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Viết một miền mới (cắm–rút)

Tầng 1 (`platform/`) không biết tên miền nào. Nó quét `domains/*/` theo quy ước và tự lắp những gì miền khai báo: migration, dữ liệu mẫu, bí mật, route gateway, schema GraphQL. Vì vậy thêm một miền nghiệp vụ mới, ví dụ thủy sản, quản lý nước hay rác thải, **không sửa dòng nào trong `platform/`**: chỉ thêm một thư mục, và gỡ ra cũng chỉ cần xóa thư mục đó.

Miền carbon (`domains/carbon/`) là miền thật của sản phẩm. Miền mẫu nhỏ nhất, dùng để học và thử, ở [`examples/mien-mau-thuy-san/`](../examples/mien-mau-thuy-san/): hộ nuôi khai báo ao nuôi tôm, mỗi người chỉ thấy ao của mình.

## 1. Cấu trúc thư mục của một miền

| Tệp trong `domains/<miền>/` | Bắt buộc | Tầng 1 làm gì |
|---|---|---|
| `db/migrations/*.sql` | có | dịch vụ `migrate` áp theo thứ tự tên, mỗi tệp một transaction, ghi tên + SHA-256 vào `nen_tang.lich_su_migration`. Tệp đã áp không được sửa: muốn đổi thì thêm tệp mới |
| `db/seed/*.sql` | không | nạp dữ liệu **giả** khi `NAP_DU_LIEU_MAU=true`; viết sao cho chạy lại không nhân đôi (`ON CONFLICT DO NOTHING`) |
| `db/vai-dang-nhap.txt` | không | mỗi dòng `<vai PostgreSQL> <tên bí mật>`: Tầng 1 đặt mật khẩu đăng nhập cho vai do migration tạo, lấy từ OpenBao |
| `bi-mat.txt` | không | mỗi dòng một tên bí mật: OpenBao sinh và đặt vào `/run/bimat/<tên>` |
| `gateway/routes.yaml` | không | ghép vào cấu hình APISIX lúc khởi động (route riêng của miền, ví dụ API công khai) |

Schema PostgreSQL của miền lộ ra GraphQL (PostGraphile) khi thêm tên schema vào biến `GRAPHQL_SCHEMAS` trong `.env`.

## 2. Những gì Tầng 1 cho miền dùng

- **Vai PostgreSQL:** `vai_nguoi_dung` (đã đăng nhập), `vai_quan_tri` (vai `quan_tri` trong Keycloak), `vai_an_danh`. PostGraphile chuyển sang vai tương ứng theo JWT của người gọi.
- **Người gọi:** hàm `nen_tang.nguoi_goi()` trả `sub` của token (rỗng nếu chưa đăng nhập). Dùng nó trong cột mặc định và chính sách RLS.
- **Lỗi nghiệp vụ:** hàm hoặc trigger của miền báo lỗi bằng SQLSTATE bắt đầu bằng `U`, ví dụ `RAISE EXCEPTION USING ERRCODE = 'UT001', MESSAGE = '…', HINT = '…'`. PostGraphile trả nguyên thông báo tiếng Việt cho giao diện, mọi lỗi khác bị che.
- **Ẩn cột khỏi API:** chú thích `@behavior -*` trên cột (ví dụ cột `chu_sub`).

## 3. Viết miền: từng bước

1. **Tạo thư mục** `domains/<miền>/db/migrations/` và tệp `001_<miền>.sql`, có header SPDX hai dòng (`task license` thêm giúp).
2. **Tạo schema và cấp quyền dùng schema:**
   ```sql
   CREATE SCHEMA thuy_san;
   GRANT USAGE ON SCHEMA thuy_san TO vai_nguoi_dung, vai_quan_tri;
   ```
3. **Tạo bảng**, cột chủ sở hữu mặc định là người gọi:
   ```sql
   chu_sub text NOT NULL DEFAULT coalesce(nen_tang.nguoi_goi(), 'he-thong')
   ```
4. **Cấp quyền theo cột** (chỉ cho ghi những cột người dùng được nhập), rồi **bật RLS** và viết chính sách:
   ```sql
   ALTER TABLE thuy_san.ao_nuoi ENABLE ROW LEVEL SECURITY;
   ALTER TABLE thuy_san.ao_nuoi FORCE ROW LEVEL SECURITY;
   CREATE POLICY quan_tri ON thuy_san.ao_nuoi FOR ALL TO vai_quan_tri USING (true) WITH CHECK (true);
   CREATE POLICY cua_toi ON thuy_san.ao_nuoi FOR ALL TO vai_nguoi_dung
     USING (chu_sub = nen_tang.nguoi_goi()) WITH CHECK (chu_sub = nen_tang.nguoi_goi());
   ```
5. **Dữ liệu giả** (nếu cần) trong `db/seed/`.
6. **Bật GraphQL:** thêm schema vào `.env`, ví dụ `GRAPHQL_SCHEMAS=nen_tang,carbon,thuy_san`.

## 4. Cắm vào hệ thống đang chạy

```bash
cp -R examples/mien-mau-thuy-san domains/thuy-san
# sửa .env: GRAPHQL_SCHEMAS=nen_tang,carbon,thuy_san
docker compose --env-file .env -f compose.yaml up -d --force-recreate migrate postgraphile
```

Nhật ký `migrate` in `migration: đã áp thuy-san/db/migrations/001_thuy_san.sql`. GraphQL có ngay các truy vấn `allThuySanAoNuois`, `thuySanAoNuoiByRowId`, gọi qua gateway `/graphql` với token Keycloak như miền carbon. Hệ thống đang chạy không phải dựng lại.

## 5. Rút ra

```bash
rm -rf domains/thuy-san
# sửa .env: bỏ thuy_san khỏi GRAPHQL_SCHEMAS
docker compose --env-file .env -f compose.yaml up -d --force-recreate postgraphile
```

API của miền biến mất ngay. Dữ liệu trong PostgreSQL **được giữ lại** (an toàn hơn xóa nhầm). Muốn xóa hẳn trên máy thử:

```sql
DROP SCHEMA thuy_san CASCADE;
DELETE FROM nen_tang.lich_su_migration WHERE ten LIKE 'thuy-san/%';
```

## 6. Kiểm thử

- Viết ca Hurl trong `tests/e2e/<miền>.hurl` theo mẫu `tests/e2e/carbon-rls.hurl`: đăng nhập hai người dùng mẫu, kiểm mỗi người chỉ thấy dữ liệu của mình.
- Chạy `task check` (SPDX + compose) và `task smoke` trước khi mở PR.

Đã thử ngày 03/11/2026 trên máy dev: cắm miền mẫu không sửa `platform/`; RLS đúng (người A thấy ao của A, người B không thấy, quản trị thấy tất cả); rút ra thì API của miền biến mất.
