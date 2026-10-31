<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Sales from '../components/Sales.vue';
import { ago, num, pct, fold, qualityColor, itemName } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number });
const emit = defineEmits(['open']);
const api = window.peon;

const list = ref(null);
const search = ref('');
const quality = ref('all');
const onlyLast = ref(false);
const kind = ref('all');
const sortKey = ref('auctions');
const sortDesc = ref(true);
const scroller = ref(null);
const scrollTop = ref(0);
const ROW = 36;
const height = ref(600);

async function load() {
  if (!props.market) return;
  list.value = await api.items(props.market.key);
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

const COLS = [
  { key: 'name', label: 'Gegenstand' },
  { key: 'min', label: 'Min', num: true },
  { key: 'median', label: 'Median', num: true },
  { key: 'qty', label: 'Menge', num: true },
  { key: 'auctions', label: 'Angebote', num: true },
  { key: 'avg7', label: 'Ø 7 Tage', num: true },
  { key: 'sales', label: 'Absatz', num: true, tip: 'Absatz je Tag (14 Tage), Zeichen = Sicherheit' },
  { key: 'band', label: 'Üblicher Bereich', num: true, tip: 'Untergrenze bis Obergrenze, wie Broker ihn vom Manager bekommt' },
  { key: 'trend', label: 'Trend', num: true },
  { key: 'seen', label: 'Gesehen', num: true },
  { key: 'src', label: 'Quellen', tip: 'S = eigene Komplettscans, L = Live-Abfragen, B = Broker-Verlauf' },
];

const rows = computed(() => {
  if (!list.value) return [];
  const q = fold(search.value.trim());
  let r = list.value.items;
  if (q) r = r.filter((x) => fold(itemName(x)).includes(q) || String(x.item) === q);
  if (quality.value !== 'all') r = r.filter((x) => (x.quality ?? -1) >= Number(quality.value));
  if (onlyLast.value) r = r.filter((x) => x.inLast);
  if (kind.value === 'mass') r = r.filter((x) => x.commodity === 1);
  else if (kind.value === 'single') r = r.filter((x) => x.commodity === 0);
  const k = sortKey.value, dir = sortDesc.value ? -1 : 1;
  const val = (x) => (k === 'name' ? fold(itemName(x)) : k === 'sales' ? (x.sales ? x.sales.perDay : null) : k === 'band' ? (x.band ? x.band.lang : null) : k === 'src' ? srcKey(x.sources) : (k === 'qty' || k === 'auctions') && !x.inLast ? null : x[k]);
  return [...r].sort((a, b) => {
    const va = val(a), vb = val(b);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;          // leere Werte immer unten
    if (vb == null) return -1;
    return va < vb ? -dir : va > vb ? dir : 0;
  });
});

function sortBy(k) {
  if (sortKey.value === k) sortDesc.value = !sortDesc.value;
  else { sortKey.value = k; sortDesc.value = k !== 'name'; }
}

// Nur sichtbare Zeilen zeichnen (mehrere Tausend Gegenstaende)
const visible = computed(() => {
  const start = Math.max(0, Math.floor(scrollTop.value / ROW) - 10);
  const count = Math.ceil(height.value / ROW) + 20;
  return { start, items: rows.value.slice(start, start + count) };
});
function onScroll(e) { scrollTop.value = e.target.scrollTop; }
onMounted(() => {
  const ro = new ResizeObserver(() => { if (scroller.value) height.value = scroller.value.clientHeight; });
  if (scroller.value) ro.observe(scroller.value);
});
watch([search, quality, onlyLast, kind], () => { if (scroller.value) scroller.value.scrollTop = 0; scrollTop.value = 0; });

function srcLetters(s) { return (s.scan ? 'S' : '') + (s.live ? 'L' : '') + (s.broker ? 'B' : ''); }
function srcKey(s) { return (s.scan ? 4 : 0) + (s.live ? 2 : 0) + (s.broker ? 1 : 0); }
function sourceText(s) {
  const parts = [];
  if (s.scan) parts.push(s.scan === 1 ? '1 Scan' : `${num(s.scan)} Scans`);
  if (s.live) parts.push(`${num(s.live)} live`);
  if (s.broker) parts.push(`${num(s.broker)} Broker-Tage`);
  return parts.join(', ');
}
</script>

<template>
  <div class="items" v-if="market">
    <div class="head">
      <h1>Gegenstände</h1>
      <span class="muted" v-if="list">{{ num(rows.length) }} von {{ num(list.items.length) }}</span>
    </div>
    <div class="filters">
      <input type="text" v-model="search" placeholder="Name oder Nummer suchen" aria-label="Suchen" spellcheck="false" />
      <select v-model="quality" aria-label="Qualität">
        <option value="all">Alle Qualitäten</option>
        <option value="1">Ab Gewöhnlich</option>
        <option value="2">Ab Selten</option>
        <option value="3">Ab Rar</option>
        <option value="4">Ab Episch</option>
      </select>
      <select v-model="kind" aria-label="Warenart">
        <option value="all">Alle Warenarten</option>
        <option value="mass">Massenware</option>
        <option value="single">Einzelgegenstände</option>
      </select>
      <label class="check"><input type="checkbox" v-model="onlyLast" /> Nur im letzten Scan</label>
      <span class="small muted hint">Klick auf eine Spaltenüberschrift sortiert, nochmal klicken dreht um.</span>
    </div>

    <div class="table" role="table" aria-label="Gegenstände">
      <div class="tr th" role="row">
        <button v-for="c in COLS" :key="c.key" class="cell" :class="{ num: c.num, on: sortKey === c.key }" role="columnheader" @click="sortBy(c.key)" :title="c.tip || ''">
          {{ c.label }}<span v-if="sortKey === c.key" class="dir">{{ sortDesc ? '▾' : '▴' }}</span>
        </button>
      </div>
      <div class="body" ref="scroller" @scroll="onScroll">
        <div :style="{ height: rows.length * ROW + 'px', position: 'relative' }">
          <div v-for="(it, k) in visible.items" :key="it.key" class="tr" role="row" tabindex="0"
            :style="{ top: (visible.start + k) * ROW + 'px' }" :class="{ gone: !it.inLast }"
            @click="emit('open', it.key)" @keydown.enter="emit('open', it.key)">
            <span class="cell name" :style="{ color: qualityColor(it.quality) }" :title="sourceText(it.sources)">{{ itemName(it) }}</span>
            <span class="cell num"><Gold :copper="it.min" compact /></span>
            <span class="cell num"><Gold :copper="it.median" compact /></span>
            <span class="cell num">{{ it.inLast ? num(it.qty) : 'weg' }}</span>
            <span class="cell num">{{ it.inLast ? num(it.auctions) : '' }}</span>
            <span class="cell num muted"><Gold :copper="it.avg7" compact /></span>
            <span class="cell num"><Sales :s="it.sales" /></span>
            <span class="cell num small muted"><template v-if="it.band"><Gold :copper="it.band.low" compact /> – <Gold :copper="it.band.high" compact /></template><span v-else class="faint">–</span></span>
            <span class="cell num" :class="it.trend > 0.05 ? 'up' : it.trend < -0.05 ? 'down' : 'muted'">{{ pct(it.trend) }}</span>
            <span class="cell num muted small">{{ it.seen ? ago(it.seen, now) : '' }}</span>
            <span class="cell muted small src" :title="sourceText(it.sources)">{{ srcLetters(it.sources) }}</span>
          </div>
        </div>
        <p v-if="list && !rows.length" class="muted empty">Nichts gefunden. Suche nach einem Teil des Namens oder der Nummer.</p>
      </div>
    </div>
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.items { display: flex; flex-direction: column; gap: 14px; height: 100%; max-width: 1180px; }
.head { display: flex; align-items: baseline; gap: 14px; }
.filters { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.filters input[type="text"] { width: 300px; }
.check { display: flex; gap: 8px; align-items: center; }
.hint { margin-left: auto; }
.src { letter-spacing: 0.08em; }
.table { display: flex; flex-direction: column; flex: 1; min-height: 300px; border-top: 1px solid var(--line); }
.tr { display: grid; grid-template-columns: minmax(0, 2fr) repeat(3, minmax(72px, 1fr)) 100px minmax(76px, 1fr) 80px minmax(130px, 1.5fr) 66px 92px 74px; align-items: center; height: 36px; }
.th { border-bottom: 1px solid var(--line); }
.th .cell { background: none; border: none; border-radius: 0; color: var(--muted); font-weight: 500; text-align: left; padding: 0 10px; height: 100%; }
.th .cell.num { text-align: right; }
.th .cell.on { color: var(--text); }
.th .cell:hover { color: var(--text); }
.dir { margin-left: 4px; }
.body { flex: 1; overflow: auto; position: relative; }
.body .tr { position: absolute; left: 0; right: 0; border-bottom: 1px solid var(--line-soft); cursor: pointer; }
.body .tr:hover, .body .tr:focus-visible { background: var(--raised); }
.body .tr.gone .cell { opacity: 0.6; }
.cell { padding: 0 10px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cell.num { text-align: right; }
.up { color: var(--up); }
.down { color: var(--down); }
.empty { padding: 24px 10px; }
</style>
