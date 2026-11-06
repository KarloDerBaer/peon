<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import MarketChart from '../components/MarketChart.vue';
import Checklist from '../components/Checklist.vue';
import { when, num, pct, qualityColor, pl } from '../util.js';
import { statusLine, LAMP_TITLE } from '../status.js';

const props = defineProps({ data: Object, market: Object, now: Number, theme: String, stamp: Number, settings: Object });
const emit = defineEmits(['go', 'open', 'save']);
const api = window.peon;

const status = computed(() => statusLine(props.data, props.market, props.now));

// Kennzahlen: letzter Stand gegen einen Stand etwa einen Tag vorher
const hist = computed(() => (props.market ? props.market.history : []));
const dayBefore = computed(() => {
  const h = hist.value;
  if (h.length < 2) return null;
  const last = h[h.length - 1];
  let base = null;
  for (const x of h) if (x.t <= last.t - 20 * 3600) base = x;
  return base;
});
function change(field) {
  const b = dayBefore.value;
  const l = hist.value[hist.value.length - 1];
  if (!b || !l || !b[field]) return null;
  return l[field] / b[field] - 1;
}

// Titel des Diagramms nach dem echten Zeitraum
const chartTitle = computed(() => {
  const h = hist.value;
  if (h.length < 2) return 'Markt';
  const hours = (h[h.length - 1].t - h[0].t) / 3600;
  if (hours < 48) return `Markt in den letzten ${Math.max(1, Math.round(hours))} Stunden`;
  const days = Math.round(hours / 24);
  return days >= 30 ? 'Markt in den letzten 30 Tagen' : `Markt in den letzten ${days} Tagen`;
});

// Chancen und Absatz kommen aus derselben Rechnung wie der Reiter Chancen
const ch = ref(null);
const buyable = ref([]);   // Einkaufsliste: gerade unter dem Hoechstpreis
async function load() {
  if (!props.market) { ch.value = null; buyable.value = []; return; }
  const [c, b] = await Promise.all([api.chances(props.market.key, 7), api.shopBuyable(props.market.key)]);
  ch.value = c;
  buyable.value = b;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

// Was steht gerade im Auktionshaus und lohnt sich? Je Gegenstand der bessere Weg
const openChances = computed(() => {
  if (!ch.value) return [];
  const best = new Map();
  for (const [kind, list] of [['Wiederverkauf', ch.value.resale.list], ['Händler', ch.value.vendor.list]]) {
    for (const x of list) {
      if (!x.now || typeof x.now !== 'object' || x.doubt || !(x.now.profit > 0)) continue;
      const old = best.get(x.key);
      if (!old || x.now.profit > old.profit) best.set(x.key, { key: x.key, name: x.name, quality: x.quality, profit: x.now.profit, qty: x.now.qty, kind });
    }
  }
  return [...best.values()].sort((a, b) => b.profit - a.profit);
});
const chanceSum = computed(() => openChances.value.reduce((s, x) => s + x.profit, 0));
const sold = computed(() => (ch.value ? [...ch.value.worth].sort((a, b) => b.perDay - a.perDay).slice(0, 5) : []));
</script>

<template>
  <Checklist :data="data" :settings="settings" :stamp="stamp" @go="emit('go', $event)" @save="emit('save', $event)" />

  <div v-if="!market" class="empty">
    <h1>Noch keine Momentaufnahmen</h1>
    <p class="muted">Mach im Spiel einen Komplettscan und klicke danach unter dem Scan-Knopf auf „An Manager“. Das Spiel speichert die Daten beim Neuladen, der Manager liest sie dann von selbst ein.</p>
    <p class="muted" v-if="!data.wowOk">Peon_Bridge wurde im WoW-Ordner nicht gefunden: {{ data.wowDir }}. Den Ordner stellst du unter <button class="link" @click="emit('go', 'settings')">Einstellungen</button> ein.</p>
  </div>

  <div v-else class="ov">
    <button class="statusline small" :class="status.state" @click="emit('go', 'sources')" title="Zu den Quellen">
      <span class="lamp" :title="LAMP_TITLE[status.state]"></span><span>{{ status.text }}</span><span class="to">Quellen</span>
    </button>

    <section class="tiles" aria-label="Kennzahlen">
      <div class="tile">
        <span class="small muted">Angebote</span><strong>{{ market.lastScan ? num(market.lastScan.offers) : '–' }}</strong>
        <span class="small muted" v-if="change('offers') != null">{{ pct(change('offers')) }} zu gestern</span>
      </div>
      <div class="tile">
        <span class="small muted">Gegenstände</span><strong>{{ market.lastScan ? num(market.lastScan.items) : '–' }}</strong>
        <span class="small muted" v-if="change('items') != null">{{ pct(change('items')) }} zu gestern</span>
      </div>
      <div class="tile click" tabindex="0" @click="emit('go', 'chances')" @keydown.enter="emit('go', 'chances')">
        <span class="small muted">Offene Chancen</span><strong>{{ ch ? num(openChances.length) : '–' }}</strong>
        <span class="small muted" v-if="openChances.length">zusammen <Gold :copper="chanceSum" compact /> Gewinn</span>
      </div>
    </section>

    <section class="block" v-if="buyable.length" aria-label="Einkaufsliste">
      <div class="block-head">
        <h2>Jetzt kaufbar</h2>
        <button class="link small" @click="emit('go', 'shopping')">Zur Einkaufsliste</button>
      </div>
      <table class="tbl">
        <tbody>
          <tr v-for="r in buyable.slice(0, 5)" :key="r.key" class="click" tabindex="0" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">
            <td class="name" :style="{ color: qualityColor(r.quality) }" :title="r.name || r.key">{{ r.name || r.key }}</td>
            <td class="muted small kind">{{ r.list }}, {{ pl(r.hits, 'Stück', 'Stück') }}</td>
            <td class="num win"><Gold :copper="r.cheapest" compact /></td>
            <td class="num muted">bis <Gold :copper="r.limit" compact /></td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block">
      <div class="block-head">
        <h2>{{ chartTitle }}</h2>
        <span class="small muted" v-if="market.lastScan">{{ market.lastScan.art === 'api' ? 'Letzter Stand der Blizzard-API' : 'Letzter Scan' }} {{ when(market.lastScan.t) }}<template v-if="market.lastScan.char">, von {{ market.lastScan.char }}</template></span>
      </div>
      <MarketChart v-if="hist.length > 1" :history="hist" :theme="theme" />
      <p v-else class="muted chart-empty">Ab dem zweiten Stand steht hier, wie sich Angebote und Gegenstände entwickeln.</p>
    </section>

    <section class="cols">
      <div class="block">
        <h2>Beste Chancen jetzt</h2>
        <p v-if="!openChances.length" class="muted small">Gerade steht nichts im Auktionshaus, das sich sicher lohnt. Chancen brauchen übliche Preise, die gibt es ab 3 Tagen mit Daten.</p>
        <table v-else class="tbl">
          <tbody>
            <tr v-for="r in openChances.slice(0, 5)" :key="r.key" class="click" tabindex="0" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">
              <td class="name" :style="{ color: qualityColor(r.quality) }" :title="r.name || r.key">{{ r.name || r.key }}</td>
              <td class="muted small kind">{{ r.kind }}, {{ pl(r.qty, 'Stück', 'Stück') }}</td>
              <td class="num win"><Gold :copper="r.profit" compact /></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="block">
        <h2>Meistverkauft</h2>
        <p v-if="!sold.length" class="muted small">Sobald der Absatz sicher genug gemessen ist, steht hier, was sich am besten verkauft.</p>
        <table v-else class="tbl">
          <tbody>
            <tr v-for="r in sold" :key="r.key" class="click" tabindex="0" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">
              <td class="name" :style="{ color: qualityColor(r.quality) }" :title="r.name || r.key">{{ r.name || r.key }}</td>
              <td class="num">{{ num(Math.round(r.perDay)) }} je Tag</td>
              <td class="num muted"><Gold :copper="r.avgPrice ?? r.lang" compact /></td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section class="block moves" v-if="market.moves">
      <div class="block-head">
        <h2>Größte Preisänderungen</h2>
        <span class="small muted" v-if="market.moves.base && market.moves.mode === 'band'">Median im letzten Stand gegenüber dem üblichen Preis, nur Gegenstände ab 1 Silber und 3 Stück</span>
        <span class="small muted" v-else-if="market.moves.base">Noch wenig Daten: Median im letzten Stand gegenüber {{ when(market.moves.base) }}. Einzelne Angebote können stark ausschlagen.</span>
      </div>
      <p v-if="!market.moves.base" class="muted">Sobald es einen zweiten Stand gibt, siehst du hier, was am stärksten gestiegen und gefallen ist.</p>
      <div v-else class="cols">
        <div v-for="side in ['up', 'down']" :key="side">
          <h3 class="side-title">{{ side === 'up' ? 'Gestiegen' : 'Gefallen' }}</h3>
          <p v-if="!market.moves[side].length" class="muted small">Nichts mit nennenswerter Änderung.</p>
          <table v-else class="tbl">
            <tbody>
              <tr v-for="r in market.moves[side]" :key="r.key" class="click" tabindex="0" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">
                <td class="name" :style="{ color: qualityColor(r.quality) }" :title="r.name || r.key">{{ r.name || r.key }}</td>
                <td class="num muted"><Gold :copper="r.before" compact /></td>
                <td class="num"><Gold :copper="r.now" compact /></td>
                <td class="num pct" :class="side">{{ pct(r.pct) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.empty { max-width: 640px; display: grid; gap: 14px; padding-top: 40px; }
.ov { display: grid; gap: 28px; max-width: 1180px; }
.statusline { display: flex; align-items: center; gap: 10px; width: 100%; text-align: left; padding: 8px 12px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.statusline.bad { border-color: var(--bad); }
.statusline.alt { border-color: var(--warn); }
.statusline .to { margin-left: auto; color: var(--accent); }
.lamp { width: 10px; height: 10px; border-radius: 50%; background: var(--faint); flex: none; }
.ok .lamp { background: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
.alt .lamp { background: var(--warn); }
.bad .lamp { background: var(--bad); }
.tiles { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.tile { display: grid; gap: 2px; padding: 12px 16px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); align-content: start; }
.tile strong { font-size: 24px; font-weight: 500; font-family: var(--font-cond); }
.tile.click { cursor: pointer; }
.tile.click:hover { border-color: var(--line); }
.block { display: grid; grid-template-columns: minmax(0, 1fr); gap: 12px; align-content: start; }
.block-head { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }
.chart-empty { padding: 26px 0; }
.cols { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 36px; }
.cols > div { min-width: 0; }
.side-title { color: var(--muted); margin-bottom: 6px; }
.tbl { width: 100%; border-collapse: collapse; table-layout: fixed; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); }
.tbl td.name { padding-left: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tbl td.num { width: 100px; }
.tbl td.kind { width: 150px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.num { text-align: right; white-space: nowrap; }
.win { color: var(--up); }
.click { cursor: pointer; }
.click:hover td, .click:focus-visible td { background: var(--raised); }
.pct { font-weight: 600; padding-right: 0 !important; }
.pct.up { color: var(--up); }
.pct.down { color: var(--down); }
@media (max-width: 1100px) {
  .cols { grid-template-columns: minmax(0, 1fr); }
}
</style>
