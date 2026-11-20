<!-- ab 0.52.0: Verlauf eines Gegenstands in beiden Haeusern (Reiter Neutral der Gegenstandsseite).
     Linien: guenstigster Preis je Tag, Punkte: Mittel der echten Verkaufspreise. Luecken bleiben offen. -->
<script setup>
import { computed, ref } from 'vue';
import { shortMoney } from '../util.js';

const props = defineProps({ series: Object, home: String, neutral: String });
const W = 640, H = 200, L = 64, R = 12, T = 12, B = 26;
const hover = ref(null);

const geo = computed(() => {
  const s = props.series;
  if (!s || !s.days || !s.days.length) return null;
  const all = [...s.home, ...s.neutral, ...s.homeSold, ...s.neutralSold].filter((v) => v != null && v > 0);
  if (!all.length) return null;
  let lo = Math.min(...all), hi = Math.max(...all);
  if (hi <= lo) { hi = lo * 1.1 + 1; lo = lo * 0.9; }
  const pad = (hi - lo) * 0.08;
  lo = Math.max(0, lo - pad); hi += pad;
  const n = s.days.length;
  const x = (i) => L + (i * (W - L - R)) / Math.max(1, n - 1);
  const y = (v) => T + (1 - (v - lo) / (hi - lo)) * (H - T - B);
  const line = (vals) => {
    const segs = [];
    let cur = [];
    vals.forEach((v, i) => { if (v == null) { if (cur.length) segs.push(cur); cur = []; } else cur.push(`${x(i).toFixed(1)},${y(v).toFixed(1)}`); });
    if (cur.length) segs.push(cur);
    return segs.map((p) => p.join(' '));
  };
  const dots = (vals) => vals.map((v, i) => (v == null ? null : { x: x(i), y: y(v) })).filter(Boolean);
  const ticks = [0, 0.5, 1].map((f) => { const v = lo + (hi - lo) * f; return { y: y(v), label: shortMoney(Math.round(v)) }; });
  const fmt = (d) => { const t = new Date(d * 86400 * 1000); return `${t.getDate()}.${t.getMonth() + 1}.`; };
  const xt = [0, Math.floor((n - 1) / 2), n - 1].map((i) => ({ x: x(i), label: fmt(s.days[i]) }));
  return { home: line(s.home), neutral: line(s.neutral), homeSold: dots(s.homeSold), neutralSold: dots(s.neutralSold), ticks, xt, x, n };
});

function move(ev) {
  const g = geo.value;
  if (!g) return;
  const r = ev.currentTarget.getBoundingClientRect();
  const px = ((ev.clientX - r.left) / r.width) * W;
  const i = Math.round(((px - L) / (W - L - R)) * (g.n - 1));
  hover.value = i >= 0 && i < g.n ? i : null;
}
const hoverText = computed(() => {
  const i = hover.value, s = props.series;
  if (i == null || !s) return '';
  const t = new Date(s.days[i] * 86400 * 1000);
  const m = (v) => (v == null ? '–' : shortMoney(v));
  return `${t.getDate()}.${t.getMonth() + 1}.: ${props.home} ${m(s.home[i])} (verkauft ${m(s.homeSold[i])}), ${props.neutral} ${m(s.neutral[i])} (verkauft ${m(s.neutralSold[i])})`;
});
</script>

<template>
  <div v-if="geo" class="cmp-chart">
    <svg :viewBox="`0 0 ${W} ${H}`" class="svg" role="img" :aria-label="`Preise ${home} und ${neutral} der letzten 30 Tage`" @mousemove="move" @mouseleave="hover = null">
      <line v-for="(t, k) in geo.ticks" :key="'g' + k" :x1="L" :x2="W - R" :y1="t.y" :y2="t.y" class="grid" />
      <text v-for="(t, k) in geo.ticks" :key="'t' + k" :x="L - 6" :y="t.y + 4" class="axis" text-anchor="end">{{ t.label }}</text>
      <text v-for="(t, k) in geo.xt" :key="'x' + k" :x="t.x" :y="H - 6" class="axis" text-anchor="middle">{{ t.label }}</text>
      <polyline v-for="(p, k) in geo.home" :key="'h' + k" :points="p" class="home" />
      <polyline v-for="(p, k) in geo.neutral" :key="'n' + k" :points="p" class="neutral" />
      <circle v-for="(d, k) in geo.homeSold" :key="'hs' + k" :cx="d.x" :cy="d.y" r="2.6" class="home-dot" />
      <circle v-for="(d, k) in geo.neutralSold" :key="'ns' + k" :cx="d.x" :cy="d.y" r="2.6" class="neutral-dot" />
      <line v-if="hover != null" :x1="geo.x(hover)" :x2="geo.x(hover)" :y1="T" :y2="H - B" class="cursor" />
    </svg>
    <div class="legend small">
      <span><i class="sw home-sw"></i>{{ home }} günstigster</span>
      <span><i class="sw neutral-sw"></i>{{ neutral }} günstigster</span>
      <span><i class="dt home-sw"></i>{{ home }} verkauft</span>
      <span><i class="dt neutral-sw"></i>{{ neutral }} verkauft</span>
    </div>
    <p class="small muted hover">{{ hoverText || 'Maus über das Diagramm: Werte des Tages' }}</p>
  </div>
  <p v-else class="small muted">Für das Diagramm fehlen noch Preise aus den letzten 30 Tagen.</p>
</template>

<style scoped>
.cmp-chart { max-width: 720px; }
.svg { width: 100%; height: auto; display: block; }
.grid { stroke: var(--line); stroke-width: 1; }
.axis { fill: var(--muted); font-size: 11px; }
.home { fill: none; stroke: var(--accent); stroke-width: 2; }
.neutral { fill: none; stroke: #e0b000; stroke-width: 2; }
.home-dot { fill: var(--accent); opacity: 0.75; }
.neutral-dot { fill: #e0b000; opacity: 0.75; }
.cursor { stroke: var(--muted); stroke-dasharray: 3 3; }
.legend { display: flex; gap: 16px; flex-wrap: wrap; margin-top: 4px; color: var(--muted); }
.sw { display: inline-block; width: 14px; height: 3px; margin-right: 6px; vertical-align: middle; }
.dt { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 6px; vertical-align: middle; }
.home-sw { background: var(--accent); }
.neutral-sw { background: #e0b000; }
.hover { min-height: 1.4em; margin: 4px 0 0; }
</style>
