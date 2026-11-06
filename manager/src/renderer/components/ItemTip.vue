<script setup>
// Gegenstands-Tooltip wie im Spiel, Daten aus der Blizzard-API (src/core/item-info.js)
import { computed } from 'vue';
import Gold from './Gold.vue';
import { qualityColor } from '../util.js';

const props = defineProps({
  info: Object,                       // { state, tip } oder null, solange nichts geladen ist
  name: String,                       // Name aus der Liste, bei Zusatz der volle Name
  quality: Number,
  variant: Boolean,                   // Gegenstand mit Zusatz: Die API nennt nur die Grundwerte
});
const tip = computed(() => (props.info && props.info.tip) || null);
const shownName = computed(() => props.name || (tip.value && tip.value.name) || '');
const shownQuality = computed(() => props.quality ?? (tip.value ? tip.value.quality : null));
const NOTE = {
  none: 'Blizzard liefert zu diesem Gegenstand keine Werte.',
  'no-access': 'Werte gibt es mit einem Blizzard-Zugang unter Einstellungen.',
  unreachable: 'Blizzard ist gerade nicht erreichbar.',
};
</script>

<template>
  <div class="itemtip">
    <div class="name" :style="{ color: qualityColor(shownQuality) }">{{ shownName }}</div>
    <template v-if="tip">
      <div v-for="(l, i) in tip.lines" :key="i" class="line" :class="l.c">
        <span>{{ l.l }}</span><span v-if="l.r" class="right">{{ l.r }}</span>
      </div>
      <div class="line sell" v-if="tip.sell">Händler <Gold :copper="tip.sell" /></div>
      <p class="note" v-if="variant && !tip.exact">Nur Grundwerte. Die genauen Werte holt der Manager aus dem Spiel, sie kommen nach dem nächsten Laden dort.</p>
      <p class="note" v-if="tip.exact">Genaue Werte aus dem Spiel.</p>
      <p class="note" v-if="tip.source === 'classic'">Aus den Classic-Daten, in Forever kann es abweichen.</p>
    </template>
    <p class="note" v-else-if="info">{{ NOTE[info.state] }}</p>
    <p class="note" v-else>Lade Werte</p>
  </div>
</template>

<style scoped>
.itemtip { width: 100%; max-width: 340px; display: grid; gap: 2px; padding: 10px 12px; font-size: 13px; line-height: 1.35; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-m); }
.name { font-size: 15px; font-weight: 600; margin-bottom: 2px; }
.line { display: flex; justify-content: space-between; gap: 12px; }
.right { white-space: nowrap; }
.level { color: var(--gold); }
.good { color: var(--up); }
.set { color: var(--gold); margin-top: 6px; }
.muted { color: var(--muted); }
.desc { color: var(--gold); margin-top: 4px; }
.reagent { color: var(--q7); }
.sell { justify-content: flex-start; color: var(--muted); margin-top: 4px; }
.note { margin: 6px 0 0; font-size: 12px; color: var(--muted); }
</style>
