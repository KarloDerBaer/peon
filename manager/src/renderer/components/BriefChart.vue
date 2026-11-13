<!-- Diagramm im Steckbrief (Peon_Manager_Chancen.md 6.1 Stufe 3): Angebote als Linie, echte Verkaeufe als Punkte,
     Zielpreis und Kaufen bis als Linien, Prognose als Faecher -->
<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart, ScatterChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent, MarkLineComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
import { shortMoney, coins } from '../util.js';
echarts.use([LineChart, ScatterChart, GridComponent, TooltipComponent, LegendComponent, MarkLineComponent, CanvasRenderer]);

const props = defineProps({ brief: Object, theme: String });
const el = ref(null);
let chart = null, ro = null;
const css = (n) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const FONT = 'Barlow, Segoe UI, sans-serif';
const money = (v) => { const c = coins(v); return c ? (c.g ? `${c.g.toLocaleString('de-DE')}g ` : '') + (c.g || c.s ? `${c.s}s ` : '') + `${c.c}c` : '–'; };

function draw() {
  if (!chart || !props.brief) return;
  const b = props.brief;
  const text = css('--muted'), line = css('--line-soft'), accent = css('--accent'), gold = css('--gold'), up = css('--up'), bad = css('--bad'), silver = css('--silver') || text;
  const med = b.offers.filter((x) => x.median != null).map((x) => [x.t * 1000, Math.round(x.median)]);
  const min = b.offers.filter((x) => x.min != null).map((x) => [x.t * 1000, Math.round(x.min)]);
  const maxQ = Math.max(1, ...b.sales.map((x) => x.qty));
  const sales = b.sales.map((x) => ({ value: [x.t * 1000, x.price], qty: x.qty, symbolSize: 5 + 14 * Math.sqrt(x.qty / maxQ) }));
  const marks = [];
  if (b.best && b.best.target) marks.push({ yAxis: b.best.target, name: 'Zielpreis', lineStyle: { color: up, type: 'dashed' }, label: { formatter: 'Zielpreis', color: up } });
  if (b.best && b.best.buy) marks.push({ yAxis: b.best.buy, name: 'Kaufen bis', lineStyle: { color: accent, type: 'dashed' }, label: { formatter: 'Kaufen bis', color: accent } });
  // Prognose als Faecher: vom letzten Median aus bis zum Ende des Zeitraums, Breite nach Sicherheit
  const series = [
    { name: 'Median der Angebote', type: 'line', data: med, showSymbol: false, lineStyle: { width: 2, color: gold }, itemStyle: { color: gold }, markLine: { symbol: 'none', data: marks, silent: true } },
    { name: 'Günstigstes Angebot', type: 'line', data: min, showSymbol: false, lineStyle: { width: 1, color: silver, type: 'dotted' }, itemStyle: { color: silver } },
    { name: 'Verkauft', type: 'scatter', data: sales, symbolSize: (v, p) => p.data.symbolSize, itemStyle: { color: up, opacity: 0.75 } },
  ];
  const f = b.forecast;
  if (f && med.length) {
    const [t0, p0] = med[med.length - 1];
    const t1 = t0 + f.days * 86400 * 1000;
    const end = p0 * (1 + f.dir * f.expect);
    const w = { low: 0.6, mid: 0.4, high: 0.2 }[f.sure] * Math.abs(end - p0);
    const col = f.dir > 0 ? up : bad;
    series.push({ name: 'Prognose', type: 'line', data: [[t0, p0], [t1, Math.round(end)]], showSymbol: false, lineStyle: { color: col, type: 'dashed', width: 2 }, itemStyle: { color: col } });
    series.push({ name: '_hi', type: 'line', data: [[t0, p0], [t1, Math.round(end + w)]], showSymbol: false, lineStyle: { color: col, opacity: 0.35, width: 1 }, areaStyle: null, silent: true });
    series.push({ name: '_lo', type: 'line', data: [[t0, p0], [t1, Math.round(Math.max(1, end - w))]], showSymbol: false, lineStyle: { color: col, opacity: 0.35, width: 1 }, silent: true });
  }
  chart.setOption({
    animation: false,
    textStyle: { fontFamily: FONT },
    legend: { top: 0, left: 0, textStyle: { color: text, fontFamily: FONT }, data: ['Median der Angebote', 'Günstigstes Angebot', 'Verkauft', 'Prognose'] },
    grid: { left: 64, right: 16, top: 34, bottom: 28 },
    tooltip: { trigger: 'item', backgroundColor: css('--raised'), borderColor: css('--line'), textStyle: { color: css('--text'), fontFamily: FONT },
      formatter: (p) => `${new Date(p.value[0]).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}<br>${p.seriesName}: ${money(p.value[1])}${p.data && p.data.qty ? ` · ${Math.round(p.data.qty)} Stück` : ''}` },
    xAxis: { type: 'time', axisLine: { lineStyle: { color: line } }, axisLabel: { color: text, hideOverlap: true, formatter: (v) => new Date(v).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }) } },
    yAxis: { type: 'value', scale: true, splitLine: { lineStyle: { color: line } }, axisLabel: { color: text, formatter: shortMoney } },
    series,
  }, true);
}

onMounted(() => {
  chart = echarts.init(el.value, null, { renderer: 'canvas' });
  ro = new ResizeObserver(() => chart && chart.resize());
  ro.observe(el.value);
  draw();
});
onBeforeUnmount(() => { if (ro) ro.disconnect(); if (chart) chart.dispose(); chart = null; });
watch(() => [props.brief, props.theme], draw);
</script>

<template><div ref="el" class="chart" role="img" aria-label="Verlauf der Angebote, echte Verkäufe und Prognose"></div></template>

<style scoped>
.chart { width: 100%; height: 320px; }
</style>
