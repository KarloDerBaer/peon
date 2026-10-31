<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Sales from '../components/Sales.vue';
import Spark from '../components/Spark.vue';
import { num, pct, fold, qualityColor, itemName, when, pl, slotText } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number, settings: Object });
const emit = defineEmits(['open', 'save']);
const api = window.peon;

const TABS = [
  { key: 'resale', label: 'Wiederverkauf' },
  { key: 'vendor', label: 'Händler' },
  { key: 'down', label: 'Fallend' },
  { key: 'up', label: 'Steigend' },
  { key: 'worth', label: 'Lohnend' },
];
const tab = ref('resale');
const d = ref(null);
const loading = ref(false);
const days = ref(props.settings.chances?.days || 7);
const minSilver = ref(Math.round((props.settings.chances?.minProfit ?? 1000) / 100));
const quality = ref(String(props.settings.chances?.quality ?? 0));
const search = ref('');
const sortKey = ref(null);
const sortDesc = ref(true);
const limit = ref(50);

async function load() {
  if (!props.market) return;
  loading.value = true;
  try { d.value = await api.chances(props.market.key, days.value); } finally { loading.value = false; }
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp, days.value], load);
watch([days, minSilver, quality], () => {
  emit('save', { chances: { days: Number(days.value), minProfit: Math.max(0, Number(minSilver.value) || 0) * 100, quality: Number(quality.value) } });
});
watch(tab, () => { sortKey.value = null; sortDesc.value = true; limit.value = 50; });
watch([search, quality, minSilver, days], () => { limit.value = 50; });

const COLS = {
  resale: [
    { key: 'name', label: 'Gegenstand', w: 3 },
    { key: 'buy', label: 'Einkauf Ø', num: true, gold: true },
    { key: 'sell', label: 'Verkauf zu', num: true, gold: true, tip: 'Untergrenze des üblichen Bereichs, wie Broker bei Dumping' },
    { key: 'perPiece', label: 'Gewinn/Stück', num: true, gold: true, tip: 'Gewinn je Stück nach 5 % Gebühr' },
    { key: 'perScan', label: 'Stück/Scan', num: true },
    { key: 'share', label: 'Treffer', num: true, tip: 'Anteil der Scans mit solchen Angeboten' },
    { key: 'sales', label: 'Absatz/Tag', num: true },
    { key: 'perDay', label: 'Gewinn/Tag', num: true, gold: true, tip: 'Stück je Scan, höchstens Absatz je Tag, mal Gewinn je Stück' },
    { key: 'nowQty', label: 'Jetzt', num: true, tip: 'Stück im letzten Scan' },
    { key: 'slot', label: 'Meist', num: true, tip: 'Tageszeit mit den meisten Treffern' },
  ],
  vendor: [
    { key: 'name', label: 'Gegenstand', w: 3 },
    { key: 'buy', label: 'Einkauf Ø', num: true, gold: true },
    { key: 'sell', label: 'Händler', num: true, gold: true },
    { key: 'perPiece', label: 'Gewinn/Stück', num: true, gold: true, tip: 'Gewinn je Stück' },
    { key: 'perScan', label: 'Stück/Scan', num: true },
    { key: 'share', label: 'Treffer', num: true, tip: 'Anteil der Scans mit solchen Angeboten' },
    { key: 'perDay', label: 'Gewinn/Tag', num: true, gold: true, tip: 'Stück je Scan mal Gewinn je Stück' },
    { key: 'nowQty', label: 'Jetzt', num: true, tip: 'Stück im letzten Scan' },
    { key: 'slot', label: 'Meist', num: true, tip: 'Tageszeit mit den meisten Treffern' },
  ],
  move: [
    { key: 'name', label: 'Gegenstand', w: 3 },
    { key: 'now', label: 'Median jetzt', num: true, gold: true },
    { key: 'lang', label: 'Langzeitwert', num: true, gold: true },
    { key: 'change', label: 'Änderung', num: true },
    { key: 'low', label: 'Bereich', num: true, w: 2 },
    { key: 'spark', label: '14 Tage', num: true, nosort: true },
    { key: 'min', label: 'Min jetzt', num: true, gold: true, w: 1.4 },
    { key: 'qty', label: 'Menge', num: true },
  ],
  worth: [
    { key: 'name', label: 'Gegenstand', w: 3 },
    { key: 'sales', label: 'Absatz/Tag', num: true },
    { key: 'rate', label: 'Verkauft', num: true, tip: 'Anteil der beendeten Angebote, die gekauft wurden' },
    { key: 'lang', label: 'Langzeitwert', num: true, gold: true },
    { key: 'low', label: 'Bereich', num: true, w: 2 },
    { key: 'turnover', label: 'Umsatz/Tag', num: true, gold: true, tip: 'Absatz je Tag mal Langzeitwert' },
    { key: 'spanDay', label: 'Spanne/Tag', num: true, gold: true, tip: 'Absatz je Tag mal (Obergrenze nach Gebühr minus Untergrenze)' },
  ],
};
const cols = computed(() => COLS[tab.value === 'up' || tab.value === 'down' ? 'move' : tab.value]);
const widthSum = computed(() => cols.value.reduce((a, c) => a + (c.w || 1), 0));

const raw = computed(() => {
  if (!d.value) return [];
  if (tab.value === 'resale') return d.value.resale.list;
  if (tab.value === 'vendor') return d.value.vendor.list;
  return d.value[tab.value] || [];
});

function sortVal(x, k) {
  if (k === 'name') return fold(itemName(x));
  if (k === 'sales') return x.sales ? x.sales.perDay : x.perDay ?? null;
  if (k === 'nowQty') return x.now && typeof x.now === 'object' ? x.now.qty : null;
  if (k === 'perDay' && tab.value === 'worth') return x.perDay;
  return x[k];
}

const rows = computed(() => {
  const q = fold(search.value.trim());
  const minP = Math.max(0, Number(minSilver.value) || 0) * 100;
  let r = raw.value;
  if (q) r = r.filter((x) => fold(itemName(x)).includes(q) || String(x.item) === q);
  if (Number(quality.value) > 0) r = r.filter((x) => (x.quality ?? -1) >= Number(quality.value));
  if (tab.value === 'resale' || tab.value === 'vendor') r = r.filter((x) => (x.perDay ?? x.rough) >= minP);
  if (tab.value === 'worth') r = r.filter((x) => x.spanDay >= minP);
  if (sortKey.value) {
    const k = sortKey.value, dir = sortDesc.value ? -1 : 1;
    r = [...r].sort((a, b) => {
      const va = sortVal(a, k), vb = sortVal(b, k);
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      return va < vb ? -dir : va > vb ? dir : 0;
    });
  }
  return r;
});
const shown = computed(() => rows.value.slice(0, limit.value));
const total = computed(() => raw.value.length);

function sortBy(c) {
  if (c.nosort) return;
  if (sortKey.value === c.key) sortDesc.value = !sortDesc.value;
  else { sortKey.value = c.key; sortDesc.value = c.key !== 'name'; }
}

const intro = computed(() => ({
  resale: 'Angebote, die so tief unter dem üblichen Bereich liegen, dass sich Kaufen und zur Untergrenze wieder Einstellen lohnt (mindestens 20 % Gewinn nach Gebühr). Der Gewinn je Tag ist durch den Absatz begrenzt. „Zweifelhaft“: in 14 Tagen wurde nie nahe der Untergrenze verkauft.',
  vendor: 'Angebote unter dem Händlerpreis: kaufen und beim Händler verkaufen. Keine Gebühr, kein Risiko.',
  down: 'Median im letzten Scan mindestens 15 % unter dem Langzeitwert und unter dem üblichen Bereich. Rotes ▼ bei Min jetzt: Dumping, das günstigste Angebot liegt mehr als 30 % unter dem Langzeitwert.',
  up: 'Median im letzten Scan mindestens 15 % über dem Langzeitwert und über dem üblichen Bereich.',
  worth: 'Gegenstände mit sicherem Absatz (mindestens 1 Std. beobachtet), sortiert nach dem, was zwischen Unter- und Obergrenze am Tag zu holen ist.',
}[tab.value]));

const emptyText = computed(() => {
  if (!d.value) return '';
  const t = tab.value;
  if ((t === 'resale' || t === 'up' || t === 'down') && !d.value.bands) return 'Dafür braucht es den üblichen Bereich, also Daten an mindestens 3 Tagen.';
  if (t === 'vendor' && !d.value.vendorKnown) return 'Händlerpreise kommen über Peon_Bridge aus dem Spiel, mit dem nächsten Komplettscan.';
  if (t === 'worth' && !d.value.sure) return 'Dafür braucht es Absatz, also Komplettscans höchstens 24 Std. auseinander, zusammen mindestens 1 Std. beobachtet.';
  if (total.value && !rows.value.length) return 'Nichts über dem Mindestgewinn. Setz ihn tiefer oder wähle einen längeren Zeitraum.';
  return 'Im Moment nichts.';
});

function counts(k) {
  if (!d.value) return '';
  const n = k === 'resale' ? d.value.resale.list.length : k === 'vendor' ? d.value.vendor.list.length : (d.value[k] || []).length;
  return n ? num(n) : '';
}
</script>

<template>
  <div class="ch" v-if="market">
    <div class="head">
      <h1>Chancen</h1>
      <span class="small muted" v-if="d">{{ pl(d.resale.scans, 'Scan', 'Scans') }} in {{ pl(d.days, 'Tag', 'Tagen') }}, üblicher Bereich für {{ num(d.bands) }}, Absatz für {{ num(d.salesItems) }} Gegenstände<template v-if="d.lastScan">, letzter Scan {{ when(d.lastScan) }}</template></span>
    </div>

    <div class="tabs" role="tablist">
      <button v-for="t in TABS" :key="t.key" role="tab" :aria-selected="tab === t.key" :class="{ on: tab === t.key }" @click="tab = t.key">
        {{ t.label }}<span class="cnt" v-if="counts(t.key)">{{ counts(t.key) }}</span>
      </button>
    </div>

    <div class="filters">
      <input type="text" v-model="search" placeholder="Name oder Nummer suchen" aria-label="Suchen" spellcheck="false" />
      <label v-if="tab === 'resale' || tab === 'vendor'">Zeitraum
        <select v-model.number="days" aria-label="Zeitraum">
          <option :value="1">1 Tag</option><option :value="3">3 Tage</option><option :value="7">7 Tage</option><option :value="14">14 Tage</option>
        </select>
      </label>
      <label v-if="tab !== 'up' && tab !== 'down'">Gewinn ab <input class="short" type="number" min="0" step="1" v-model.number="minSilver" aria-label="Mindestgewinn je Tag in Silber" /> Silber/Tag</label>
      <select v-model="quality" aria-label="Qualität">
        <option value="0">Alle Qualitäten</option>
        <option value="1">Ab Gewöhnlich</option>
        <option value="2">Ab Selten</option>
        <option value="3">Ab Rar</option>
        <option value="4">Ab Episch</option>
      </select>
      <span class="small faint" v-if="loading">rechnet</span>
    </div>
    <p class="small muted intro">{{ intro }}</p>

    <table class="tbl" v-if="rows.length">
      <colgroup><col v-for="c in cols" :key="c.key" :style="{ width: ((c.w || 1) / widthSum * 100) + '%' }" /></colgroup>
      <thead>
        <tr>
          <th v-for="c in cols" :key="c.key" :class="{ num: c.num, on: sortKey === c.key, nosort: c.nosort }" :title="c.tip || ''" @click="sortBy(c)">
            {{ c.label }}<span v-if="sortKey === c.key" class="dir">{{ sortDesc ? '▾' : '▴' }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in shown" :key="r.key" class="click" tabindex="0" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">
          <td class="name" :style="{ color: qualityColor(r.quality) }" :title="itemName(r)">{{ itemName(r) }}</td>
          <template v-if="tab === 'resale' || tab === 'vendor'">
            <td class="num"><Gold :copper="r.buy" compact /></td>
            <td class="num"><Gold :copper="r.sell" compact /></td>
            <td class="num"><Gold :copper="r.perPiece" compact /></td>
            <td class="num">{{ r.perScan >= 10 ? num(Math.round(r.perScan)) : r.perScan.toLocaleString('de-DE', { maximumFractionDigits: 1 }) }}</td>
            <td class="num muted">{{ Math.round(r.share * 100) }} %</td>
            <td class="num" v-if="tab === 'resale'"><Sales :s="r.sales" /></td>
            <td class="num strong"><Gold v-if="r.perDay != null" :copper="r.perDay" compact /><span v-else-if="r.doubt" class="faint" title="In 14 Tagen nie nahe der Untergrenze verkauft">zweifelhaft</span><span v-else class="faint" title="Absatz noch unbekannt">?</span></td>
            <td class="num">{{ r.now ? num(r.now.qty) : '' }}</td>
            <td class="num muted small">{{ slotText(r.slot) }}</td>
          </template>
          <template v-else-if="tab === 'up' || tab === 'down'">
            <td class="num"><Gold :copper="r.now" compact /></td>
            <td class="num muted"><Gold :copper="r.lang" compact /></td>
            <td class="num pct" :class="tab">{{ pct(r.change) }}</td>
            <td class="num muted small"><Gold :copper="r.low" compact /> – <Gold :copper="r.high" compact /></td>
            <td class="num spark"><Spark :values="r.spark" :low="r.low" :high="r.high" /></td>
            <td class="num"><Gold :copper="r.min" compact /><span v-if="r.dump && tab === 'down'" class="dump" title="Dumping: günstigstes Angebot mehr als 30 % unter dem Langzeitwert">▼</span></td>
            <td class="num">{{ num(r.qty) }}</td>
          </template>
          <template v-else>
            <td class="num"><Sales :s="r" /></td>
            <td class="num muted">{{ r.rate == null ? '–' : Math.round(r.rate * 100) + ' %' }}</td>
            <td class="num"><Gold :copper="r.lang" compact /></td>
            <td class="num muted small"><Gold :copper="r.low" compact /> – <Gold :copper="r.high" compact /></td>
            <td class="num"><Gold :copper="r.turnover" compact /></td>
            <td class="num strong"><Gold :copper="r.spanDay" compact /></td>
          </template>
        </tr>
      </tbody>
    </table>
    <p v-else-if="d" class="muted empty">{{ emptyText }}</p>
    <p v-if="rows.length > shown.length" class="more small muted">{{ num(shown.length) }} von {{ num(rows.length) }} <button class="link" @click="limit += 50">50 weitere zeigen</button></p>
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.ch { display: grid; gap: 14px; max-width: 1180px; align-content: start; }
.head { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 8px 14px; color: var(--muted); font-weight: 500; margin-bottom: -1px; }
.tabs button:hover { color: var(--text); }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.cnt { margin-left: 8px; font-size: 12px; color: var(--faint); font-weight: 400; }
.filters { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }
.filters input[type="text"] { width: 260px; }
.filters label { display: flex; gap: 8px; align-items: center; color: var(--muted); }
.short { width: 70px; }
.intro { max-width: 90ch; }
.tbl { width: 100%; border-collapse: collapse; table-layout: fixed; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); cursor: pointer; line-height: 1.25; vertical-align: bottom; }
.tbl th.nosort { cursor: default; }
.tbl th.on, .tbl th:hover:not(.nosort) { color: var(--text); }
.tbl th:first-child { padding-left: 0; }
.tbl td { padding: 7px 8px; border-bottom: 1px solid var(--line-soft); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tbl td.name { padding-left: 0; }
.num { text-align: right !important; }
.dir { margin-left: 4px; }
.click { cursor: pointer; }
.click:hover td, .click:focus-visible td { background: var(--raised); }
.strong { font-weight: 600; }
.pct { font-weight: 600; }
.pct.up { color: var(--up); }
.pct.down { color: var(--down); }
.spark :deep(svg) { margin-left: auto; }
.dump { margin-left: 6px; font-size: 11px; color: var(--bad); }
.empty { padding: 18px 0; }
.more { display: flex; gap: 12px; align-items: baseline; }
</style>
