<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!--
	Ví tín chỉ của hợp tác xã + lệnh bán. Cơ chế tạo và duyệt hai người (TT 11/2026/TT-BNNMT Điều 6 khoản 3):
	cán bộ tạo lệnh, cán bộ KHÁC duyệt; CSDL chặn tự duyệt (UC031), vượt số dư (UC030). Lỗi hiện nguyên văn tiếng Việt.
-->
<script lang="ts">
	import { onDestroy } from 'svelte';
	import type { Token } from './dang-nhap.ts';
	import { goiGraphql, LoiNghiepVu } from './graphql.ts';

	type Khoi = { rowId: string; soLuong: number; maTrongNuoc: string; seriTu: string; seriDen: string; hopTacXaId: string };
	type NguoiMua = { ma: string; ten: string; donGiaToiDaVnd: string };
	type Lenh = {
		rowId: string;
		maNguoiMua: string;
		maTrongNuoc: string;
		soLuong: number;
		donGiaVnd: string;
		thanhTienVnd: string;
		trangThai: string;
		taoLuc: string;
		doToiTao: boolean;
		ghiChuDuyet: string | null;
		doltCommit: string | null;
		lyDoLoi: string | null;
	};

	let { token, laCanBo, vi, onThayDoi }: { token: Token; laCanBo: boolean; vi: Khoi[]; onThayDoi: () => void } = $props();

	const TRANG_THAI: Record<string, string> = {
		cho_duyet: 'Chờ cán bộ khác duyệt',
		da_duyet: 'Đang giao dịch',
		tu_choi: 'Bị từ chối',
		hoan_tat: 'Hoàn tất',
		loi: 'Lỗi'
	};
	const TRUY_VAN = `{ allCarbonNguoiMuas { nodes { ma ten donGiaToiDaVnd } }
		allCarbonLenhBans { nodes { rowId maNguoiMua maTrongNuoc soLuong donGiaVnd thanhTienVnd trangThai taoLuc doToiTao
			ghiChuDuyet doltCommit lyDoLoi } } }`;

	let nguoiMua = $state<NguoiMua[]>([]);
	let lenh = $state<Lenh[]>([]);
	let form = $state({ maNguoiMua: '', soLuong: '', donGia: '' });
	let lyDo = $state<Record<string, string>>({});
	let loi = $state<{ thongBao: string; goiY?: string } | null>(null);
	let dangGui = $state(false);
	let hen: ReturnType<typeof setTimeout> | undefined;

	const tong = $derived(vi.reduce((t, k) => t + k.soLuong, 0));
	const maTin = $derived(vi[0]?.maTrongNuoc ?? '');
	const vnd = (v: string | number) => `${Number(v).toLocaleString('vi-VN')} đ`;
	const tamTinhVnd = $derived.by(() => {
		const sl = Number(form.soLuong);
		const gia = Number(form.donGia.replace(/\D/g, ''));
		return sl > 0 && gia > 0 ? sl * gia : null;
	});

	async function tai() {
		clearTimeout(hen);
		try {
			const d = await goiGraphql<{ allCarbonNguoiMuas: { nodes: NguoiMua[] }; allCarbonLenhBans: { nodes: Lenh[] } }>(
				token,
				TRUY_VAN
			);
			nguoiMua = d.allCarbonNguoiMuas.nodes;
			const dangGiaoDich = lenh.some((l) => l.trangThai === 'da_duyet');
			lenh = d.allCarbonLenhBans.nodes.sort((a, b) => b.taoLuc.localeCompare(a.taoLuc));
			if (!form.maNguoiMua && nguoiMua.length) form.maNguoiMua = nguoiMua[0].ma;
			if (dangGiaoDich && !lenh.some((l) => l.trangThai === 'da_duyet')) onThayDoi();
		} catch (e) {
			loi = { thongBao: (e as Error).message };
		}
		if (lenh.some((l) => l.trangThai === 'da_duyet')) hen = setTimeout(tai, 3000);
	}

	async function goi(mutation: string, bien: Record<string, unknown>) {
		loi = null;
		dangGui = true;
		try {
			await goiGraphql(token, mutation, bien);
			await tai();
			onThayDoi();
			return true;
		} catch (e) {
			loi = e instanceof LoiNghiepVu ? { thongBao: e.message, goiY: e.goiY } : { thongBao: (e as Error).message };
			return false;
		} finally {
			dangGui = false;
		}
	}

	async function taoLenh(e: SubmitEvent) {
		e.preventDefault();
		const ok = await goi(
			`mutation($htx: UUID, $nm: String, $ma: String, $sl: Int, $gia: BigInt) {
				carbonTaoLenhBan(input: { hopTacXaId: $htx, maNguoiMua: $nm, maTrongNuoc: $ma, soLuong: $sl, donGiaVnd: $gia }) { result } }`,
			{
				htx: vi[0]?.hopTacXaId,
				nm: form.maNguoiMua,
				ma: maTin,
				sl: Number(form.soLuong),
				gia: form.donGia.replace(/\D/g, '')
			}
		);
		if (ok) form = { ...form, soLuong: '', donGia: '' };
	}

	const duyet = (id: string, dongY: boolean) =>
		goi(
			'mutation($id: UUID, $dy: Boolean, $gc: String) { carbonDuyetLenhBan(input: { lenhBanId: $id, dongY: $dy, ghiChu: $gc }) { result } }',
			{ id, dy: dongY, gc: lyDo[id] || null }
		);

	$effect(() => {
		void token;
		tai();
	});
	onDestroy(() => clearTimeout(hen));
</script>

<section class="vi" aria-labelledby="vi-td">
	<div class="dau-muc">
		<h2 id="vi-td">Ví tín chỉ</h2>
		<span class="nhan tot">1 tín chỉ = 1 t CO₂e</span>
	</div>

	{#if vi.length}
		<ul class="khoi">
			{#each vi as k (k.rowId)}
				<li>
					<div class="khoi-trai">
						<span class="sl">{k.soLuong}</span>
						<div>
							<strong>Dải sê-ri đang nắm giữ</strong>
							<p>
								<a href="/kiem-chung?q={k.seriTu}"><code>{k.seriTu}</code></a> →
								<code>{k.seriDen.slice(-10)}</code>
							</p>
						</div>
					</div>
				</li>
			{/each}
		</ul>
	{:else}
		<p class="phu">Ví hiện chưa có tín chỉ khả dụng.</p>
	{/if}

	{#if laCanBo && tong > 0}
		<form onsubmit={taoLenh}>
			<div class="dau-form">
				<h3>Bán tín chỉ</h3>
				<span>TT 11/2026 · Duyệt 2 cán bộ</span>
			</div>
			<label class="o-nhap">
				Người mua đã đăng ký
				<select bind:value={form.maNguoiMua} required>
					{#each nguoiMua as n (n.ma)}<option value={n.ma}>{n.ten} (trần {vnd(n.donGiaToiDaVnd)})</option>{/each}
				</select>
			</label>
			<div class="hang">
				<label class="o-nhap">Số tín chỉ <input bind:value={form.soLuong} inputmode="numeric" required placeholder="Ví dụ: 3" /></label>
				<label class="o-nhap">Đơn giá (đ) <input bind:value={form.donGia} inputmode="numeric" required placeholder="210000" /></label>
			</div>
			{#if tamTinhVnd}
				<p class="tam-tinh">Tạm tính thành tiền: <b>{vnd(tamTinhVnd)}</b></p>
			{/if}
			<button class="nut rong" type="submit" disabled={dangGui}>Tạo lệnh bán</button>
			<p class="phu">Lệnh bán cần một cán bộ HTX thứ hai duyệt chéo trước khi chuyển quyền sở hữu trên sổ cái.</p>
		</form>
	{/if}
</section>

{#if loi}
	<div role="alert" class="loi"><b>{loi.thongBao}</b>{#if loi.goiY}<br />{loi.goiY}{/if}</div>
{/if}

{#if lenh.length}
	<section class="ds-lenh" aria-labelledby="lenh-td">
		<div class="dau-muc">
			<h2 id="lenh-td">Lệnh bán ({lenh.length})</h2>
		</div>
		{#each lenh as l (l.rowId)}
			<article class="lenh" data-trang-thai={l.trangThai}>
				<header>
					<strong>{l.soLuong} tín chỉ → {nguoiMua.find((n) => n.ma === l.maNguoiMua)?.ten ?? l.maNguoiMua}</strong>
					<span class="nhan {({ cho_duyet: 'cho', hoan_tat: 'tot', tu_choi: 'xau', loi: 'xau' } as Record<string, string>)[l.trangThai] ?? ''}">
						{TRANG_THAI[l.trangThai] ?? l.trangThai}
					</span>
				</header>
				<p class="gia-lenh">
					<span>Đơn giá <b>{vnd(l.donGiaVnd)}</b></span>
					<span>·</span>
					<span>Tổng <b>{vnd(l.thanhTienVnd)}</b></span>
					{#if l.doToiTao}
						<span class="chip-nguoi">Bạn tạo</span>
					{:else if l.trangThai === 'cho_duyet'}
						<span class="chip-duyet">Cán bộ khác tạo — bạn có thể duyệt</span>
					{/if}
				</p>
				{#if l.lyDoLoi}<p class="loi">{l.lyDoLoi}</p>{/if}
				{#if l.ghiChuDuyet}<p class="phu">Ghi chú duyệt: {l.ghiChuDuyet}</p>{/if}
				{#if l.doltCommit}
					<p class="phu">
						Cam kết sổ cái: <a href="/kiem-chung?q={l.doltCommit}"><code>{l.doltCommit.slice(0, 12)}…</code></a>
					</p>
				{/if}
				{#if laCanBo && l.trangThai === 'cho_duyet' && !l.doToiTao}
					<div class="khung-duyet-lenh">
						<label class="o-nhap">
							Ghi chú duyệt (bắt buộc khi từ chối)
							<textarea bind:value={lyDo[l.rowId]} rows="2" placeholder="Đã kiểm tra hợp đồng mua bán tín chỉ…"></textarea>
						</label>
						<div class="hang-duyet">
							<button type="button" class="nut rong" disabled={dangGui} onclick={() => duyet(l.rowId, true)}>Duyệt bán</button>
							<button type="button" class="nut-tu-choi" disabled={dangGui} onclick={() => duyet(l.rowId, false)}>Từ chối</button>
						</div>
					</div>
				{/if}
			</article>
		{/each}
	</section>
{/if}

<style>
	.vi,
	.ds-lenh {
		display: flex;
		flex-direction: column;
		gap: 10px;
		padding-top: 10px;
		border-top: 1px solid var(--ke);
	}
	.dau-muc {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
	}
	h2 {
		font: 700 1.0625rem var(--sans);
	}
	h3 {
		font: 700 0.9375rem var(--sans);
	}
	.khoi {
		display: grid;
		gap: 8px;
		margin: 0;
		padding: 0;
		list-style: none;
		overflow-wrap: anywhere;
	}
	.khoi li {
		padding: 12px 14px;
		border: 1px solid var(--teal-vien);
		border-radius: 14px;
		background: var(--teal-nhat);
		box-shadow: 0 1px 3px rgba(11, 99, 81, 0.06);
	}
	.khoi-trai {
		display: flex;
		align-items: center;
		gap: 12px;
	}
	.khoi-trai strong {
		display: block;
		color: var(--teal-dam);
		font-size: 0.75rem;
	}
	.khoi-trai p {
		margin-top: 2px;
		font-size: 0.8125rem;
	}
	.khoi a {
		color: var(--teal-dam);
		font-weight: 600;
	}
	.sl {
		display: inline-grid;
		place-items: center;
		min-width: 42px;
		height: 36px;
		padding: 0 10px;
		border-radius: 10px;
		background: var(--teal);
		color: #fff;
		font: 700 1rem var(--sans);
		font-variant-numeric: tabular-nums;
	}
	code {
		font-size: 0.85em;
	}
	form {
		display: grid;
		gap: 12px;
		padding: 18px;
		border: 1px solid var(--ke);
		border-radius: 16px;
		background: var(--nen-mem);
	}
	.dau-form {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
	}
	.dau-form span {
		color: var(--mo);
		font-size: 0.75rem;
		font-weight: 500;
	}
	.hang {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 10px;
	}
	.tam-tinh {
		padding: 10px 14px;
		border: 1px solid var(--tot-vien);
		border-radius: 10px;
		background: var(--tot-nen);
		color: var(--tot);
		font-size: 0.875rem;
		font-weight: 600;
		font-variant-numeric: tabular-nums;
	}
	.phu {
		color: var(--mo);
		font-size: 0.8125rem;
		line-height: 1.45;
	}
	.phu a {
		color: var(--teal);
	}
	.lenh {
		display: grid;
		gap: 8px;
		padding: 14px 0;
		border-bottom: 1px solid var(--ke);
	}
	.lenh:last-child {
		padding-bottom: 0;
		border-bottom: 0;
	}
	.lenh header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		flex-wrap: wrap;
		gap: 8px;
		color: var(--muc);
	}
	.lenh header strong {
		font-size: 0.875rem;
	}
	.gia-lenh {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 6px;
		color: var(--mo);
		font-size: 0.8125rem;
		font-variant-numeric: tabular-nums;
	}
	.gia-lenh b {
		color: var(--muc);
	}
	.chip-nguoi,
	.chip-duyet {
		padding: 2px 8px;
		border-radius: 999px;
		font-size: 0.6875rem;
		font-weight: 600;
	}
	.chip-nguoi {
		background: var(--giay-2);
		color: var(--mo);
	}
	.chip-duyet {
		background: var(--teal-nhat);
		color: var(--teal-dam);
	}
	.khung-duyet-lenh {
		display: grid;
		gap: 10px;
		margin-top: 4px;
		padding-top: 10px;
		border-top: 1px dashed var(--ke);
	}
	.hang-duyet {
		display: grid;
		grid-template-columns: 1fr auto;
		gap: 10px;
	}
	.nut-tu-choi {
		min-height: 46px;
		padding: 0 16px;
		border: 1px solid #f3c4bd;
		border-radius: 999px;
		background: var(--xau-nhat);
		color: var(--xau);
		font: 600 0.875rem var(--sans);
		cursor: pointer;
	}
</style>
