<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!--
	Trang công khai ở /: giới thiệu phương pháp đo + số liệu thật rút từ sổ cái Dolt (/kiem-chung/api/tong-quan, chỉ đọc,
	không định danh xã viên). Sổ cái trống hoặc API lỗi thì hiện trạng thái trống/lỗi, không có số dự phòng.
	Thẻ tài khoản mẫu chỉ mở trang đăng nhập Keycloak thật với tên đăng nhập điền sẵn (login_hint); vẫn phải nhập mật khẩu.
-->
<script lang="ts">
	import 'maplibre-gl/dist/maplibre-gl.css';
	import { onMount } from 'svelte';
	import { LngLatBounds, Map as BanDo, ScaleControl } from 'maplibre-gl';
	import { batDauDangNhap } from './dang-nhap.ts';
	import { kieuBanDo, NEN, themLopLo } from './ban-do.ts';

	type Polygon = { type: 'Polygon'; coordinates: [number, number][][] };
	type TongQuan = {
		so_ket_qua_mrv: number;
		co2e_da_ghi_so_tan: number;
		tin_chi_da_cap: number;
		tin_chi_da_ban: number;
		seri_moi_nhat: string | null;
		lo_da_do: { id: string; ten: string; ranh_gioi: Polygon }[];
		ket_qua_moi_nhat: {
			lo_dat_id: string;
			ten_lo: string;
			ranh_gioi: Polygon;
			dien_tich_tan_ha: number;
			co2e_tan: number;
			ndvi_tb_tan: number | null;
			ngay_chup: string | null;
			may_toan_canh: number | null;
			commit: string;
		} | null;
	};

	/** Tài khoản mẫu do domains/carbon/keycloak/nguoi-dung-mau.json tạo; mật khẩu do OpenBao sinh, không ghi ở đây. */
	const TAI_KHOAN_MAU = [
		{ ten: 'canbo-htx-mau', nhan: 'Cán bộ hợp tác xã', viec: 'Vẽ lô, yêu cầu đo MRV, duyệt kết quả, đề nghị cấp và tạo lệnh bán' },
		{ ten: 'canbo-htx-mau-2', nhan: 'Cán bộ hợp tác xã thứ hai', viec: 'Duyệt lệnh bán do cán bộ khác tạo (hai người, TT 11/2026)' },
		{ ten: 'xavien-mau-1', nhan: 'Xã viên', viec: 'Xem lô đất của mình và kết quả đo' }
	] as const;

	let tq = $state<TongQuan | null>(null);
	let trangThai = $state<'dang-tai' | 'xong' | 'loi'>('dang-tai');
	let khungBanDo = $state<HTMLDivElement>();
	let banDo: BanDo | undefined;

	function doDuLieuBanDo(b: BanDo, d: TongQuan) {
		const chon = d.ket_qua_moi_nhat?.lo_dat_id;
		const src = b.getSource('lo') as { setData?: (data: unknown) => void } | undefined;
		if (!src?.setData) return;
		src.setData({
			type: 'FeatureCollection',
			features: d.lo_da_do.map((l) => ({
				type: 'Feature',
				geometry: l.ranh_gioi,
				properties: { id: l.id, ten: l.ten, chon: l.id === chon }
			}))
		});
		const VUNG_ANH: [number, number, number, number] = [104.73, 8.59, 104.79, 8.65];
		const trongAnh = ([kinh, vi]: [number, number]) =>
			kinh >= VUNG_ANH[0] && kinh <= VUNG_ANH[2] && vi >= VUNG_ANH[1] && vi <= VUNG_ANH[3];
		const dinh = d.lo_da_do.flatMap((l) => l.ranh_gioi.coordinates[0]).filter(trongAnh);
		if (dinh.length) {
			const khung = new LngLatBounds();
			for (const p of dinh) khung.extend(p);
			b.fitBounds(khung, { padding: 72, maxZoom: 14.5, duration: 0 });
		}
	}

	onMount(() => {
		if (khungBanDo) {
			banDo = new BanDo({
				container: khungBanDo,
				style: kieuBanDo(),
				bounds: NEN.toaDo[0].concat(NEN.toaDo[2]) as [number, number, number, number],
				attributionControl: { compact: true, customAttribution: NEN.ghiNguon },
				interactive: false
			});
			banDo.addControl(new ScaleControl({ unit: 'metric', maxWidth: 120 }), 'bottom-left');
			banDo.on('load', () => {
				if (!banDo) return;
				themLopLo(banDo);
				if (tq) doDuLieuBanDo(banDo, tq);
			});
		}

		fetch('/kiem-chung/api/tong-quan')
			.then((r) => (r.ok && r.headers.get('content-type')?.includes('application/json') ? r.json() : null))
			.then((d: TongQuan | null) => {
				if (!d || typeof d.so_ket_qua_mrv !== 'number') {
					trangThai = 'loi';
					return;
				}
				tq = d;
				trangThai = 'xong';
				if (banDo?.isStyleLoaded()) doDuLieuBanDo(banDo, d);
			})
			.catch(() => {
				trangThai = 'loi';
			});

		return () => banDo?.remove();
	});

	// API trả số thập phân của PostgreSQL dưới dạng chuỗi ("8.8746") nên ép về Number trước khi định dạng.
	const so = (v: number | string | null | undefined, n = 2) =>
		v === null || v === undefined || v === '' ? '–' : Number(v).toLocaleString('vi-VN', { maximumFractionDigits: n });
	const kq = $derived(tq?.ket_qua_moi_nhat ?? null);
	/** Thông báo thay cho số liệu khi chưa có kết quả MRV nào trên sổ cái hoặc không đọc được API. */
	const thongBaoTrong = $derived(
		trangThai === 'dang-tai'
			? 'Đang đọc sổ cái…'
			: trangThai === 'loi'
				? 'Không đọc được sổ cái lúc này. Hãy tải lại trang sau ít phút.'
				: 'Sổ cái chưa có kết quả MRV nào được duyệt.'
	);
	const toaDoLo = $derived.by(() => {
		const vong = kq?.ranh_gioi?.coordinates?.[0];
		if (!vong?.length) return null;
		const kinh = vong.reduce((t, p) => t + p[0], 0) / vong.length;
		const vi = vong.reduce((t, p) => t + p[1], 0) / vong.length;
		return `${so(vi, 2)}°B · ${so(kinh, 2)}°Đ`;
	});
	const hrefKiemChung = $derived(
		tq?.seri_moi_nhat ? `/kiem-chung?q=${tq.seri_moi_nhat}` : kq ? `/kiem-chung?q=${kq.commit}` : '/kiem-chung'
	);
</script>

<div class="trang">
	<header class="dau">
		<a class="ten" href="/">
			<img class="logo-anh" src="/nen/logo-transparent.png" alt="Logo CarbonFarm OS" width="36" height="36" />
			<span>CarbonFarm OS</span>
		</a>
		<nav aria-label="Mục trong trang">
			<a href="#cach-lam">Quy trình 4 bước</a>
			<a href="#phuong-phap">Phương pháp IPCC</a>
			<a href="#ban-do">Ảnh vệ tinh</a>
			<a href={hrefKiemChung}>Kiểm chứng sổ cái</a>
		</nav>
		<div class="hanh-dong-dau">
			<button class="nut nho" onclick={() => batDauDangNhap()}>Đăng nhập</button>
		</div>
	</header>

	<main>
		<section class="mo" aria-labelledby="tieu-de">
			<div class="mo-trai">
				<div class="huy-hieu-chinh">
					<img class="logo-mini" src="/nen/logo-transparent.png" alt="" width="20" height="20" />
					<span>Nền tảng đo đạc MRV & sổ cái Dolt</span>
				</div>
				<h1 id="tieu-de">
					Tín chỉ carbon rừng ngập mặn,<br />
					<span class="chu-nhan">truy tới từng điểm ảnh vệ tinh.</span>
				</h1>
				<p class="dan">
					Mỗi tấn CO₂e của <b>Hợp tác xã Rừng ngập mặn Đất Mũi</b> đều gắn liền với ranh giới lô đất của xã viên,
					ảnh quang học 10 m của vệ tinh <em>Copernicus Sentinel-2</em> và chuỗi bản ghi bất biến có chữ ký băm
					<code>SHA-256</code> trên sổ cái Dolt.
				</p>
				<div class="cum-nut">
					<a class="nut" href={hrefKiemChung}>
						<span>Tra cứu & kiểm chứng sổ cái</span>
						<svg viewBox="0 0 20 20" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M5 10h10m-4-4 4 4-4 4"/></svg>
					</a>
					<a class="nut nhat" href="#ban-do">
						<svg viewBox="0 0 20 20" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="10" cy="10" r="7"/><path d="M10 3v14M3 10h14"/></svg>
						<span>Xem ảnh vệ tinh Đất Mũi</span>
					</a>
				</div>

				<div class="vai-tro" aria-labelledby="vai-td">
					<div class="vai-dau">
						<div>
							<h2 id="vai-td">Dùng thử bằng tài khoản mẫu</h2>
							<p class="vai-mo-ta">
								Chọn tài khoản để mở trang đăng nhập Keycloak với tên đăng nhập điền sẵn. Mật khẩu do người vận hành
								máy chủ cấp.
							</p>
						</div>
						<span class="nhan">Hợp tác xã dữ liệu giả</span>
					</div>
					<div class="ds-vai">
						{#each TAI_KHOAN_MAU as v, i (v.ten)}
							<button type="button" class="the-vai-demo" onclick={() => batDauDangNhap(v.ten)}>
								<div class="the-vai-icon">
									{#if i === 0}
										<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3"/></svg>
									{:else if i === 1}
										<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
									{:else}
										<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/></svg>
									{/if}
								</div>
								<div class="the-vai-nd">
									<strong class="vai-ten">{v.nhan}</strong>
									<span class="vai-chuc-vu">{v.viec}</span>
									<span class="vai-vao">Đăng nhập <code>{v.ten}</code> →</span>
								</div>
							</button>
						{/each}
					</div>
				</div>
			</div>

			<aside class="bang-do" aria-label="Lô mới đo trên sổ cái">
				<div class="bang-do-dau">
					<div>
						{#if kq}
							<span class="nhan tot">
								<span class="cham-xanh"></span>
								Đã ghi sổ cái Dolt
							</span>
							<h2 class="ten-lo">{kq.ten_lo}</h2>
						{:else}
							<span class="nhan">Lô mới đo gần nhất</span>
							<h2 class="ten-lo">Chưa có số liệu</h2>
						{/if}
					</div>
					{#if toaDoLo}
						<div class="toa-do-the">
							<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="8" cy="8" r="6"/><path d="M8 2v12M2 8h12"/></svg>
							<span>{toaDoLo}</span>
						</div>
					{/if}
				</div>

				<div class="khung-anh" role="img" aria-label="Sơ đồ ranh giới lô rừng ngập mặn trên ảnh vệ tinh Sentinel-2">
					<img
						src="/nen/mui-ca-mau-s2-20260414.webp"
						alt="Ảnh quang học Sentinel-2 thực tế vùng Đất Mũi"
						class="anh-ve-tinh-nen"
						loading="eager"
					/>
					<div class="phu-ve-tinh"></div>
					<svg viewBox="0 0 360 190" class="so-do-lo" aria-hidden="true">
						<defs>
							<filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
								<feGaussianBlur stdDeviation="3" result="blur" />
								<feComposite in="SourceGraphic" in2="blur" operator="over" />
							</filter>
						</defs>
						<!-- Lưới toạ độ vệ tinh mảnh -->
						<line x1="0" y1="48" x2="360" y2="48" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />
						<line x1="0" y1="95" x2="360" y2="95" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />
						<line x1="0" y1="142" x2="360" y2="142" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />
						<line x1="90" y1="0" x2="90" y2="190" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />
						<line x1="180" y1="0" x2="180" y2="190" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />
						<line x1="270" y1="0" x2="270" y2="190" stroke="rgba(255,255,255,0.14)" stroke-width="0.8" stroke-dasharray="2 4" />

						{#if kq}
						<!-- Đa giác lô rừng ngập mặn -->
						<polygon
							points="58,32 242,26 264,136 76,148"
							fill="rgba(16, 185, 129, 0.42)"
							stroke="#fbbf24"
							stroke-width="2.5"
							filter="url(#glow)"
						/>
						<!-- 4 đỉnh góc ranh giới -->
						<circle cx="58" cy="32" r="4.5" fill="#ffffff" stroke="#d97706" stroke-width="2.5" />
						<circle cx="242" cy="26" r="4.5" fill="#ffffff" stroke="#d97706" stroke-width="2.5" />
						<circle cx="264" cy="136" r="4.5" fill="#ffffff" stroke="#d97706" stroke-width="2.5" />
						<circle cx="76" cy="148" r="4.5" fill="#ffffff" stroke="#d97706" stroke-width="2.5" />

						<!-- Tâm lô & nhãn -->
						<circle cx="160" cy="85" r="14" fill="none" stroke="rgba(255,255,255,0.6)" stroke-width="1.5" stroke-dasharray="3 3" />
						<circle cx="160" cy="85" r="2.5" fill="#fbbf24" />
						<rect x="100" y="72" width="120" height="26" rx="6" fill="rgba(10, 31, 25, 0.88)" stroke="rgba(255,255,255,0.22)" stroke-width="1" />
						<text x="160" y="89" text-anchor="middle" fill="#ffffff" font-size="11" font-weight="700" letter-spacing="0.02em">
							{kq.ten_lo}
						</text>
						{/if}
					</svg>
					<div class="hud-ve-tinh">
						<span class="hud-tag"><span class="cham-xanh"></span> Sentinel-2 L2A · 10 m</span>
						{#if kq?.may_toan_canh != null}
							<span class="hud-tag">Mây toàn cảnh: {so(kq.may_toan_canh, 2)} %</span>
						{/if}
					</div>
				</div>

				{#if !kq}
					<p class="trong-so-cai" role={trangThai === 'loi' ? 'alert' : 'status'}>{thongBaoTrong}</p>
				{/if}

				<div class="so-chinh">
					<div>
						<p class="nhan-phu">Lượng hấp thụ CO₂e kỳ gần nhất</p>
						<p class="co2e">{so(kq?.co2e_tan, 2)} <span>t CO₂e</span></p>
					</div>
					<div class="so-phu">
						<p class="nhan-phu">Tín chỉ phát hành</p>
						<p class="tin-chi-so">{so(tq?.tin_chi_da_cap, 0)} <span>tín chỉ</span></p>
					</div>
				</div>

				<dl class="chi-so">
					<div>
						<dt>Diện tích tán rừng</dt>
						<dd>{kq ? `${so(kq.dien_tich_tan_ha)} ha` : '–'}</dd>
					</div>
					<div>
						<dt>Chỉ số thực vật NDVI</dt>
						<dd>{so(kq?.ndvi_tb_tan, 2)}</dd>
					</div>
					<div>
						<dt>Ngày vệ tinh chụp</dt>
						<dd>{kq?.ngay_chup ? kq.ngay_chup.split('-').reverse().join('/') : '–'}</dd>
					</div>
					<div>
						<dt>Cam kết sổ cái Dolt</dt>
						<dd>
							{#if kq}
								<a href="/kiem-chung?q={kq.commit}"><code>{kq.commit.slice(0, 12)}…</code></a>
							{:else}
								–
							{/if}
						</dd>
					</div>
				</dl>
			</aside>
		</section>

		<section class="thong-ke" aria-label="Số liệu từ sổ cái">
			<div class="o-thong-ke">
				<span class="nhan-tk">Kết quả MRV đã duyệt</span>
				<strong class="so-tk">{so(tq?.so_ket_qua_mrv, 0)}</strong>
				<span class="chu-tk">kỳ đo vệ tinh trên sổ cái</span>
			</div>
			<div class="o-thong-ke">
				<span class="nhan-tk">Tổng hấp thụ đã ghi sổ</span>
				<strong class="so-tk">{so(tq?.co2e_da_ghi_so_tan, 2)} <small>t CO₂e</small></strong>
				<span class="chu-tk">tính theo cận dưới IPCC Tier 1</span>
			</div>
			<div class="o-thong-ke">
				<span class="nhan-tk">Tín chỉ đã cấp sê-ri</span>
				<strong class="so-tk">{so(tq?.tin_chi_da_cap, 0)}</strong>
				<span class="chu-tk">mỗi tín chỉ tương ứng 1 tấn CO₂e</span>
			</div>
			<div class="o-thong-ke">
				<span class="nhan-tk">Tín chỉ đã chuyển nhượng</span>
				<strong class="so-tk">{so(tq?.tin_chi_da_ban, 0)}</strong>
				<span class="chu-tk">duyệt chéo 2 cán bộ hợp tác xã</span>
			</div>
		</section>

		<section class="cach-lam" id="cach-lam" aria-labelledby="cl-td">
			<div class="dau-muc">
				<h2 id="cl-td">Bốn bước từ ranh giới rừng ngập mặn tới chứng thư tín chỉ</h2>
				<p>
					Toàn bộ quy trình được kiểm soát bằng ràng buộc hình học PostGIS, phân quyền mức dòng (RLS) và sổ cái
					phiên bản Dolt chống sửa lùi.
				</p>
			</div>
			<ol class="buoc">
				<li>
					<div class="buoc-dau">
						<span class="stt">01</span>
						<span class="buoc-nhan">PostGIS · Poka-Yoke</span>
					</div>
					<h3>Khoanh lô trên ảnh thực địa</h3>
					<p>
						Cán bộ hoặc xã viên vẽ đa giác ranh giới lô rừng ngay trên ảnh Sentinel-2. Cơ sở dữ liệu tự động từ
						chối nếu chồng lấn với lô khác (<code>UC005</code>) hoặc lệch quá 10 % so với diện tích trên giấy tờ
						(<code>UC004</code>).
					</p>
				</li>
				<li>
					<div class="buoc-dau">
						<span class="stt">02</span>
						<span class="buoc-nhan">Sentinel-2 · SCL + NDVI</span>
					</div>
					<h3>Đo tán rừng từ vệ tinh</h3>
					<p>
						Luồng xử lý tự tải băng đỏ (B04), cận hồng ngoại (B08) và lớp phân loại cảnh (SCL) từ kỳ chụp ít mây
						nhất, loại bỏ điểm ảnh mây/bóng mây và giữ các điểm ảnh có <code>NDVI ≥ 0,4</code> làm diện tích tán.
					</p>
				</li>
				<li>
					<div class="buoc-dau">
						<span class="stt">03</span>
						<span class="buoc-nhan">Dolt · SHA-256</span>
					</div>
					<h3>Cán bộ duyệt và khóa sổ cái</h3>
					<p>
						Cán bộ hợp tác xã đối chiếu lớp phủ NDVI trên bản đồ, nhập ghi chú kiểm tra và ký duyệt. Bản ghi JSON
						chuẩn hoá được băm <code>SHA-256</code> và tạo commit bất biến trên sổ cái Dolt.
					</p>
				</li>
				<li>
					<div class="buoc-dau">
						<span class="stt">04</span>
						<span class="buoc-nhan">TT 11/2026/TT-BNNMT</span>
					</div>
					<h3>Cấp sê-ri và bán hai chữ ký</h3>
					<p>
						Phần nguyên tấn CO₂e được cấp dải sê-ri định danh duy nhất. Mọi lệnh bán bắt buộc do một cán bộ tạo và
						một cán bộ khác của hợp tác xã duyệt chéo (<code>UC031</code>).
					</p>
				</li>
			</ol>
		</section>

		<section class="phuong-phap" id="phuong-phap" aria-labelledby="pp-td">
			<div class="pp-mo-ta">
				<h2 id="pp-td">Công thức ước lượng công khai, dùng cận dưới thận trọng</h2>
				<p>
					Phương pháp v0.1 dùng hệ số Tier 1 của <em>IPCC 2013 Wetlands Supplement</em>, Chương 4 (rừng ngập mặn,
					vùng nhiệt đới ẩm), và luôn chọn cận dưới khoảng tin cậy 95 % để không thổi phồng tín chỉ. Ảnh vệ tinh chỉ
					đo diện tích tán; rừng đã chạm trần sinh khối thì không tính thêm.
				</p>
				<div class="cong-thuc">
					<code>CO₂e (tấn) = Diện tích tán (ha) × 9,4 × (1 + 0,47) × 0,429 × 44/12 × (số ngày trong kỳ / 365)</code>
				</div>
				<p class="pp-ghi-chu">
					Đặc tả và trích dẫn: <code>methodology/v0.1-rung-ngap-man-ipcc-tier1.md</code>; tham số máy đọc:
					<code>methodology/v0.1-rung-ngap-man-ipcc-tier1.yaml</code>. Phiên bản phương pháp và SHA-256 tệp tham số
					được ghi vào trường <code>pha_he</code> của từng kết quả MRV.
				</p>
			</div>

			<div class="bang-tham-so-khung">
				<dl class="tham-so">
					<div>
						<dt>Tăng sinh khối trên mặt đất (G<sub>W</sub>, Bảng 4.4)</dt>
						<dd>9,4 t chất khô / ha / năm</dd>
					</div>
					<div>
						<dt>Tỉ lệ sinh khối dưới / trên mặt đất (R, Bảng 4.5)</dt>
						<dd>0,47</dd>
					</div>
					<div>
						<dt>Tỉ lệ carbon trong sinh khối khô (CF, Bảng 4.2)</dt>
						<dd>0,429 t C / t chất khô</dd>
					</div>
					<div>
						<dt>Quy đổi C → CO₂</dt>
						<dd>44 / 12 ≈ 3,667</dd>
					</div>
					<div>
						<dt>Kết quả cho một héc-ta tán kín</dt>
						<dd>≈ 21,74 t CO₂e / ha / năm</dd>
					</div>
					<div>
						<dt>Trần sinh khối trên mặt đất (B<sub>max</sub>, Bảng 4.3)</dt>
						<dd>187 t chất khô / ha</dd>
					</div>
				</dl>
			</div>
		</section>

		<section class="ban-do-muc" id="ban-do" aria-labelledby="bd-td">
			<div class="bd-dau">
				<div>
					<h2 id="bd-td">Ảnh vệ tinh Sentinel-2 thực tế vùng Mũi Cà Mau</h2>
					<p>
						Các đa giác màu xanh ngọc biểu thị những lô rừng ngập mặn đã được đo đạc và ghi sổ cái. Ảnh nền quang
						học 10 m được cắt trực tiếp từ cảnh vệ tinh Copernicus Sentinel-2 ngày 14/04/2026.
					</p>
				</div>
				<div class="bd-nut">
					<button class="nut nhat nho" onclick={() => batDauDangNhap()}>
						Đăng nhập để mở bản đồ tương tác
					</button>
				</div>
			</div>
			<div class="khung-ban-do-ngoai">
				<div class="khung-ban-do" bind:this={khungBanDo} aria-label="Bản đồ lô đã đo trên ảnh Sentinel-2"></div>
				<div class="chu-thich-ban-do">
					<span><i class="mau-lo chon"></i> Lô mới đo gần nhất{kq ? ` (${kq.ten_lo})` : ''}</span>
					<span><i class="mau-lo"></i> Lô đang hoạt động trong HTX</span>
					<span>Nguồn ảnh: ESA Copernicus Sentinel-2 L2A</span>
				</div>
			</div>
		</section>

		<section class="so-cai" aria-labelledby="sc-td">
			<div class="so-cai-trai">
				<h2 id="sc-td">Mỗi tín chỉ có một chuỗi phả hệ không thể sửa lùi</h2>
				<p>
					Người mua tín chỉ, cơ quan kiểm toán độc lập hoặc người dân đều có thể tự nhập số sê-ri tín chỉ hoặc mã
					băm commit Dolt để kiểm tra lại mã băm <code>SHA-256</code> của toàn bộ lịch sử: từ lúc đo ảnh vệ tinh,
					cấp sê-ri cho tới giao dịch chuyển nhượng.
				</p>
				<div class="cum-nut">
					<a class="nut" href={hrefKiemChung}>Mở cổng kiểm chứng công khai</a>
					<button class="nut nhat" onclick={() => batDauDangNhap()}>Đăng nhập tài khoản Keycloak</button>
				</div>
			</div>
			<div class="chung-thu">
				<div class="chung-thu-dau">
					<span class="nhan">Sê-ri cấp gần nhất trên sổ cái</span>
					{#if tq?.seri_moi_nhat}<code>{tq.seri_moi_nhat}</code>{/if}
				</div>
				{#if tq?.seri_moi_nhat}
					<div class="chung-thu-than">
						<div>
							<span>Nguồn gốc lô rừng</span>
							<strong>{kq?.ten_lo ?? '–'}</strong>
						</div>
						<div>
							<span>Commit kết quả MRV</span>
							{#if kq}<code>{kq.commit}</code>{:else}<strong>–</strong>{/if}
						</div>
						<div>
							<span>Chủ sở hữu, chuỗi cấp – bán và đối chiếu SHA-256</span>
							<a href="/kiem-chung?q={tq.seri_moi_nhat}">Tra sê-ri này trên cổng kiểm chứng →</a>
						</div>
					</div>
				{:else}
					<p class="trong-so-cai" role={trangThai === 'loi' ? 'alert' : 'status'}>
						{trangThai === 'xong' ? 'Sổ cái chưa cấp tín chỉ nào.' : thongBaoTrong}
					</p>
				{/if}
			</div>
		</section>
	</main>

	<footer class="chan">
		<div>
			<strong>CarbonFarm OS</strong> · Hệ thống đo đạc, báo cáo, thẩm định (MRV) và quản lý tín chỉ carbon rừng ngập mặn
			cho hợp tác xã nông lâm nghiệp.
		</div>
		<div class="chan-phai">
			<span>Giấy phép nguồn mở GPL-3.0-or-later</span>
			<span>·</span>
			<a href={hrefKiemChung}>Cổng kiểm chứng công khai</a>
		</div>
	</footer>
</div>

<style>
	.trang {
		max-width: 1240px;
		margin: 0 auto;
		padding: 0 var(--le) 72px;
		overflow-x: clip;
	}

	/* Thanh điều hướng đầu trang */
	.dau {
		position: sticky;
		top: 0;
		z-index: 20;
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 16px;
		min-height: 72px;
		padding: 12px 0;
		border-bottom: 1px solid var(--ke);
		background: rgb(246 248 245 / 0.9);
		backdrop-filter: blur(12px);
	}
	.ten {
		display: inline-flex;
		align-items: center;
		gap: 12px;
		color: var(--muc);
		font: 700 1.25rem var(--serif);
		letter-spacing: -0.02em;
		text-decoration: none;
	}
	.logo-anh {
		display: block;
		width: 36px;
		height: 36px;
		object-fit: contain;
		filter: drop-shadow(0 2px 6px rgb(11 93 76 / 0.18));
	}
	.dau nav {
		display: flex;
		gap: 24px;
		margin-left: auto;
	}
	.dau nav a {
		color: var(--mo);
		font-size: 0.9375rem;
		font-weight: 500;
		text-decoration: none;
		transition: color 0.15s var(--de);
	}
	.dau nav a:hover {
		color: var(--teal);
	}
	.hanh-dong-dau {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	/* Phần mở đầu (Hero) */
	.mo {
		display: grid;
		grid-template-columns: minmax(0, 1.15fr) minmax(360px, 0.85fr);
		gap: clamp(32px, 4.5vw, 64px);
		align-items: start;
		padding: clamp(32px, 5vw, 56px) 0;
		border-bottom: 1px solid var(--ke);
	}
	.huy-hieu-chinh {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 18px;
		padding: 5px 14px;
		border: 1px solid var(--teal-vien);
		border-radius: 999px;
		background: var(--teal-nhat);
		color: var(--teal-dam);
		font-size: 0.8125rem;
		font-weight: 600;
	}
	.logo-mini {
		display: block;
		width: 18px;
		height: 18px;
		object-fit: contain;
	}
	h1 {
		color: var(--muc);
		font-size: clamp(2.25rem, 4vw, 3.4rem);
		line-height: 1.1;
		letter-spacing: -0.03em;
	}
	.chu-nhan {
		color: var(--teal);
	}
	.dan {
		max-width: 58ch;
		margin-top: 20px;
		color: var(--mo);
		font-size: 1.0625rem;
		line-height: 1.65;
	}
	.dan b,
	.dan em {
		color: var(--muc);
		font-style: normal;
		font-weight: 600;
	}
	.cum-nut {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 12px;
		margin-top: 28px;
	}

	/* Khối chọn vai trò: 3 thẻ tương tác cao cấp */
	.vai-tro {
		margin-top: 36px;
		padding: 22px;
		border: 1px solid var(--ke);
		border-radius: 18px;
		background: var(--nen-mem);
	}
	.vai-dau {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		flex-wrap: wrap;
		gap: 10px;
	}
	.vai-dau h2 {
		font: 700 1.0625rem var(--sans);
		letter-spacing: -0.01em;
	}
	.vai-mo-ta {
		max-width: 60ch;
		margin-top: 4px;
		color: var(--mo);
		font-size: 0.8125rem;
		line-height: 1.5;
	}
	.ds-vai {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 12px;
		margin-top: 16px;
	}
	.the-vai-demo {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: 10px;
		padding: 14px;
		border: 1px solid var(--ke);
		border-radius: 14px;
		background: #ffffff;
		color: var(--muc);
		text-align: left;
		cursor: pointer;
		box-shadow: 0 1px 2px rgba(10, 31, 25, 0.03);
		transition:
			border-color 0.16s var(--de),
			transform 0.16s var(--de),
			box-shadow 0.16s var(--de);
	}
	.the-vai-demo:hover {
		border-color: var(--teal);
		transform: translateY(-2px);
		box-shadow: 0 4px 12px -2px rgba(11, 99, 81, 0.15);
	}
	.the-vai-icon {
		display: inline-grid;
		place-items: center;
		width: 34px;
		height: 34px;
		border-radius: 10px;
		background: var(--teal-nhat);
		color: var(--teal-dam);
	}
	.the-vai-nd {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}
	.vai-ten {
		color: var(--muc);
		font-size: 0.875rem;
		font-weight: 700;
	}
	.vai-chuc-vu {
		color: var(--mo);
		font-size: 0.75rem;
		line-height: 1.4;
	}
	.vai-vao {
		margin-top: 4px;
		color: var(--teal);
		font-size: 0.75rem;
		font-weight: 600;
	}

	/* Thẻ đối chứng vệ tinh bên phải */
	.bang-do {
		display: grid;
		gap: 16px;
		padding: 24px;
		border: 1px solid var(--ke);
		border-radius: 24px;
		background: #ffffff;
		box-shadow: var(--bong-the);
	}
	.bang-do-dau {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		flex-wrap: wrap;
		gap: 8px 12px;
	}
	.trong-so-cai {
		padding: 14px 16px;
		border: 1px dashed var(--ke);
		border-radius: 14px;
		color: var(--mo);
		font-size: 0.9375rem;
		line-height: 1.5;
	}
	.ten-lo {
		margin-top: 8px;
		font-size: 1.5rem;
	}
	.toa-do-the {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		color: var(--mo);
		font-size: 0.75rem;
		font-weight: 500;
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}
	.khung-anh {
		position: relative;
		height: 200px;
		overflow: hidden;
		border-radius: 16px;
		background: #0d211b;
		box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.1);
	}
	.anh-ve-tinh-nen {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		object-fit: cover;
		filter: brightness(0.88) contrast(1.15);
	}
	.phu-ve-tinh {
		position: absolute;
		inset: 0;
		background: linear-gradient(180deg, rgba(10, 31, 25, 0.25) 0%, rgba(10, 31, 25, 0.6) 100%);
		pointer-events: none;
	}
	.so-do-lo {
		position: absolute;
		inset: 0;
		width: 100%;
		height: 100%;
		pointer-events: none;
	}
	.hud-ve-tinh {
		position: absolute;
		bottom: 10px;
		left: 10px;
		right: 10px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		pointer-events: none;
	}
	.hud-tag {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 3px 10px;
		border: 1px solid rgba(255, 255, 255, 0.2);
		border-radius: 999px;
		background: rgba(10, 31, 25, 0.78);
		backdrop-filter: blur(8px);
		color: #e2f4ed;
		font-size: 0.6875rem;
		font-weight: 600;
	}
	.so-chinh {
		display: grid;
		grid-template-columns: 1.2fr 0.8fr;
		gap: 16px;
		padding: 14px 0;
		border-top: 1px solid var(--ke);
		border-bottom: 1px solid var(--ke);
	}
	.so-phu {
		padding-left: 16px;
		border-left: 1px solid var(--ke);
	}
	.nhan-phu {
		color: var(--mo);
		font-size: 0.75rem;
		font-weight: 500;
	}
	.co2e,
	.tin-chi-so {
		margin-top: 4px;
		color: var(--teal-dam);
		font: 700 2rem/1.05 var(--serif);
		letter-spacing: -0.03em;
		font-variant-numeric: tabular-nums;
	}
	.co2e span,
	.tin-chi-so span {
		color: var(--mo);
		font: 500 0.9375rem var(--sans);
		letter-spacing: 0;
	}
	.chi-so {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 12px 20px;
		margin: 0;
	}
	.chi-so div {
		display: grid;
		gap: 2px;
	}
	.chi-so dt {
		color: var(--mo);
		font-size: 0.75rem;
	}
	.chi-so dd {
		margin: 0;
		color: var(--muc);
		font-size: 0.875rem;
		font-weight: 600;
		font-variant-numeric: tabular-nums;
	}
	.chi-so a {
		color: var(--teal);
		text-decoration: underline;
		text-underline-offset: 0.2em;
	}

	/* Dải thống kê 4 cột */
	.thong-ke {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 16px;
		margin-top: 32px;
	}
	.o-thong-ke {
		display: grid;
		gap: 6px;
		padding: 22px 24px;
		border: 1px solid var(--ke);
		border-radius: 20px;
		background: #ffffff;
		box-shadow: 0 2px 8px -2px rgba(10, 31, 25, 0.05);
		transition: transform 0.16s var(--de), border-color 0.16s var(--de);
	}
	.o-thong-ke:hover {
		transform: translateY(-2px);
		border-color: var(--teal-vien);
	}
	.nhan-tk {
		color: var(--mo);
		font-size: 0.8125rem;
		font-weight: 500;
	}
	.so-tk {
		color: var(--muc);
		font: 700 2.125rem/1.1 var(--serif);
		letter-spacing: -0.02em;
		font-variant-numeric: tabular-nums;
	}
	.so-tk small {
		color: var(--mo);
		font: 500 1rem var(--sans);
	}
	.chu-tk {
		color: var(--teal);
		font-size: 0.8125rem;
		font-weight: 500;
	}

	/* Quy trình 4 bước */
	.cach-lam {
		padding-top: clamp(56px, 7vw, 88px);
	}
	.dau-muc {
		max-width: 64ch;
		margin-bottom: 28px;
	}
	h2 {
		font-size: clamp(1.75rem, 3vw, 2.5rem);
	}
	.dau-muc p {
		margin-top: 10px;
		color: var(--mo);
		font-size: 1.0625rem;
	}
	.buoc {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 16px;
		margin: 0;
		padding: 0;
		list-style: none;
	}
	.buoc li {
		display: flex;
		flex-direction: column;
		gap: 12px;
		padding: 24px;
		border: 1px solid var(--ke);
		border-radius: 22px;
		background: #fff;
	}
	.buoc-dau {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}
	.stt {
		display: inline-grid;
		place-items: center;
		width: 34px;
		height: 34px;
		border-radius: 10px;
		background: var(--teal-nhat);
		color: var(--teal-dam);
		font: 700 0.9375rem var(--sans);
	}
	.buoc-nhan {
		color: var(--mo);
		font-size: 0.75rem;
		font-weight: 600;
	}
	h3 {
		font-size: 1.25rem;
	}
	.buoc p {
		color: var(--mo);
		font-size: 0.9375rem;
		line-height: 1.6;
	}
	code {
		padding: 2px 6px;
		border-radius: 6px;
		background: var(--giay-2);
		color: var(--teal-dam);
		font-size: 0.84em;
	}

	/* Phương pháp luận IPCC */
	.phuong-phap {
		display: grid;
		grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr);
		gap: clamp(28px, 4vw, 56px);
		align-items: start;
		padding-top: clamp(56px, 7vw, 88px);
	}
	.pp-mo-ta {
		display: grid;
		gap: 16px;
	}
	.pp-mo-ta p {
		max-width: 60ch;
		color: var(--mo);
		line-height: 1.65;
	}
	.cong-thuc {
		padding: 18px 20px;
		border: 1px solid #b8ded0;
		border-radius: 16px;
		background: var(--teal-nhat);
	}
	.cong-thuc code {
		padding: 0;
		background: none;
		color: var(--teal-dam);
		font-size: 0.9375rem;
		font-weight: 600;
	}
	.pp-ghi-chu {
		font-size: 0.875rem;
	}
	.bang-tham-so-khung {
		padding: 24px;
		border: 1px solid var(--ke);
		border-radius: 24px;
		background: #fff;
		box-shadow: var(--bong);
	}
	.tham-so {
		margin: 0;
	}
	.tham-so div {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		gap: 16px;
		padding: 13px 0;
		border-bottom: 1px solid var(--ke);
	}
	.tham-so div:first-child {
		padding-top: 0;
	}
	.tham-so div:last-child {
		padding-bottom: 0;
		border-bottom: 0;
	}
	.tham-so dt {
		color: var(--mo);
		font-size: 0.9375rem;
	}
	.tham-so dd {
		margin: 0;
		color: var(--muc);
		font-weight: 600;
		font-variant-numeric: tabular-nums;
		text-align: right;
	}

	/* Bản đồ vệ tinh */
	.ban-do-muc {
		padding-top: clamp(56px, 7vw, 88px);
	}
	.bd-dau {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		flex-wrap: wrap;
		gap: 20px;
		margin-bottom: 22px;
	}
	.bd-dau p {
		max-width: 62ch;
		margin-top: 8px;
		color: var(--mo);
	}
	.khung-ban-do-ngoai {
		overflow: hidden;
		border: 1px solid var(--ke);
		border-radius: 26px;
		background: #fff;
		box-shadow: var(--bong);
	}
	.khung-ban-do {
		height: clamp(360px, 48vw, 500px);
		background: #1b382c;
	}
	.chu-thich-ban-do {
		display: flex;
		flex-wrap: wrap;
		gap: 20px;
		padding: 14px 22px;
		border-top: 1px solid var(--ke);
		color: var(--mo);
		font-size: 0.8125rem;
		font-weight: 500;
	}
	.chu-thich-ban-do span {
		display: inline-flex;
		align-items: center;
		gap: 8px;
	}
	.mau-lo {
		display: inline-block;
		width: 12px;
		height: 12px;
		border: 2px solid #9dd9d2;
		border-radius: 4px;
		background: rgb(157 217 210 / 0.35);
	}
	.mau-lo.chon {
		border-color: #ecba82;
		background: rgb(236 186 130 / 0.45);
	}

	/* Khối sổ cái cuối trang: phẳng 2 cột, chỉ 1 thẻ chứng thư bên phải */
	.so-cai {
		display: grid;
		grid-template-columns: minmax(0, 1.15fr) minmax(300px, 0.85fr);
		gap: clamp(24px, 4vw, 48px);
		align-items: center;
		margin-top: clamp(56px, 7vw, 88px);
		padding-top: clamp(40px, 5vw, 64px);
		border-top: 1px solid var(--ke);
	}
	.so-cai-trai p {
		max-width: 56ch;
		margin-top: 14px;
		color: var(--mo);
		font-size: 1.0625rem;
		line-height: 1.65;
	}
	.chung-thu {
		display: grid;
		gap: 14px;
		padding: 24px;
		border: 1px solid #b8ded0;
		border-radius: 22px;
		background: #fff;
		box-shadow: var(--bong);
	}
	.chung-thu-dau {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 8px;
		padding-bottom: 12px;
		border-bottom: 1px solid var(--ke);
	}
	.chung-thu-than {
		display: grid;
		gap: 12px;
	}
	.chung-thu-than > div {
		display: grid;
		gap: 2px;
	}
	.chung-thu-than span {
		color: var(--mo);
		font-size: 0.75rem;
	}
	.chung-thu-than strong {
		color: var(--muc);
		font-size: 0.9375rem;
	}
	.chung-thu-than code {
		overflow-wrap: anywhere;
		font-size: 0.8125rem;
	}
	.chung-thu-than a {
		color: var(--teal);
		font-weight: 600;
	}

	.chan {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 16px;
		margin-top: 56px;
		padding-top: 24px;
		border-top: 1px solid var(--ke);
		color: var(--mo);
		font-size: 0.875rem;
	}
	.chan > div:first-child {
		max-width: 64ch;
	}
	.chan-phai {
		display: flex;
		align-items: center;
		gap: 10px;
	}
	.chan a {
		color: var(--teal);
		font-weight: 500;
		text-decoration: none;
	}

	@media (max-width: 1024px) {
		.mo,
		.phuong-phap,
		.so-cai {
			grid-template-columns: minmax(0, 1fr);
		}
		.thong-ke,
		.buoc {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
		.dau nav {
			display: none;
		}
	}
	@media (max-width: 640px) {
		.ds-vai,
		.thong-ke,
		.buoc {
			grid-template-columns: minmax(0, 1fr);
		}
		.so-chinh,
		.chi-so {
			grid-template-columns: minmax(0, 1fr);
		}
		.so-phu {
			padding-left: 0;
			padding-top: 12px;
			border-left: 0;
			border-top: 1px solid var(--ke);
		}
	}
</style>
