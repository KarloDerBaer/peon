<!-- Kleine Linie der Tageswerte (Lücken bleiben offen), Bereich als Band -->
<script setup>
import { computed } from 'vue';
const props = defineProps({ values: Array, low: Number, high: Number, width: { type: Number, default: 96 }, height: { type: Number, default: 24 } });
const geo = computed(() => {
  const v = props.values || [];
  const xs = v.filter((x) => x != null);
  if (!xs.length) return null;
  let lo = Math.min(...xs, props.low ?? Infinity), hi = Math.max(...xs, props.high ?? -Infinity);
  if (hi <= lo) { hi = lo + 1; }
  const W = props.width, H = props.height, pad = 2;
  const x = (i) => pad + (i * (W - 2 * pad)) / Math.max(1, v.length - 1);
  const y = (val) => H - pad - ((val - lo) / (hi - lo)) * (H - 2 * pad);
  const segs = [];
  let cur = [];
  v.forEach((val, i) => { if (val == null) { if (cur.length) segs.push(cur); cur = []; } else cur.push(`${x(i).toFixed(1)},${y(val).toFixed(1)}`); });
  if (cur.length) segs.push(cur);
  const band = props.low != null && props.high != null ? { y: y(props.high), h: Math.max(1, y(props.low) - y(props.high)) } : null;
  const lastI = v.map((val, i) => (val == null ? -1 : i)).filter((i) => i >= 0).pop();
  return { segs, band, W, H, dot: lastI != null ? { x: x(lastI), y: y(v[lastI]) } : null };
});
</script>

<template>
  <svg v-if="geo" :width="geo.W" :height="geo.H" :viewBox="`0 0 ${geo.W} ${geo.H}`" aria-hidden="true" class="spark">
    <rect v-if="geo.band" x="0" :y="geo.band.y" :width="geo.W" :height="geo.band.h" class="band" />
    <polyline v-for="(s, k) in geo.segs" :key="k" :points="s.join(' ')" class="line" />
    <circle v-if="geo.dot" :cx="geo.dot.x" :cy="geo.dot.y" r="2.2" class="dot" />
  </svg>
</template>

<style scoped>
.spark { display: block; }
.band { fill: var(--accent-soft); }
.line { fill: none; stroke: var(--muted); stroke-width: 1.5; stroke-linejoin: round; }
.dot { fill: var(--text); }
</style>
