<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# 0008 · Trang tài liệu bằng Starlight, nội dung chép từ docs/

- Trạng thái: chấp nhận
- Ngày: 2026-11-02
- Người viết: @Minhthuan12
- Issue / PR: #53

## Bối cảnh
Tài liệu (kiến trúc, ADR, phương pháp MRV, hướng dẫn dùng thử) nằm rải trong `docs/`, `methodology/`, README. Người dùng thử, ban giám khảo và người muốn dùng lại phương pháp cần một trang đọc liền mạch, có mục lục và tìm kiếm. Thang điểm sản phẩm có tiêu chí "phát triển bền vững (tài liệu kỹ thuật, công cụ hỗ trợ)". Ràng buộc: nguồn mở, một nguồn sự thật (không chép tay hai nơi), không dùng công cụ của đội khác trong trường.

## Các phương án
Giấy phép đọc từ tệp LICENSE trong gói npm ngày 02/11/2026.

| Phương án | Giấy phép | Ưu | Nhược |
|---|---|---|---|
| Starlight 0.42 (Astro 7) | MIT | Tìm kiếm tĩnh (Pagefind, MIT) sẵn, giao diện tiếng Việt, cùng hệ Node với web Tầng 2 | Thêm ~350 gói npm lúc build |
| GitHub chỉ đọc Markdown | — | Không thêm gì | Không mục lục chung, không tìm kiếm, không đọc được ngoài GitHub |
| VitePress | MIT | Nhẹ | Ít sẵn thành phần tài liệu (sửa trang, mục lục ADR tự sinh) hơn Starlight |

## Quyết định
Dùng Starlight trong `docs-site/`. Nội dung **không** viết lại: `docs-site/scripts/chep-tai-lieu.mjs` chép README, `docs/thu-nghiem.md`, `docs/architecture.md`, `docs/roadmap.md`, `methodology/*.md`, `docs/adr/*.md` vào `src/content/docs/` (ngoài git) lúc build, sửa liên kết tương đối thành trang trên site hoặc tệp trên GitHub. Mỗi trang có nút sửa trỏ về tệp gốc.

## Hệ quả
- Starlight, Astro chỉ chạy lúc build; sản phẩm là HTML tĩnh, không nằm trong image nào của hệ thống. Khai ở mục công cụ phát triển của `DEPENDENCIES.md`.
- Gói gián tiếp có libvips (LGPL-3.0-or-later, qua `sharp`) chỉ dùng xử lý ảnh lúc build, không phân phối trong repo.
- CI build trang ở mọi PR (job `tai-lieu`). Công bố lên GitHub Pages cần bật Pages cho repo: việc riêng, khi người hướng dẫn đồng ý.
- Sơ đồ Mermaid hiện dạng mã trên site; ảnh `docs/images/kien-truc.webp` thay cho phần tóm tắt.
