<!-- Verlauf eines Gegenstands: Preis je Stueck (oben) und Stueck (unten), gemeinsame Zeitachse -->
<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart, BarChart, ScatterChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent, AxisPointerComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
import { shortMoney, coins } from '../util.js';
echarts.use([LineChart, BarChart, ScatterChart, GridComponent, TooltipComponent, LegendComponent, AxisPointerComponent, CanvasRenderer]);

const props = defineProps({ detail: Object, theme: String });
const el = ref(null);
let chart = null, ro = null;
const css = (n) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const FONT = 'Barlow, Segoe UI, sans-serif';

function money(v) {
  const c = coins(v);
  if (!c) return '–';
  return (c.g ? `${c.g.toLocaleString('de-DE')}g ` : '') + (c.g || c.s ? `${c.s}s ` : '') + `${c.c}c`;
}

function draw() {
  if (!chart || !props.detail) return;
  const d = props.detail;
  const own = [...d.own.filter((x) => x.source === 'scan'), ...d.hours.filter((x) => x.source === 'scan'), ...d.days.filter((x) => x.source === 'scan')]
    .sort((a, b) => a.t - b.t);
  const live = d.own.filter((x) => x.source === 'live' && x.min != null);
  const br = d.broker;
  const P = (arr, f) => arr.filter((x) => x[f] != null).map((x) => [x.t * 1000, x[f]]);
  const text = css('--muted'), line = css('--line-soft'), accent = css('--accent'), silver = css('--silver'), faint = css('--faint'), gold = css('--gold');
  const axisX = (i) => ({ type: 'time', gridIndex: i, axisLine: { lineStyle: { color: line } }, splitLine: { show: false },
    axisLabel: { show: i === 1, color: text, fontFamily: FONT, hideOverlap: true,
      formatter: (v) => new Date(v).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }) } });
  const band = own.filter((x) => x.p25 != null && x.p75 != null);
  // Ueblicher Bereich je Tag (wie Broker ihn an dem Tag bekommen haette), als Treppe ueber den Tag
  const bands = d.bands || [];
  const step = (f) => bands.flatMap((b) => [[(b.t - 12 * 3600) * 1000, b[f]], [(b.t + 12 * 3600 - 1) * 1000, b[f]]]);
  const sd = (d.salesDays || []).map((x) => [x.t * 1000, Math.round(x.perDay * 10) / 10]);
  const warn = css('--warn');
  chart.setOption({
    animation: false,
    textStyle: { fontFamily: FONT },
    legend: { top: 0, left: 0, textStyle: { color: text, fontFamily: FONT }, itemWidth: 14, itemHeight: 3,
      data: ['Median', 'Min', 'Mittlere Hälfte', 'Üblicher Bereich', 'Live (Min)', 'Broker (Tagesmittel)', 'Menge', 'Menge Broker', 'Absatz je Tag'] },
    tooltip: { trigger: 'axis', axisPointer: { type: 'line', link: [{ xAxisIndex: 'all' }] }, backgroundColor: css('--raised'), borderColor: css('--line'),
      textStyle: { color: css('--text'), fontFamily: FONT },
      formatter: (ps) => {
        if (!ps.length) return '';
        const t = new Date(ps[0].axisValue).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
        const seen = new Set();
        const rows = ps.filter((p) => !p.seriesName.startsWith('_') && !(p.seriesName === 'Üblicher Bereich' && seen.has(p.seriesIndex))).map((p) => {
          seen.add(p.seriesIndex);
          if (p.seriesName === 'Üblicher Bereich') {
            const lo = ps.find((q) => q.seriesId === 'bandLow'), hi = ps.find((q) => q.seriesId === 'bandHigh');
            if (p.seriesId === 'bandHigh') return null;
            return `${p.marker}Üblicher Bereich: ${money(lo && lo.value[1])} bis ${money(hi && hi.value[1])}`;
          }
          const v = Array.isArray(p.value) ? p.value[1] : p.value;
          const val = p.seriesName.startsWith('Menge') || p.seriesName === 'Absatz je Tag' ? Number(v).toLocaleString('de-DE') : money(v);
          return `${p.marker}${p.seriesName}: ${val}`;
        });
        return `${t}<br>${rows.filter(Boolean).join('<br>')}`;
      } },
    axisPointer: { link: [{ xAxisIndex: 'all' }] },
    grid: [{ left: 64, right: 48, top: 56, height: '48%' }, { left: 64, right: 48, top: '70%', bottom: 28 }],
    xAxis: [axisX(0), axisX(1)],
    yAxis: [
      { type: 'value', gridIndex: 0, scale: true, axisLabel: { color: text, fontFamily: FONT, formatter: shortMoney }, splitLine: { lineStyle: { color: line } } },
      { type: 'value', gridIndex: 1, axisLabel: { color: text, fontFamily: FONT, formatter: (v) => v.toLocaleString('de-DE') }, splitLine: { lineStyle: { color: line } } },
      // Absatz je Tag rechts mit eigener Skala (Menge im AH ist oft viel groesser)
      { type: 'value', gridIndex: 1, position: 'right', show: sd.length > 0, axisLabel: { color: gold, fontFamily: FONT, formatter: (v) => v.toLocaleString('de-DE') }, splitLine: { show: false } },
    ],
    series: [
      // Band p25..p75: unterer Rand unsichtbar, darauf gestapelt die Differenz
      { name: '_p25', type: 'line', stack: 'band', symbol: 'none', lineStyle: { opacity: 0 }, data: band.map((x) => [x.t * 1000, x.p25]), tooltip: { show: false } },
      { name: 'Mittlere Hälfte', type: 'line', stack: 'band', symbol: 'none', lineStyle: { opacity: 0 }, areaStyle: { color: css('--accent-soft') },
        itemStyle: { color: css('--accent-soft') }, data: band.map((x) => [x.t * 1000, x.p75 - x.p25]), tooltip: { show: false } },
      { name: 'Median', type: 'line', showSymbol: own.length < 60, symbolSize: 5, lineStyle: { width: 2, color: accent }, itemStyle: { color: accent }, data: P(own, 'median') },
      { name: 'Min', type: 'line', showSymbol: own.length < 60, symbolSize: 4, lineStyle: { width: 1.5, color: silver }, itemStyle: { color: silver }, data: P(own, 'min') },
      { id: 'bandLow', name: 'Üblicher Bereich', type: 'line', symbol: 'none', lineStyle: { width: 1.2, type: [6, 4], color: warn }, itemStyle: { color: warn }, data: step('low') },
      { id: 'bandHigh', name: 'Üblicher Bereich', type: 'line', symbol: 'none', lineStyle: { width: 1.2, type: [6, 4], color: warn }, itemStyle: { color: warn }, data: step('high') },
      { name: 'Live (Min)', type: 'scatter', symbol: 'diamond', symbolSize: 8, itemStyle: { color: gold }, data: P(live, 'min') },
      { name: 'Broker (Tagesmittel)', type: 'line', symbol: 'emptyCircle', symbolSize: 6, lineStyle: { width: 1.5, type: [5, 4], color: faint }, itemStyle: { color: faint }, data: P(br, 'median') },
      { name: 'Menge', type: 'bar', xAxisIndex: 1, yAxisIndex: 1, barMaxWidth: 10, itemStyle: { color: accent, opacity: 0.75 }, data: P(own, 'qty') },
      { name: 'Absatz je Tag', type: 'line', xAxisIndex: 1, yAxisIndex: 2, symbol: 'circle', symbolSize: 6, lineStyle: { width: 2, color: gold }, itemStyle: { color: gold }, data: sd },
      { name: 'Menge Broker', type: 'line', xAxisIndex: 1, yAxisIndex: 1, symbol: 'emptyCircle', symbolSize: 5, lineStyle: { width: 1.5, type: [5, 4], color: faint }, itemStyle: { color: faint }, data: P(br, 'qty') },
    ],
  }, true);
}

onMounted(() => {
  chart = echarts.init(el.value, null, { renderer: 'canvas' });
  draw();
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => draw());
  ro = new ResizeObserver(() => chart && chart.resize());
  ro.observe(el.value);
});
onBeforeUnmount(() => { if (ro) ro.disconnect(); if (chart) chart.dispose(); chart = null; });
watch(() => [props.detail, props.theme], () => setTimeout(draw), { deep: false });
</script>

<template>
  <div ref="el" class="chart"></div>
</template>

<style scoped>
.chart { width: 100%; height: 420px; }
</style>
