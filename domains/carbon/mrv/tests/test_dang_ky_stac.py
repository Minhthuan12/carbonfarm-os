# SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
# SPDX-License-Identifier: GPL-3.0-or-later
"""Đăng ký item STAC của kết quả MRV (luu_tru.dang_ky_stac) trên STAC giả lập bằng httpx.MockTransport.

Không cần hệ thống chạy, không cần GDAL: các thư viện nặng mà luu_tru nhập (rasterio, numpy, psycopg, boto3, PyMySQL)
được thay bằng mô-đun rỗng nếu máy không có. Ca chính là lỗi #60: hai lượt đo song song cùng tạo bộ sưu tập, lượt sau
nhận 409 và không được hỏng.
"""
from __future__ import annotations

import importlib.util
import sys
import types
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

CO_HTTPX = importlib.util.find_spec("httpx") is not None
if CO_HTTPX:
    import httpx

    thieu = [g for g in ("boto3", "numpy", "psycopg", "pymysql", "rasterio") if importlib.util.find_spec(g) is None]
    for ten in ("boto3", "numpy", "psycopg", "psycopg.rows", "pymysql", "rasterio", "rasterio.io"):
        if ten.split(".")[0] in thieu:
            sys.modules[ten] = types.ModuleType(ten)
    sys.modules["psycopg.rows"].dict_row = getattr(sys.modules["psycopg.rows"], "dict_row", None)
    sys.modules["rasterio.io"].MemoryFile = getattr(sys.modules["rasterio.io"], "MemoryFile", None)
    from mrv import luu_tru

ITEM = {"type": "Feature", "id": "kq-1", "collection": "carbon-mrv"}


@unittest.skipUnless(CO_HTTPX, "cần httpx")
class DangKyStac(unittest.TestCase):
    def chay(self, tra_loi: dict[tuple[str, str], int]) -> list[tuple[str, str]]:
        """Gọi dang_ky_stac trên STAC giả; tra_loi ánh xạ (phương thức, đường dẫn) → mã HTTP. Trả các yêu cầu đã gửi."""
        da_goi: list[tuple[str, str]] = []

        def xu_ly(req: httpx.Request) -> httpx.Response:
            khoa = (req.method, req.url.path)
            da_goi.append(khoa)
            return httpx.Response(tra_loi.get(khoa, 200), json={})

        goc = httpx.Client
        luu_tru.httpx.Client = lambda **kw: goc(transport=httpx.MockTransport(xu_ly), **kw)
        try:
            luu_tru.dang_ky_stac(ITEM)
        finally:
            luu_tru.httpx.Client = goc
        return da_goi

    def test_bo_suu_tap_vua_duoc_luot_khac_tao_thi_di_tiep(self):
        goi = self.chay({("GET", "/collections/carbon-mrv"): 404, ("POST", "/collections"): 409})
        self.assertIn(("POST", "/collections/carbon-mrv/items"), goi)

    def test_loi_khac_khi_tao_bo_suu_tap_van_bao(self):
        with self.assertRaises(httpx.HTTPStatusError):
            self.chay({("GET", "/collections/carbon-mrv"): 404, ("POST", "/collections"): 500})

    def test_da_co_bo_suu_tap_thi_khong_tao_lai(self):
        goi = self.chay({})
        self.assertNotIn(("POST", "/collections"), goi)

    def test_item_da_co_thi_cap_nhat(self):
        goi = self.chay({("POST", "/collections/carbon-mrv/items"): 409})
        self.assertEqual(goi[-1], ("PUT", "/collections/carbon-mrv/items/kq-1"))


if __name__ == "__main__":
    unittest.main()
