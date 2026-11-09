<script setup>
// Haendler (Manager 0.25, Umbau Broker U11): alles, was Broker bei Haendlern gesehen hat, mit dem Preis im Auktionshaus.
// Die Daten kommen aus Peon_Broker.lua (PeonBrokerDB.vendors), der Manager liest sie bei jedem neuen Stand mit.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import { fold, qualityColor, ago } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, now: Number });
const emit = defineEmits(['open']);
const api = window.peon;

const view = ref(null);
const search = ref('');
const onlyProfit = ref(false);
const zone = ref('');

async function load() { view.value = await api.vendors(props.market ? props.market.key : ''); }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

const zones = computed(() => (view.value ? [...new Set(view.value.rows.map((r) => r.zone).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'de')) : []));
const rows = computed(() => {
  if (!view.value) return [];
  const q = fold(search.value.trim());
  return view.value.rows.filter((r) => (!onlyProfit.value || r.profit) && (!zone.value || r.zone === zone.value)
    && (!q || fold(`${r.name} ${r.vendor} ${r.zone}`).includes(q)));
});
</script>

<template>
  <div class="vendors" v-if="view">
    <div class="head">
      <h1>Händler</h1>
      <span class="muted small">{{ view.vendors }} Händler mit {{ view.offers }} Angeboten<template v-if="view.oldest">, ältester Besuch {{ ago(view.oldest, now) }}</template></span>
    </div>
    <div class="filters">
      <input type="search" v-model="search" placeholder="Gegenstand, Händler oder Zone" aria-label="Suche" spellcheck="false" />
      <select v-model="zone" aria-label="Zone">
        <option value="">Alle Zonen</option>
        <option v-for="z in zones" :key="z" :value="z">{{ z }}</option>
      </select>
      <label class="check small"><input type="checkbox" v-model="onlyProfit" /> Nur mit AH-Gewinn</label>
    </div>
    <p v-if="!view.rows.length" class="muted">Noch keine Händler. Broker merkt sich die Angebote, wenn du im Spiel ein Händlerfenster öffnest.</p>
    <table v-else class="tbl">
      <thead><tr><th>Gegenstand</th><th class="num">Preis</th><th>Händler</th><th>Zone</th><th>Braucht</th><th class="num" title="Günstigstes Angebot im Auktionshaus. Grün: nach dem Anteil des Hauses mehr als beim Händler">AH</th></tr></thead>
      <tbody>
        <tr v-for="r in rows" :key="r.npc + ':' + r.key" :class="{ hit: r.profit }">
          <td class="name click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name }}</td>
          <td class="num"><Gold v-if="r.price != null" :copper="r.price" compact /><span v-for="(c, i) in r.costs" :key="i" class="small"> {{ c.n }} {{ c.name }}</span></td>
          <td>{{ r.vendor }}</td>
          <td class="small">{{ r.zone }}<span v-if="r.x != null" class="muted"> ({{ r.x }}, {{ r.y }})</span></td>
          <td class="small warn">{{ r.req || '' }}</td>
          <td class="num" :class="{ good: r.profit }"><Gold v-if="r.ah != null" :copper="r.ah" compact /><span v-else class="muted">–</span></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.head { display: flex; align-items: baseline; gap: 12px; }
.filters { display: flex; gap: 10px; align-items: center; margin: 8px 0 12px; }
.filters input[type="search"] { min-width: 260px; }
.good { color: var(--good, #60e060); }
.warn { color: var(--warn, #ff7070); }
</style>
