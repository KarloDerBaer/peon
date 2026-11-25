<script setup>
// Kennzahlen des Markts (ab 0.56.0 Reiter Uebersicht in Markt, Peon_Manager_Schlank.md Abschnitt 4): Kacheln, Diagramm,
// Stabilitaet, Meistverkauft und groesste Preisaenderungen aus der frueheren Startseite. Einrichtung, Jetzt kaufbar und
// beste Chancen stehen jetzt auf Heute.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import MarketChart from '../components/MarketChart.vue';
import StabilityChart from '../components/StabilityChart.vue';
import { when, num, pct, qualityColor, pl } from '../util.js';

const props = defineProps({ market: Object, now: Number, theme: String, stamp: Number });
const emit = defineEmits(['go', 'open', 'tab']);
const api = window.peon;

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
// ab 0.35.0: aus der Seite Chancen (alle Arten) und der Marktuebersicht (Lohnend)
const ch = ref(null);
const mk = ref(null);
const stab = ref(null);    // ab 0.46.0: Stabilitaet des Markts und ihr Verlauf
async function load() {
  if (!props.market) { ch.value = null; mk.value = null; stab.value = null; return; }
  const [c, m, s] = await Promise.all([api.chanceView(props.market.key), api.marketOverview(props.market.key), api.stabilitySummary(props.market.key)]);
  ch.value = c;
  mk.value = m;
  stab.value = s;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

// Was steht gerade im Auktionshaus und lohnt sich? Je Gegenstand der bessere Weg
const openChances = computed(() => {
  if (!ch.value) return [];
  const best = new Map();
  for (const x of ch.value.list) {
    if (!(x.gain > 0)) continue;
    const old = best.get(x.key);
    if (!old || x.gain > old.profit) best.set(x.key, { key: x.key, name: x.name, quality: x.quality, profit: x.gain, qty: x.qty, kind: x.kindLabel });
  }
  return [...best.values()].sort((a, b) => b.profit - a.profit);
});
const chanceSum = computed(() => openChances.value.reduce((s, x) => s + x.profit, 0));
const LEVELS = ['sehr stabil', 'stabil', 'mittel', 'unruhig', 'unsicher'];
const stabAll = computed(() => (stab.value && stab.value.groups && stab.value.groups.all) || null);
const stabHist = computed(() => (stab.value && stab.value.hist) || []);
// Aenderung des Index zu einer Rechnung etwa einen Tag vorher
const stabChange = computed(() => {
  const h = stabHist.value;
  if (h.length < 2 || !h[h.length - 1].all) return null;
  const last = h[h.length - 1];
  let base = null;
  for (const x of h) if (x.t <= last.t - 20 * 3600 && x.all) base = x;
  return base ? last.all.i - base.all.i : null;
});
const stabTitle = computed(() => {
  const h = stabHist.value;
  const days = h.length > 1 ? Math.round((h[h.length - 1].t - h[0].t) / 86400) : 0;
  return days >= 2 ? `Stabilität der Preise in den letzten ${days} Tagen` : 'Stabilität der Preise';
});
const sold = computed(() => (mk.value ? [...mk.value.worth].sort((a, b) => b.perDay - a.perDay).slice(0, 5) : []));
</script>

<template>
  <div v-if="!market" class="empty">
    <h1>Noch keine Momentaufnahmen</h1>
    <p class="muted">Mach im Spiel einen Komplettscan und klicke danach unter dem Scan-Knopf auf „An Manager“. Das Spiel speichert die Daten beim Neuladen, der Manager liest sie dann von selbst ein.</p>
  </div>

  <div v-else class="ov">
    <section class="tiles" aria-label="Kennzahlen">
      <div class="tile">
        <span class="small muted">Angebote</span><strong>{{ market.lastScan ? num(market.lastScan.offers) : '–' }}</strong>
        <span class="small muted" v-if="change('offers') != null">{{ pct(change('offers')) }} zu gestern</span>
      </div>
      <div class="tile">
        <span class="small muted">Gegenstände</span><strong>{{ market.lastScan ? num(market.lastScan.items) : '–' }}</strong>
        <span class="small muted" v-if="change('items') != null">{{ pct(change('items')) }} zu gestern</span>
      </div>
      <div class="tile click" tabindex="0" title="Zu Chancen, Spekulation" @click="emit('go', 'chances')" @keydown.enter="emit('go', 'chances')">
        <span class="small muted">Offene Chancen</span><strong>{{ ch ? num(openChances.length) : '–' }}</strong>
        <span class="small muted" v-if="openChances.length">zusammen <Gold :copper="chanceSum" compact /> Gewinn</span>
      </div>
      <div class="tile click" tabindex="0" title="Zum Reiter Stabilität" @click="emit('tab', 'stab')" @keydown.enter="emit('tab', 'stab')">
        <span class="small muted">Stabilität des Markts</span>
        <strong v-if="stabAll"><span :class="'lv' + stabAll.g">{{ LEVELS[stabAll.g] }}</span> <span class="idx">{{ stabAll.i }}</span></strong>
        <strong v-else>–</strong>
        <span class="small muted" v-if="stabAll && stabChange != null">{{ stabChange > 0 ? '+' : '' }}{{ stabChange }} Punkte zu gestern</span>
        <span class="small muted" v-else-if="stabAll">Index von 0 bis 100</span>
        <span class="small muted" v-else>Noch keine Rechnung</span>
      </div>
    </section>

    <section class="block">
      <div class="block-head">
        <h2>{{ chartTitle }}</h2>
        <span class="small muted" v-if="market.lastScan">{{ market.lastScan.art === 'api' ? 'Letzter Stand der Blizzard-API' : 'Letzter Scan' }} {{ when(market.lastScan.t) }}<template v-if="market.lastScan.char">, von {{ market.lastScan.char }}</template></span>
      </div>
      <MarketChart v-if="hist.length > 1" :history="hist" :theme="theme" />
      <p v-else class="muted chart-empty">Ab dem zweiten Stand steht hier, wie sich Angebote und Gegenstände entwickeln.</p>
    </section>

    <section class="block" v-if="stabAll" aria-label="Stabilität">
      <div class="block-head">
        <h2>{{ stabTitle }}</h2>
        <span class="small muted">Index je Rechnung nach jedem neuen Stand, 100 heißt sehr ruhig</span>
        <button class="link small" @click="emit('tab', 'stab')">Mehr zur Stabilität</button>
      </div>
      <StabilityChart v-if="stabHist.length > 1" :hist="stabHist" :theme="theme" />
      <p v-else class="muted chart-empty">Ab der zweiten Rechnung steht hier, wie sich die Stabilität entwickelt.</p>
    </section>

    <section class="block">
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
.tiles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
.tile { display: grid; gap: 2px; padding: 12px 16px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); align-content: start; }
.tile strong { font-size: 24px; font-weight: 500; font-family: var(--font-cond); }
.tile.click { cursor: pointer; }
.tile .idx { color: var(--muted); font-size: 18px; margin-left: 4px; }
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
