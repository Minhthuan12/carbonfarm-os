<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Triển khai demo công khai

Hướng dẫn chạy CarbonFarm OS trên một máy chủ Linux, sau reverse proxy HTTPS. Bản demo của đội chạy theo đúng các bước này: **https://carbonfarm.dzfullstack.com** (tra tín chỉ không cần tài khoản: https://carbonfarm.dzfullstack.com/kiem-chung).

Bản demo dùng **dữ liệu giả** (hợp tác xã, xã viên, lô đất, người mua); Registry, Buyer, Bank là connector mô phỏng.

## 1. Cần chuẩn bị
- Máy chủ Linux có Docker Engine + Docker Compose v2, truy cập được Internet (MRV tải ảnh Sentinel-2 từ Earth Search).
- RAM: đo bằng `docker stats` ngay sau khi dựng (v0.5.0, 19 container), toàn bộ stack dùng khoảng 3,9 GB, trong đó Metabase khoảng 1,8 GB và Keycloak khoảng 0,8 GB. Máy chủ thiếu RAM thì tắt Metabase (`docker compose stop metabase`), các luồng chính vẫn chạy.
- Một tên miền trỏ về máy chủ và một reverse proxy có HTTPS (nginx, Caddy, Traefik… tùy máy chủ). Stack không tự xin chứng chỉ.

## 2. Cấu hình
```bash
git clone https://github.com/carbonfarm-os/carbonfarm-os.git
cd carbonfarm-os
git checkout v0.6.0          # hoặc bản phát hành mới nhất
cp .env.example .env
```
Sửa `.env`:

| Biến | Giá trị trên máy chủ | Ghi chú |
|---|---|---|
| `PUBLIC_URL` | `https://<tên-miền>` (không có `/` ở cuối) | Keycloak hostname, issuer JWT của PostGraphile, `ORIGIN` của web và redirect URI của client web đều đọc biến này |
| `GATEWAY_PORT` | cổng nội bộ cho reverse proxy, ví dụ `19380` | APISIX chỉ nghe ở `127.0.0.1` |
| `OPENBAO_PORT`, `PREFECT_PORT`, `METABASE_PORT` | cổng chưa dùng trên máy chủ | UI quản trị, chỉ nghe ở `127.0.0.1`; mở qua đường hầm SSH khi cần |
| `NAP_DU_LIEU_MAU` | `true` | nạp hợp tác xã, xã viên, lô đất giả lúc dựng |

**Đặt `PUBLIC_URL` trước lần chạy đầu.** Realm Keycloak được nhập một lần lúc dựng, redirect URI của client web lấy từ `PUBLIC_URL` tại thời điểm đó. Đổi tên miền sau khi đã dựng thì phải sửa redirect URI trong Keycloak hoặc dựng lại từ volume trống.

## 3. Chạy
```bash
task up        # hoặc: mkdir -p .data/openbao && docker compose --env-file .env -f compose.yaml up -d --wait
```
Lần chạy đầu OpenBao ghi khóa mở vào `.data/openbao/`. **Sao lưu thư mục này ra nơi an toàn và không xóa**: mất khóa là không mở được bí mật, phải dựng lại từ đầu.

Compose không đặt `restart` cho dịch vụ chạy lâu (máy dev không cần). Trên máy chủ, cho container tự chạy lại sau khi khởi động lại máy:
```bash
docker update --restart unless-stopped $(docker compose --env-file .env -f compose.yaml ps -q)
```

## 4. Reverse proxy
Chuyển toàn bộ tên miền về `http://127.0.0.1:<GATEWAY_PORT>`. Mọi đường dẫn (`/`, `/auth`, `/graphql`, `/stac`, `/tiles`, `/kiem-chung`…) đi qua APISIX, không cần route riêng.

Reverse proxy cần gửi kèm:
- `Host` của tên miền;
- `X-Forwarded-For`, `X-Forwarded-Proto: https`: Keycloak đọc các header này (`KC_PROXY_HEADERS=xforwarded`) để biết đang chạy sau HTTPS.

Ví dụ khối `location` của nginx:
```nginx
location / {
    proxy_pass http://127.0.0.1:19380;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
}
```

**Đứng sau Cloudflare.** API kiểm chứng công khai (`/kiem-chung/api/*`) giới hạn 60 yêu cầu/phút cho mỗi người dùng. Sau reverse proxy, APISIX chỉ thấy địa chỉ của proxy, nên route đếm theo header `CF-Connecting-IP` mà Cloudflare gửi kèm (`domains/carbon/gateway/routes.yaml`). nginx chuyển tiếp header này theo mặc định. Không dùng Cloudflare thì header vắng và giới hạn tính theo địa chỉ proxy (chung cho mọi người): khi đó đặt header riêng chứa IP thật ở reverse proxy và sửa `key` của route cho khớp.

## 5. Dữ liệu demo và tài khoản
- Người dùng mẫu (`canbo-htx-mau`, `canbo-htx-mau-2`, `xavien-mau-1`) có mật khẩu do OpenBao sinh, mỗi máy một khác:
  ```bash
  docker compose --env-file .env -f compose.yaml exec keycloak cat /run/bimat/mk-canbo-htx-mau
  ```
  Đưa mật khẩu trực tiếp cho người được mời thử; không ghi vào issue, tài liệu hay tin nhắn nhóm.
- Để trang kiểm chứng có sẵn tín chỉ, đăng nhập `canbo-htx-mau` và làm một lượt nhiệm vụ 3–5 trong [`thu-nghiem.md`](thu-nghiem.md): yêu cầu đo MRV, duyệt, cấp tín chỉ, tạo lệnh bán, rồi duyệt lệnh bán bằng `canbo-htx-mau-2`.
- Mời người dùng thử theo [`thu-nghiem.md`](thu-nghiem.md); mỗi phản hồi một issue bằng mẫu "Phản hồi dùng thử".

## 6. Kiểm sau khi triển khai
```bash
curl -s https://<tên-miền>/kiem-chung/api/tong-quan          # JSON tổng quan sổ cái
curl -s https://<tên-miền>/auth/realms/dxos/.well-known/openid-configuration | grep issuer
```
`issuer` phải bắt đầu bằng `https://<tên-miền>/auth`. Sai thì kiểm lại `PUBLIC_URL` và header `X-Forwarded-Proto`.

## 7. Cập nhật lên bản mới
```bash
git fetch --tags && git checkout vX.Y.Z
docker compose --env-file .env -f compose.yaml up -d --wait --build
docker compose --env-file .env -f compose.yaml restart apisix
```
`up --build` dựng lại image của dự án và áp migration mới của miền (dịch vụ `migrate`). APISIX ghép route Tầng 1 với `domains/*/gateway/routes.yaml` **lúc khởi động**, mà Compose không tạo lại container khi chỉ tệp route đổi, nên cần `restart apisix` để nhận route mới. Volume và `.data/openbao/` giữ nguyên. Đọc `CHANGELOG.md` trước khi cập nhật.
