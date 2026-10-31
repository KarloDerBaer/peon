<!-- Angebote und Gegenstände je Komplettscan (letzte 30 Tage) -->
<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer]);

const props = defineProps({ history: Array, theme: String });
const el = ref(null);
let chart = null;
let ro = null;

function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }

function draw() {
  if (!chart) return;
  const h = props.history || [];
  const text = css('--muted'), line = css('--line-soft'), accent = css('--accent'), silver = css('--silver');
  chart.setOption({
    animation: false,
    grid: { left: 56, right: 56, top: 34, bottom: 28 },
    legend: { top: 0, left: 0, textStyle: { color: text, fontFamily: 'Barlow, Segoe UI, sans-serif' }, itemWidth: 14, itemHeight: 3, icon: 'rect' },
    tooltip: { trigger: 'axis', backgroundColor: css('--raised'), borderColor: css('--line'), textStyle: { color: css('--text'), fontFamily: 'Barlow, Segoe UI, sans-serif' },
      valueFormatter: (v) => Number(v).toLocaleString('de-DE') },
    xAxis: { type: 'time', axisLine: { lineStyle: { color: line } }, axisLabel: { color: text, fontFamily: 'Barlow, Segoe UI, sans-serif', hideOverlap: true,
      formatter: (v) => new Date(v).toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }) }, splitLine: { show: false } },
    yAxis: [
      { type: 'value', name: '', axisLabel: { color: text, fontFamily: 'Barlow, Segoe UI, sans-serif', formatter: (v) => v.toLocaleString('de-DE') }, splitLine: { lineStyle: { color: line } } },
      { type: 'value', name: '', axisLabel: { color: text, fontFamily: 'Barlow, Segoe UI, sans-serif', formatter: (v) => v.toLocaleString('de-DE') }, splitLine: { show: false } },
    ],
    series: [
      { name: 'Angebote', type: 'line', step: false, showSymbol: h.length < 40, symbolSize: 5, lineStyle: { width: 2, color: accent }, itemStyle: { color: accent },
        areaStyle: { color: css('--accent-soft') }, data: h.map((x) => [x.t * 1000, x.offers]) },
      { name: 'Gegenstände', type: 'line', yAxisIndex: 1, showSymbol: h.length < 40, symbolSize: 4, lineStyle: { width: 1.5, color: silver, type: [4, 3] }, itemStyle: { color: silver },
        data: h.map((x) => [x.t * 1000, x.items]) },
    ],
  }, true);
}

onMounted(() => {
  chart = echarts.init(el.value, null, { renderer: 'canvas' });
  draw();
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => draw());   // Achsen erst mit geladener Schrift
  ro = new ResizeObserver(() => chart && chart.resize());
  ro.observe(el.value);
});
onBeforeUnmount(() => { if (ro) ro.disconnect(); if (chart) chart.dispose(); chart = null; });
watch(() => [props.history, props.theme], () => setTimeout(draw), { deep: true });
</script>

<template>
  <div ref="el" class="chart"></div>
</template>

<style scoped>
.chart { width: 100%; height: 230px; }
</style>
