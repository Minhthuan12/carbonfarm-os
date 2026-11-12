<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<script lang="ts">
	import { goto } from '$app/navigation';
	import { hoanTatDangNhap } from '#lib/dang-nhap.ts';

	let loi = $state('');
	hoanTatDangNhap(new URL(location.href))
		.then(() => goto('/', { replaceState: true }))
		.catch((e: Error) => (loi = e.message));
</script>

<svelte:head><title>{loi ? 'Không thể đăng nhập' : 'Đang đăng nhập'} · CarbonFarm OS</title></svelte:head>

<main>
	<div class="hop">
		<div class="logo-hop">
			<img src="/nen/logo-transparent.png" alt="Logo CarbonFarm OS" width="48" height="48" />
		</div>
		{#if loi}
			<h1>Không thể hoàn tất đăng nhập</h1>
			<p role="alert" class="loi">{loi}</p>
			<a class="nut" href="/">Về trang chủ CarbonFarm OS</a>
		{:else}
			<div class="vong-xoay" aria-hidden="true"></div>
			<h1>Đang xác thực phiên làm việc…</h1>
			<p role="status">Hệ thống đang trao đổi mã khoá PKCE an toàn với máy chủ định danh Keycloak.</p>
		{/if}
	</div>
</main>

<style>
	main {
		display: grid;
		place-items: center;
		min-height: 100svh;
		padding: var(--le);
		background: var(--giay);
		color: var(--muc);
		font-family: var(--sans);
	}
	.hop {
		display: grid;
		gap: 16px;
		justify-items: center;
		max-width: 440px;
		width: 100%;
		padding: 36px 32px;
		border: 1px solid var(--ke);
		border-radius: 24px;
		background: #ffffff;
		text-align: center;
		box-shadow: var(--bong-the);
	}
	.logo-hop {
		display: grid;
		place-items: center;
		width: 64px;
		height: 64px;
		border-radius: 16px;
		background: var(--teal-nhat);
		border: 1px solid var(--teal-vien);
	}
	.vong-xoay {
		width: 32px;
		height: 32px;
		border: 3px solid var(--teal-nhat);
		border-top-color: var(--teal);
		border-radius: 50%;
		animation: xoay 0.8s linear infinite;
	}
	@keyframes xoay {
		to {
			transform: rotate(360deg);
		}
	}
	h1 {
		font-size: 1.375rem;
		letter-spacing: -0.02em;
	}
	p {
		color: var(--mo);
		font-size: 0.9375rem;
		line-height: 1.5;
	}
</style>
