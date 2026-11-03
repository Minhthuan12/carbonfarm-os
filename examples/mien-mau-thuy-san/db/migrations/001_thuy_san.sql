-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Miền MẪU "thủy sản" (ví dụ cắm–rút, không thuộc sản phẩm): hộ nuôi khai báo ao nuôi tôm.
-- Chỉ dùng thứ Tầng 1 cung cấp: vai vai_nguoi_dung / vai_quan_tri, hàm nen_tang.nguoi_goi() (sub trong JWT),
-- RLS của PostgreSQL. Không sửa gì trong platform/. Xem docs/viet-mien.md.

CREATE SCHEMA thuy_san;
COMMENT ON SCHEMA thuy_san IS 'Miền mẫu thủy sản (ví dụ cắm–rút)';
GRANT USAGE ON SCHEMA thuy_san TO vai_nguoi_dung, vai_quan_tri;

CREATE TABLE thuy_san.ao_nuoi (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ten         text NOT NULL CHECK (length(btrim(ten)) BETWEEN 2 AND 120),
  dien_tich_m2 numeric(10, 1) NOT NULL CHECK (dien_tich_m2 > 0 AND dien_tich_m2 <= 100000),
  doi_tuong   text NOT NULL DEFAULT 'tom_su' CHECK (doi_tuong IN ('tom_su', 'tom_the', 'cua')),
  chu_sub     text NOT NULL DEFAULT coalesce(nen_tang.nguoi_goi(), 'he-thong'),
  tao_luc     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE thuy_san.ao_nuoi IS 'Ao nuôi của hộ; mỗi người chỉ thấy ao của mình';
COMMENT ON COLUMN thuy_san.ao_nuoi.chu_sub IS E'@behavior -*\nKhông lộ qua API';

GRANT SELECT ON thuy_san.ao_nuoi TO vai_nguoi_dung, vai_quan_tri;
GRANT INSERT (ten, dien_tich_m2, doi_tuong) ON thuy_san.ao_nuoi TO vai_nguoi_dung, vai_quan_tri;
GRANT UPDATE (ten, dien_tich_m2, doi_tuong) ON thuy_san.ao_nuoi TO vai_nguoi_dung, vai_quan_tri;

ALTER TABLE thuy_san.ao_nuoi ENABLE ROW LEVEL SECURITY;
ALTER TABLE thuy_san.ao_nuoi FORCE ROW LEVEL SECURITY;
CREATE POLICY quan_tri ON thuy_san.ao_nuoi FOR ALL TO vai_quan_tri USING (true) WITH CHECK (true);
CREATE POLICY cua_toi ON thuy_san.ao_nuoi FOR ALL TO vai_nguoi_dung
  USING (chu_sub = nen_tang.nguoi_goi()) WITH CHECK (chu_sub = nen_tang.nguoi_goi());
