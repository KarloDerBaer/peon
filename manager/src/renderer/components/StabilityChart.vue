<!-- Verlauf des Stabilitätsindex (ab 0.46.0): Markt, Massenware und Handwerkswaren je Rechnung, dahinter die Stufen -->
<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent, MarkAreaComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, MarkAreaComponent, CanvasRenderer]);

const props = defineProps({ hist: Array, theme: String, height: { type: Number, default: 200 } });
const el = ref(null);
let chart = null;
let ro = null;

const LEVELS = ['sehr stabil', 'stabil', 'mittel', 'unruhig', 'unsicher'];
function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }

function draw() {
  if (!chart) return;
  const h = props.hist || [];
  const span = h.length > 1 ? h[h.length - 1].t - h[0].t : 0;
  const short = span < 3 * 86400;
  const text = css('--muted'), line = css('--line-soft'), font = 'Barlow, Segoe UI, sans-serif';
  const up = css('--up'), warn = css('--warn'), bad = css('--bad');
  // Stufen als blasse Baender: 80 bis 100 sehr stabil, darunter je 20
  const bands = [up, up, warn, bad, bad].map((c, i) => [{ yAxis: 100 - i * 20, itemStyle: { color: c, opacity: i === 1 || i === 3 ? 0.05 : 0.09 } }, { yAxis: 80 - i * 20 }]);
  const series = [
    { key: 'all', name: 'Ganzer Markt', color: css('--text'), width: 2.5 },
    { key: 'mass', name: 'Massenware', color: css('--accent'), width: 2 },
    { key: 'craft', name: 'Handwerkswaren', color: css('--gold'), width: 2 },
  ].map((s, n) => ({
    name: s.name, type: 'line', showSymbol: h.length < 40, symbolSize: 5, connectNulls: false,
    lineStyle: { width: s.width, color: s.color }, itemStyle: { color: s.color },
    data: h.map((e) => [e.t * 1000, e[s.key] ? e[s.key].i : null]),
    markArea: n === 0 ? { silent: true, data: bands } : undefined,
  }));
  chart.setOption({
    animation: false,
    grid: { left: 40, right: 86, top: 34, bottom: 28 },
    legend: { top: 0, left: 0, textStyle: { color: text, fontFamily: font }, itemWidth: 14, itemHeight: 3, icon: 'rect' },
    tooltip: { trigger: 'axis', backgroundColor: css('--raised'), borderColor: css('--line'), textStyle: { color: css('--text'), fontFamily: font },
      valueFormatter: (v) => (v == null ? '–' : `${v} (${LEVELS[Math.min(4, Math.floor((100 - v) / 20))]})`) },
    xAxis: { type: 'time', minInterval: short ? 3600 * 1000 : 86400 * 1000, axisLine: { lineStyle: { color: line } }, axisLabel: { color: text, fontFamily: font, hideOverlap: true,
      formatter: (v) => { const d = new Date(v), day = d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }); return short ? `${day} ${d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })}` : day; } }, splitLine: { show: false } },
    yAxis: [
      { type: 'value', min: 0, max: 100, interval: 20, axisLabel: { color: text, fontFamily: font }, splitLine: { lineStyle: { color: line } } },
      // rechts die Namen der Stufen, jeweils in der Mitte ihres Bandes
      { type: 'value', min: 0, max: 100, interval: 10, position: 'right', splitLine: { show: false }, axisLine: { show: false }, axisTick: { show: false },
        axisLabel: { color: text, fontFamily: font, fontSize: 11, formatter: (v) => (v % 20 === 10 ? LEVELS[(90 - v) / 20] : '') } },
    ],
    series,
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
watch(() => [props.hist, props.theme], () => setTimeout(draw), { deep: true });
</script>

<template>
  <div ref="el" class="chart" :style="{ height: height + 'px' }"></div>
</template>

<style scoped>
.chart { width: 100%; }
</style>
