<!-- Preisstufen: wie viel Stueck es bis zu welchem Preis gibt (Treppe der Summe) -->
<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as echarts from 'echarts/core';
import { LineChart } from 'echarts/charts';
import { GridComponent, TooltipComponent } from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
import { shortMoney, coins } from '../util.js';
echarts.use([LineChart, GridComponent, TooltipComponent, CanvasRenderer]);

const props = defineProps({ levels: Object, theme: String });
const el = ref(null);
let chart = null, ro = null;
const css = (n) => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const FONT = 'Barlow, Segoe UI, sans-serif';

function draw() {
  if (!chart || !props.levels) return;
  // ohne Ausreisser oben: bis zum Dreifachen des Preises, bei dem die Haelfte der Stueck erreicht ist
  const list = props.levels.list;
  const total = list.length ? list[list.length - 1].cum : 0;
  const half = list.find((x) => x.cum >= total / 2);
  const cap = half ? half.price * 3 : Infinity;
  const shown = list.filter((x) => x.price <= cap);
  const text = css('--muted'), line = css('--line-soft'), accent = css('--accent');
  chart.setOption({
    animation: false,
    grid: { left: 56, right: 16, top: 12, bottom: 28 },
    tooltip: { trigger: 'axis', backgroundColor: css('--raised'), borderColor: css('--line'), textStyle: { color: css('--text'), fontFamily: FONT },
      formatter: (ps) => { const p = ps[0]; const c = coins(p.value[0]);
        return `bis ${c.g ? c.g + 'g ' : ''}${c.g || c.s ? c.s + 's ' : ''}${c.c}c je Stück:<br>${Number(p.value[1]).toLocaleString('de-DE')} Stück`; } },
    xAxis: { type: 'value', scale: true, axisLabel: { color: text, fontFamily: FONT, formatter: shortMoney, hideOverlap: true }, axisLine: { lineStyle: { color: line } }, splitLine: { show: false } },
    yAxis: { type: 'value', axisLabel: { color: text, fontFamily: FONT, formatter: (v) => v.toLocaleString('de-DE') }, splitLine: { lineStyle: { color: line } } },
    series: [{ type: 'line', step: 'end', symbol: 'none', lineStyle: { width: 2, color: accent }, areaStyle: { color: css('--accent-soft') },
      data: shown.map((x) => [x.price, x.cum]) }],
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
watch(() => [props.levels, props.theme], () => setTimeout(draw));
</script>

<template>
  <div ref="el" class="chart"></div>
</template>

<style scoped>
.chart { width: 100%; height: 220px; }
</style>
