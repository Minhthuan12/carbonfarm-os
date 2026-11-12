<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<p align="center"><img src="docs/images/banner.png" alt="CarbonFarm OS – Người dân sống được với rừng nhờ carbon" width="100%"></p>

# CarbonFarm OS

**Nền tảng nguồn mở tín chỉ carbon cho nông dân nhỏ, hợp tác xã và cộng đồng ven biển** · *An open-source carbon-credit platform for smallholders, cooperatives and coastal communities.*

> "Người dân sống được với rừng nhờ carbon." · *"People can live with the forest thanks to carbon."*

[![Giấy phép GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE) [![CI](https://github.com/carbonfarm-os/carbonfarm-os/actions/workflows/ci.yml/badge.svg)](https://github.com/carbonfarm-os/carbonfarm-os/actions/workflows/ci.yml)

Kho mã: https://github.com/carbonfarm-os/carbonfarm-os · Kế hoạch sprint: https://github.com/orgs/carbonfarm-os/projects/1

> ⚠️ **Điều kiện dự thi · Eligibility.** Dự án do nhóm DTU3 làm cho OLP PMNM 2026. Thể lệ cho phép tối đa 2 đội mỗi trường; một đội của trường đã rút và DTU3 đăng ký thay suất đó. **Trạng thái: chờ trường xác nhận.**
> *One of the school's two registered teams has withdrawn and DTU3 is registering in its place. Status: pending confirmation by the school.*

## Giới thiệu · Introduction
CarbonFarm OS số hóa **hợp tác xã** như một doanh nghiệp: quản lý xã viên, lô đất, hồ sơ đo lường – báo cáo – xác minh (MRV) và doanh thu từ tín chỉ carbon. Luồng chính:

**đăng ký lô đất → ước lượng carbon từ ảnh Sentinel-2 → duyệt MRV → cấp tín chỉ vào ví → bán cho người mua (mô phỏng) → kiểm chứng trên sổ cái có phiên bản**

*CarbonFarm OS digitises a cooperative: members, land plots, MRV records and credit revenue. Main flow: register a plot → estimate carbon from Sentinel-2 → review MRV → issue credits to a wallet → sell to a (mock) buyer → verify on a versioned ledger.*

Bản MVP: một hệ sinh thái (rừng ngập mặn), một khu vực mẫu, **dữ liệu hợp tác xã là dữ liệu giả**. Registry, người mua, ngân hàng là **connector mô phỏng**; Registry Connector thiết kế theo Thông tư 11/2026/TT-BNNMT. Đề xuất đầy đủ: [`docs/de-xuat.md`](docs/de-xuat.md).

## Kiến trúc · Architecture
- **Tầng 1 – `platform/`:** dịch vụ lõi tổng quát, không chứa nghiệp vụ carbon: SSO (Keycloak), API Gateway (APISIX), bí mật (OpenBao), dữ liệu có cấu trúc + không gian (PostgreSQL + PostGIS, PostGraphile), dữ liệu phi cấu trúc (Versity S3 + danh mục STAC + TiTiler), workflow (Prefect), event bus (Valkey), sổ cái có phiên bản (Dolt).
- **Tầng 2 – `domains/carbon/`:** miền tín chỉ carbon (H-P-D-I, trọng tâm [P] và [D]): hợp tác xã, lô đất, MRV engine, ví tín chỉ, web SvelteKit + MapLibre, dashboard Metabase.
- **`connectors/`:** Registry, Buyer, Bank mô phỏng, mỗi connector có hợp đồng OpenAPI; thay bằng API thật mà không sửa lõi.

![Sơ đồ kiến trúc hai tầng của CarbonFarm OS](docs/images/kien-truc.webp)

Trang tài liệu (kiến trúc, phương pháp MRV, ADR, dùng thử, có tìm kiếm): https://carbonfarm-os.github.io/carbonfarm-os/

**Demo công khai:** https://carbonfarm.dzfullstack.com (dữ liệu giả; tra tín chỉ không cần tài khoản: https://carbonfarm.dzfullstack.com/kiem-chung). Tự triển khai trên máy chủ: [`docs/trien-khai.md`](docs/trien-khai.md).

### Hình ảnh demo · Screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/images/demo/01-trang-chu.webp" alt="Trang chủ công khai của CarbonFarm OS"><br>1. [H] Trang chủ công khai – giới thiệu luồng và thẻ tài khoản mẫu</td>
    <td width="50%"><img src="docs/images/demo/02-dang-ky-lo-chong-lan.webp" alt="Đăng ký lô bị từ chối vì ranh giới chồng lấn"><br>2. [P] Đăng ký lô (cán bộ HTX) – cơ sở dữ liệu từ chối ranh giới chồng lấn (UC005)</td>
  </tr>
  <tr>
    <td><img src="docs/images/demo/03-duyet-mrv-cap-tin-chi.webp" alt="Duyệt kết quả MRV và cấp 15 tín chỉ"><br>3. [P] Duyệt MRV (cán bộ HTX) – ghi sổ cái, cấp 15 tín chỉ, ví lên 25</td>
    <td><img src="docs/images/demo/04-ban-hai-can-bo-duyet.webp" alt="Bán 3 tín chỉ, cán bộ thứ hai duyệt"><br>4. [P] Bán 3 tín chỉ – cán bộ thứ hai duyệt chéo, ví còn 22</td>
  </tr>
  <tr>
    <td><img src="docs/images/demo/05-kiem-chung.webp" alt="Kiểm chứng tín chỉ trên sổ cái: Toàn vẹn"><br>5. [D] Kiểm chứng công khai (không cần tài khoản) – sổ cái Dolt báo "Toàn vẹn."</td>
    <td><img src="docs/images/demo/06-dashboard.webp" alt="Dashboard hợp tác xã trên Metabase"><br>6. [D] Dashboard hợp tác xã (Metabase OSS) – tín chỉ, doanh thu, kết quả đo</td>
  </tr>
</table>

Dữ liệu giả. Ảnh nền chứa dữ liệu Copernicus Sentinel đã qua xử lý (2026). Kịch bản trình bày: [`docs/demo/kich-ban-15-phut.md`](docs/demo/kich-ban-15-phut.md).

Chi tiết và sơ đồ: [`docs/architecture.md`](docs/architecture.md). Các quyết định: [`docs/adr/`](docs/adr/).
*Tier 1 is a generic headless platform; tier 2 holds the carbon domain; connectors are pluggable mocks. See `docs/architecture.md` and the ADRs.*

## Bắt đầu · Getting started
Bản mới nhất **v0.6.0** chạy đủ luồng chính trên một máy: Tầng 1 (OpenBao, PostgreSQL + PostGIS + pgSTAC, Keycloak, APISIX, PostGraphile, Versity S3 + STAC + TiTiler, Prefect, Valkey, Dolt) và Tầng 2 (MRV engine, web, connector mô phỏng, Metabase).

| Địa chỉ | Nội dung |
|---|---|
| http://localhost:9080/ | Web: trang chủ, đăng nhập cán bộ, bản đồ lô đất, MRV, ví và lệnh bán |
| http://localhost:9080/kiem-chung | Tra tín chỉ trên sổ cái, không cần tài khoản |
| http://127.0.0.1:3001/ | Dashboard hợp tác xã (Metabase OSS) |

Người dùng mẫu (`canbo-htx-mau`, `canbo-htx-mau-2`, `xavien-mau-1`…) có mật khẩu do OpenBao sinh khi dựng: `docker compose exec keycloak cat /run/bimat/mk-<tên>` (ví dụ `mk-canbo-htx-mau`). Lần chạy đầu OpenBao ghi khóa mở vào `.data/openbao/` (ngoài git) – **giữ kín, mất là không mở được dữ liệu OpenBao**. Dùng thử theo kịch bản: [`docs/thu-nghiem.md`](docs/thu-nghiem.md).
*v0.6.0 runs the full flow locally; sample users get generated passwords; see `docs/thu-nghiem.md` for a guided trial.*

```bash
cp .env.example .env      # cấu hình máy dev · dev configuration
task up                   # chạy dịch vụ · start services (go-task)
task smoke                # kiểm thử đầu-cuối bằng Hurl · end-to-end checks
task check                # SPDX + compose, trước mọi PR · before every PR
```
Môi trường dev dùng chung: Dev Container hoặc `pixi install` (xem [`CONTRIBUTING.md`](CONTRIBUTING.md)).

## Đóng góp · Contributing
Trunk-based, Conventional Commits, PR do chủ vùng mã duyệt, phát hành tự động bằng release-please: [`CONTRIBUTING.md`](CONTRIBUTING.md). Quy tắc ứng xử: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
- Báo lỗi, góp ý: [GitHub Issues](https://github.com/carbonfarm-os/carbonfarm-os/issues) (mẫu "Báo lỗi", "Phản hồi dùng thử"); hỏi đáp: [Discussions](https://github.com/carbonfarm-os/carbonfarm-os/discussions).
- Việc cho người mới: nhãn [`good first issue`](https://github.com/carbonfarm-os/carbonfarm-os/labels/good%20first%20issue).
- Thêm một miền nghiệp vụ mới mà không sửa Tầng 1 (cắm–rút), kèm miền mẫu thủy sản: [`docs/viet-mien.md`](docs/viet-mien.md).

## Giấy phép · License
Mã nguồn: **GPL-3.0-or-later** ([`LICENSE`](LICENSE)). Chọn copyleft để mọi bản sửa đổi của nền tảng MRV công khai cho cộng đồng, giúp con số carbon kiểm chứng được. Thành phần bên thứ ba: [`DEPENDENCIES.md`](DEPENDENCIES.md), [`NOTICE`](NOTICE).
*Source code is GPL-3.0-or-later so that every modified MRV platform stays open and its carbon numbers remain verifiable.*
