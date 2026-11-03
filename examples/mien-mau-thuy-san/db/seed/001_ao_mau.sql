-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Dữ liệu GIẢ của miền mẫu; chạy lại không nhân đôi. Chủ là 'he-thong' nên chỉ quản trị thấy.
INSERT INTO thuy_san.ao_nuoi (id, ten, dien_tich_m2, doi_tuong, chu_sub) VALUES
  ('00000000-0000-4000-8000-00000000a001', 'Ao mẫu số 1', 2500, 'tom_su', 'he-thong'),
  ('00000000-0000-4000-8000-00000000a002', 'Ao mẫu số 2', 1800, 'cua', 'he-thong')
ON CONFLICT (id) DO NOTHING;
