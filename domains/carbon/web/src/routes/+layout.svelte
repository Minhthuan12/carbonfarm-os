<!-- SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<script lang="ts">
	import '@fontsource-variable/source-serif-4/opsz.css';
	import '@fontsource-variable/inter/opsz.css';
	import '../app.css';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href="/nen/logo-transparent.png" type="image/png" />
	<meta name="theme-color" content="#0b5d4c" />
</svelte:head>

{@render children()}
