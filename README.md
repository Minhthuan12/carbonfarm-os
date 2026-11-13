<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<p align="center"><img src="docs/images/banner.png" alt="CarbonFarm OS – Người dân sống được với rừng nhờ carbon" width="100%"></p>

# CarbonFarm OS

**Nền tảng nguồn mở tín chỉ carbon cho nông dân nhỏ, hợp tác xã và cộng đồng ven biển** · *An open-source carbon-credit platform for smallholders, cooperatives and coastal communities.*

> "Người dân sống được với rừng nhờ carbon." · *"People can live with the forest thanks to carbon."*

[![Giấy phép GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE) [![CI](https://github.com/carbonfarm-os/carbonfarm-os/actions/workflows/ci.yml/badge.svg)](https://github.com/carbonfarm-os/carbonfarm-os/actions/workflows/ci.yml)

Đội **DTU1** · OLP Phần mềm nguồn mở 2026 · Đề tài DX-OS Open-Core

Kho mã: https://github.com/carbonfarm-os/carbonfarm-os · Demo: https://carbonfarm.dzfullstack.com

## Mục lục
1. [Giới thiệu](#giới-thiệu--introduction)
2. [Bài toán và người dùng](#bài-toán-và-người-dùng--problem-and-users)
3. [Tính năng chính theo vai](#tính-năng-chính-theo-vai--features-by-role)
4. [Hình ảnh demo](#hình-ảnh-demo--screenshots)
5. [Kiến trúc](#kiến-trúc--architecture)
6. [Công nghệ sử dụng](#công-nghệ-sử-dụng--tech-stack)
7. [Cấu trúc thư mục](#cấu-trúc-thư-mục--repository-layout)
8. [Cài đặt](#cài-đặt--installation)
9. [Tài liệu](#tài-liệu--documentation)
10. [Đóng góp](#đóng-góp--contributing)
11. [Giấy phép](#giấy-phép--license)
12. [Đội DTU1](#đội-dtu1--team)
13. [Liên hệ](#liên-hệ--contact)

## Giới thiệu · Introduction
CarbonFarm OS số hóa **hợp tác xã** như một doanh nghiệp: quản lý xã viên, lô đất, hồ sơ đo lường – báo cáo – xác minh (MRV) và doanh thu từ tín chỉ carbon. Luồng chính:

**đăng ký lô đất → ước lượng carbon từ ảnh Sentinel-2 → duyệt MRV → cấp tín chỉ vào ví → bán cho người mua (mô phỏng) → kiểm chứng trên sổ cái có phiên bản**

*CarbonFarm OS digitises a cooperative: members, land plots, MRV records and credit revenue. Main flow: register a plot → estimate carbon from Sentinel-2 → review MRV → issue credits to a wallet → sell to a (mock) buyer → verify on a versioned ledger.*

Bản MVP: một hệ sinh thái (rừng ngập mặn), một khu vực mẫu, **dữ liệu hợp tác xã là dữ liệu giả**. Registry, người mua, ngân hàng là **connector mô phỏng**; Registry Connector thiết kế theo Thông tư 11/2026/TT-BNNMT. Đề xuất đầy đủ: [`docs/de-xuat.md`](docs/de-xuat.md).

## Bài toán và người dùng · Problem and users
- **Bài toán:** muốn được cấp tín chỉ carbon, nông dân và chủ rừng phải qua MRV. Các nền tảng carbon nông nghiệp hiện có đều đóng nguồn, nhắm thị trường Mỹ/EU, không có tiếng Việt và không làm rừng ngập mặn. Với nông dân nhỏ ở Việt Nam, MRV số hóa gần như chưa có, nên rừng ngập mặn do hợp tác xã giữ khó trở thành tín chỉ.
- **Cách giải:** hợp tác xã là đầu mối. Ước lượng carbon từ ảnh vệ tinh mở theo một phương pháp có phiên bản, cán bộ duyệt, mỗi con số truy được nguồn (cảnh ảnh, ngày chụp, tỷ lệ mây, phiên bản phương pháp, người duyệt), mỗi tín chỉ và giao dịch ghi vào sổ cái có phiên bản.
- **Người dùng:**

| Người dùng | Nhu cầu |
|---|---|
| Cán bộ hợp tác xã | Quản lý lô đất của xã viên, yêu cầu đo và duyệt MRV, cấp và bán tín chỉ, theo dõi doanh thu |
| Xã viên (nông dân nhỏ) | Đăng ký và xem lô đất của mình, biết lô đã đo, đã cấp bao nhiêu tín chỉ |
| Người mua tín chỉ (doanh nghiệp, quỹ) | Mua tín chỉ có nguồn gốc rõ ràng; trong MVP là connector mô phỏng |
| Người tra cứu công khai (cơ quan quản lý, báo chí, người mua) | Kiểm chứng một tín chỉ trên sổ cái mà không cần tài khoản |

*Smallholders lack digital MRV; CarbonFarm OS lets a cooperative estimate, review, issue, sell and publicly verify mangrove carbon credits.*

## Tính năng chính theo vai · Features by role
**Cán bộ hợp tác xã** (`canbo-htx-mau`, `canbo-htx-mau-2`)
- Vẽ ranh giới lô trên ảnh Sentinel-2. Cơ sở dữ liệu từ chối hình sai (UC001, UC002), diện tích ngoài 0,05–500 ha (UC003), diện tích khai lệch hình vẽ quá 10 % (UC004), lô chồng lấn lô đang hoạt động (UC005).
- Yêu cầu đo một kỳ: MRV engine tìm cảnh Sentinel-2 qua STAC, tính NDVI và CO₂e theo phương pháp trong [`methodology/`](methodology/), hiện lớp NDVI trên bản đồ.
- Duyệt hoặc từ chối kết quả MRV (từ chối phải có lý do). Kết quả duyệt được ghi vào sổ cái Dolt, có mã commit.
- Đề nghị cấp tín chỉ vào ví hợp tác xã qua **Registry Connector (mô phỏng)**, nhận dải số sê-ri theo Thông tư 11/2026/TT-BNNMT.
- Tạo lệnh bán cho người mua; **cán bộ thứ hai duyệt** (người tạo không tự duyệt được). Sau khi duyệt: **Buyer Connector (mô phỏng)** nhận đơn, Registry chuyển quyền sở hữu, **Bank Connector (mô phỏng)** ghi có tiền, sổ cái ghi giao dịch, ví trừ số tín chỉ.
- Xem dashboard hợp tác xã trên Metabase OSS: tín chỉ đã cấp, đã bán, còn trong ví, doanh thu, kết quả đo.

**Xã viên** (`xavien-mau-1`, `xavien-mau-2`)
- Chỉ thấy và sửa lô của mình (phân quyền theo dòng trong PostgreSQL). Đăng ký lô cho người khác bị từ chối (UC006).

**Người tra cứu công khai** (không cần tài khoản)
- Trang `/kiem-chung`: nhập số sê-ri tín chỉ hoặc mã commit Dolt, hệ thống đọc sổ cái, tính lại SHA-256 từng bản ghi và hiện chuỗi phả hệ các bản ghi nối tiếp (đo đạc, cấp, chuyển quyền).

**Người mua, Registry, ngân hàng:** chỉ là **connector mô phỏng** trong [`connectors/`](connectors/), mỗi cái có hợp đồng OpenAPI, dữ liệu giả, không xử lý tiền thật. Thay bằng hệ thống thật thì viết connector mới cùng hợp đồng, không sửa lõi.

**Quản trị:** UI quản trị của Keycloak, OpenBao, Prefect và Metabase (chỉ mở trên máy chạy hệ thống).

**Người phát triển:** thêm một miền nghiệp vụ mới mà không sửa Tầng 1 (cắm–rút), xem [`docs/viet-mien.md`](docs/viet-mien.md) và miền mẫu [`examples/mien-mau-thuy-san/`](examples/mien-mau-thuy-san/).

## Hình ảnh demo · Screenshots

**Demo công khai:** https://carbonfarm.dzfullstack.com (dữ liệu giả; tra tín chỉ không cần tài khoản: https://carbonfarm.dzfullstack.com/kiem-chung). Tự triển khai trên máy chủ: [`docs/trien-khai.md`](docs/trien-khai.md).

**App di động (Flutter, Android + iOS):** cán bộ hợp tác xã xem lô đất và ví tín chỉ; ai cũng quét QR hoặc gõ sê-ri để kiểm chứng. Hướng dẫn chạy và build: [`domains/carbon/di-dong/`](domains/carbon/di-dong/README.md).

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

## Kiến trúc · Architecture
- **Tầng 1 – `platform/`:** dịch vụ lõi tổng quát, không chứa nghiệp vụ carbon: SSO (Keycloak), API Gateway (APISIX), bí mật (OpenBao), dữ liệu có cấu trúc + không gian (PostgreSQL + PostGIS, PostGraphile), dữ liệu phi cấu trúc (Versity S3 + danh mục STAC + TiTiler), workflow (Prefect), event bus (Valkey), sổ cái có phiên bản (Dolt).
- **Tầng 2 – `domains/carbon/`:** miền tín chỉ carbon (H-P-D-I, trọng tâm [P] và [D]): hợp tác xã, lô đất, MRV engine, ví tín chỉ, web SvelteKit + MapLibre, dashboard Metabase.
- **`connectors/`:** Registry, Buyer, Bank mô phỏng, mỗi connector có hợp đồng OpenAPI; thay bằng API thật mà không sửa lõi.

![Sơ đồ kiến trúc hai tầng của CarbonFarm OS](docs/images/kien-truc.webp)

Chi tiết và sơ đồ: [`docs/architecture.md`](docs/architecture.md). Các quyết định: [`docs/adr/`](docs/adr/).
*Tier 1 is a generic headless platform; tier 2 holds the carbon domain; connectors are pluggable mocks. See `docs/architecture.md` and the ADRs.*

## Công nghệ sử dụng · Tech stack
Mọi thành phần chạy bằng image gốc, ghim phiên bản. Phiên bản, nguồn và ngày đọc giấy phép: [`DEPENDENCIES.md`](DEPENDENCIES.md).

| Thành phần | Vai trò | Giấy phép | Tầng |
|---|---|---|---|
| PostgreSQL 17 + PostGIS + pgSTAC | Dữ liệu có cấu trúc, không gian, danh mục STAC | PostgreSQL License / GPL-2.0-or-later / MIT | 1 |
| Keycloak 26.8.1 | Đăng nhập một lần (OIDC, PKCE), realm `dxos` | Apache-2.0 | 1 |
| Apache APISIX 3.19.0 | API Gateway, kiểm JWT bằng JWKS | Apache-2.0 | 1 |
| OpenBao 2.7.2 | Sinh và giữ mật khẩu dịch vụ | MPL-2.0 | 1 |
| PostGraphile 5.1.5 | API GraphQL tự sinh từ PostgreSQL, quyền bằng RLS | MIT | 1 |
| Versity S3 Gateway 1.10.0 | Lưu trữ đối tượng S3 (ảnh COG) | Apache-2.0 | 1 |
| stac-fastapi-pgstac 7.2.0 | API danh mục STAC | MIT | 1 |
| TiTiler 2.4.0 | Tile ảnh COG cho bản đồ | MIT | 1 |
| Prefect 3.9.0 | Workflow engine, flow có bước chờ duyệt | Apache-2.0 | 1 |
| Valkey 9.1.3 | Event bus (Streams) | BSD-3-Clause | 1 |
| Dolt 2.6.1 | Sổ cái có phiên bản, mỗi lần ghi là một commit có mã băm | Apache-2.0 | 1 |
| MRV engine (Python: rasterio + GDAL, numpy, psycopg, PyMySQL, boto3) | Ước lượng carbon từ Sentinel-2, ghi sổ cái | Mã dự án GPL-3.0-or-later; thư viện BSD-3-Clause, LGPL-3.0, MIT, Apache-2.0 | 2 |
| SvelteKit 3 + Svelte 5 + MapLibre GL JS 6 | Web người dùng cuối, bản đồ | MIT / BSD-3-Clause | 2 |
| Metabase OSS 0.64.3 | Dashboard hợp tác xã (dịch vụ riêng, image gốc, không sửa) | AGPL-3.0 | 2 |
| FastAPI + uvicorn + pydantic | Connector mô phỏng Registry, Buyer, Bank | MIT / BSD-3-Clause | connector |
| Sentinel-2 L2A (STAC Earth Search) | Ảnh vệ tinh mở | Dữ liệu mở Copernicus Sentinel | dữ liệu |

**Công cụ:** go-task, pixi, Hurl, pre-commit, ruff, yamllint, release-please, Syft (SBOM CycloneDX), Starlight (trang tài liệu). **Không dùng:** immudb (Business Source License), MinIO (repo đã lưu trữ), Google Earth Engine (dịch vụ độc quyền; đội chọn STAC + GDAL để tái lập được), `metabase-enterprise`.

## Cấu trúc thư mục · Repository layout
```text
carbonfarm-os/
├── platform/              # Tầng 1, không nghiệp vụ: apisix, keycloak, openbao, postgres, postgraphile, prefect, dolt
├── domains/carbon/        # Tầng 2 – miền carbon
│   ├── db/                #   migration, ràng buộc chống sai, dữ liệu giả
│   ├── mrv/               #   MRV engine Python (Sentinel-2 → NDVI → CO₂e)
│   ├── web/               #   web SvelteKit + MapLibre
│   ├── di-dong/           #   app di động Flutter (Android + iOS)
│   ├── dashboard/         #   script dựng dashboard Metabase
│   ├── keycloak/          #   người dùng mẫu của miền
│   └── gateway/           #   route APISIX của miền
├── connectors/            # Registry, Buyer, Bank mô phỏng, mỗi cái một openapi.yaml
├── methodology/           # Phương pháp ước lượng carbon có phiên bản, kèm trích dẫn
├── compose.yaml           # Điểm vào Docker Compose, ghép compose/*.yaml bằng include
├── compose/               # platform.yaml, carbon.yaml, connectors.yaml
├── tests/                 # e2e/*.hurl (đầu-cuối), tich-hop/ (Python)
├── examples/              # miền mẫu thủy sản (ví dụ cắm–rút)
├── docs/                  # kiến trúc, đề xuất, ADR, dùng thử, triển khai, kịch bản demo
├── docs-site/             # trang tài liệu Starlight
├── scripts/spdx.py        # kiểm và thêm header SPDX
└── Taskfile.yml           # lệnh go-task
```

## Cài đặt · Installation
### Yêu cầu hệ thống
- **Docker Engine + Docker Compose v2** (cần hỗ trợ `include:` trong compose), **go-task**. Python + GDAL cho máy dev: `pixi install` hoặc Dev Container.
- **RAM:** đo bằng `docker stats` ngay sau khi dựng (v0.5.0), toàn bộ stack dùng khoảng 3,9 GB, trong đó Metabase khoảng 1,8 GB, Keycloak khoảng 0,8 GB. Thiếu RAM thì tắt Metabase, các luồng chính vẫn chạy ([`docs/trien-khai.md`](docs/trien-khai.md)).
- **Ổ đĩa:** các image Docker của stack cộng lại khoảng 10,4 GB (đo bằng `docker image inspect` trên máy dev arm64, chưa trừ lớp dùng chung), cộng thêm chỗ cho volume dữ liệu.
- **Internet:** MRV tải ảnh Sentinel-2 từ Earth Search.
- **Hệ điều hành đã chạy thật:** macOS trên Apple Silicon (máy dev) và Ubuntu trên máy chủ demo. Windows chưa thử.

### Chạy trên một máy
```bash
cp .env.example .env      # cấu hình máy dev · dev configuration
task up                   # chạy dịch vụ · start services (go-task)
task smoke                # kiểm thử đầu-cuối bằng Hurl · end-to-end checks
task check                # SPDX + compose, trước mọi PR · before every PR
```
Lệnh khác trong [`Taskfile.yml`](Taskfile.yml): `task down` (dừng, giữ volume), `task seed` (nạp dữ liệu giả), `task test` (kiểm thử không cần hệ thống chạy), `task lint`, `task license` (thêm header SPDX), `task tai-lieu` (build trang tài liệu). Môi trường dev dùng chung: Dev Container hoặc `pixi install` (xem [`CONTRIBUTING.md`](CONTRIBUTING.md)).

Bản mới nhất **v0.7.0** chạy đủ luồng chính trên một máy: Tầng 1 (OpenBao, PostgreSQL + PostGIS + pgSTAC, Keycloak, APISIX, PostGraphile, Versity S3 + STAC + TiTiler, Prefect, Valkey, Dolt) và Tầng 2 (MRV engine, web, connector mô phỏng, Metabase).

| Địa chỉ | Nội dung |
|---|---|
| http://localhost:9080/ | Web: trang chủ, đăng nhập cán bộ, bản đồ lô đất, MRV, ví và lệnh bán |
| http://localhost:9080/kiem-chung | Tra tín chỉ trên sổ cái, không cần tài khoản |
| http://127.0.0.1:3001/ | Dashboard hợp tác xã (Metabase OSS) |

Người dùng mẫu (`canbo-htx-mau`, `canbo-htx-mau-2`, `xavien-mau-1`…) có mật khẩu do OpenBao sinh khi dựng: `docker compose exec keycloak cat /run/bimat/mk-<tên>` (ví dụ `mk-canbo-htx-mau`). Lần chạy đầu OpenBao ghi khóa mở vào `.data/openbao/` (ngoài git) – **giữ kín, mất là không mở được dữ liệu OpenBao**. Dùng thử theo kịch bản: [`docs/thu-nghiem.md`](docs/thu-nghiem.md).
*v0.7.0 runs the full flow locally; sample users get generated passwords; see `docs/thu-nghiem.md` for a guided trial.*

Triển khai trên máy chủ có HTTPS: [`docs/trien-khai.md`](docs/trien-khai.md).

## Tài liệu · Documentation
Trang tài liệu (có tìm kiếm): https://carbonfarm-os.github.io/carbonfarm-os/

| Tài liệu | Nội dung |
|---|---|
| [`docs/de-xuat.md`](docs/de-xuat.md) | Đề xuất: bài toán, phạm vi MVP |
| [`docs/architecture.md`](docs/architecture.md) | Kiến trúc hai tầng, sơ đồ |
| [`docs/adr/`](docs/adr/) | Các quyết định kiến trúc (ADR) |
| [`methodology/`](methodology/) | Phương pháp ước lượng carbon có phiên bản |
| [`connectors/README.md`](connectors/README.md) | Connector mô phỏng và hợp đồng OpenAPI |
| [`docs/thu-nghiem.md`](docs/thu-nghiem.md) | Hướng dẫn dùng thử theo sáu nhiệm vụ |
| [`docs/trien-khai.md`](docs/trien-khai.md) | Triển khai demo công khai |
| [`docs/viet-mien.md`](docs/viet-mien.md) | Viết một miền nghiệp vụ mới (cắm–rút) |
| [`docs/demo/kich-ban-15-phut.md`](docs/demo/kich-ban-15-phut.md) | Kịch bản trình bày 15 phút |
| [`docs/roadmap.md`](docs/roadmap.md) | Lộ trình |
| [`CHANGELOG.md`](CHANGELOG.md) | Thay đổi theo phiên bản |

## Đóng góp · Contributing
Trunk-based, Conventional Commits, PR do chủ vùng mã duyệt, phát hành tự động bằng release-please: [`CONTRIBUTING.md`](CONTRIBUTING.md). Quy tắc ứng xử: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
- Báo lỗi, góp ý: [GitHub Issues](https://github.com/carbonfarm-os/carbonfarm-os/issues) (mẫu "Báo lỗi", "Phản hồi dùng thử"); hỏi đáp: [Discussions](https://github.com/carbonfarm-os/carbonfarm-os/discussions).
- Việc cho người mới: nhãn [`good first issue`](https://github.com/carbonfarm-os/carbonfarm-os/labels/good%20first%20issue).
- Thêm một miền nghiệp vụ mới mà không sửa Tầng 1 (cắm–rút), kèm miền mẫu thủy sản: [`docs/viet-mien.md`](docs/viet-mien.md).

## Giấy phép · License
Mã nguồn: **GPL-3.0-or-later** ([`LICENSE`](LICENSE)). Chọn copyleft để mọi bản sửa đổi của nền tảng MRV công khai cho cộng đồng, giúp con số carbon kiểm chứng được. Thành phần bên thứ ba: [`DEPENDENCIES.md`](DEPENDENCIES.md), [`NOTICE`](NOTICE).
*Source code is GPL-3.0-or-later so that every modified MRV platform stays open and its carbon numbers remain verifiable.*

## Đội DTU1 · Team
| Thành viên (GitHub) | Vai | Phụ trách (theo [`CODEOWNERS`](.github/CODEOWNERS)) |
|---|---|---|
| [`Minhthuan12`](https://github.com/Minhthuan12) | Trưởng nhóm, V1 | Nền tảng Tầng 1 (`platform/`, `compose/`), DevOps, CI, bảo mật |
| [`Nhvuu918`](https://github.com/Nhvuu918) | V2 | Dữ liệu, ảnh vệ tinh, MRV, sổ cái (`domains/carbon/`, `methodology/`, `connectors/`) |
| [`tamdoannguyen06-cmyk`](https://github.com/tamdoannguyen06-cmyk) | V3 | Web, bản đồ, dashboard (`domains/carbon/web/`, `domains/carbon/dashboard/`) |

## Liên hệ · Contact
- Báo lỗi, đề xuất tính năng: [GitHub Issues](https://github.com/carbonfarm-os/carbonfarm-os/issues).
- Hỏi đáp, trao đổi: [GitHub Discussions](https://github.com/carbonfarm-os/carbonfarm-os/discussions).
