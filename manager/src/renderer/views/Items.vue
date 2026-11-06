<script setup>
// Gegenstaende und, mit favorites, die Favoriten: dieselbe Liste, nur auf die Favoriten eingegrenzt
import { ref, computed, watch, onMounted, onActivated, onBeforeUnmount, nextTick } from 'vue';
import Gold from '../components/Gold.vue';
import Sales from '../components/Sales.vue';
import ItemTip from '../components/ItemTip.vue';
import Star from '../components/Star.vue';
import { ago, num, pct, fold, qualityColor, itemName } from '../util.js';
import { favorites as favs } from '../store.js';

const props = defineProps({ market: Object, now: Number, stamp: Number, settings: Object, favorites: Boolean });
const emit = defineEmits(['open', 'save', 'go']);
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
const showCols = ref(false);
const colsEl = ref(null);

async function load() {
  if (!props.market) return;
  const r = await api.items(props.market.key);
  // einmal vorbereiten statt bei jedem Tastendruck und jedem Vergleich
  for (const x of r.items) {
    x.folded = fold(itemName(x));
    x.vs = x.inLast && x.min != null && x.band && x.band.lang > 0 ? x.min / x.band.lang - 1 : null;
  }
  list.value = r;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
// Beim Zurueckkommen steht die Liste wieder dort, wo sie war
onActivated(() => { nextTick(() => { if (scroller.value) scroller.value.scrollTop = scrollTop.value; }); });

const COLS = [
  { key: 'min', label: 'Min', num: true, w: 'minmax(72px, 1fr)' },
  { key: 'median', label: 'Median', num: true, w: 'minmax(72px, 1fr)' },
  { key: 'vs', label: 'Zu üblich', num: true, w: '80px', tip: 'Günstigstes Angebot gegenüber dem üblichen Preis' },
  { key: 'qty', label: 'Menge', num: true, w: 'minmax(60px, 1fr)' },
  { key: 'auctions', label: 'Angebote', num: true, w: '108px' },
  { key: 'avg7', label: 'Ø 7 Tage', num: true, w: 'minmax(76px, 1fr)' },
  { key: 'sales', label: 'Absatz', num: true, w: '76px', tip: 'Absatz je Tag (14 Tage), Zeichen = Sicherheit' },
  { key: 'band', label: 'Üblicher Bereich', num: true, w: 'minmax(130px, 1.5fr)', tip: 'Untergrenze bis Obergrenze, wie Broker ihn vom Manager bekommt' },
  { key: 'trend', label: 'Trend', num: true, w: '66px' },
  { key: 'seen', label: 'Gesehen', num: true, w: '92px' },
  { key: 'src', label: 'Quellen', w: '74px', tip: 'S = Komplettscans und Blizzard-API, L = Live-Abfragen, B = Broker-Verlauf' },
];
const DEFAULT_COLS = ['min', 'median', 'vs', 'qty', 'auctions', 'avg7', 'sales', 'band', 'trend'];
const chosen = computed(() => {
  const c = props.settings && props.settings.itemColumns;
  return new Set(c && c.length ? c : DEFAULT_COLS);
});
const cols = computed(() => COLS.filter((c) => chosen.value.has(c.key)));
const gridStyle = computed(() => ({ gridTemplateColumns: `34px minmax(0, 2fr) ${cols.value.map((c) => c.w).join(' ')}` }));
function toggleCol(key) {
  const next = new Set(chosen.value);
  if (next.has(key)) { if (next.size > 1) next.delete(key); } else next.add(key);
  emit('save', { itemColumns: COLS.map((c) => c.key).filter((k) => next.has(k)) });
}
function outside(e) { if (showCols.value && colsEl.value && !colsEl.value.contains(e.target)) showCols.value = false; }
onMounted(() => document.addEventListener('mousedown', outside));
onBeforeUnmount(() => document.removeEventListener('mousedown', outside));

const base = computed(() => {
  if (!list.value) return [];
  return props.favorites ? list.value.items.filter((x) => favs.value.has(x.key)) : list.value.items;
});
const rows = computed(() => {
  const q = fold(search.value.trim());
  let r = base.value;
  if (q) r = r.filter((x) => x.folded.includes(q) || String(x.item) === q);
  if (quality.value !== 'all') r = r.filter((x) => (x.quality ?? -1) >= Number(quality.value));
  if (onlyLast.value) r = r.filter((x) => x.inLast);
  if (kind.value === 'mass') r = r.filter((x) => x.commodity === 1);
  else if (kind.value === 'single') r = r.filter((x) => x.commodity === 0);
  const k = sortKey.value, dir = sortDesc.value ? -1 : 1;
  const val = (x) => (k === 'name' ? x.folded : k === 'sales' ? (x.sales ? x.sales.perDay : null) : k === 'band' ? (x.band ? x.band.lang : null) : k === 'src' ? srcKey(x.sources) : (k === 'qty' || k === 'auctions') && !x.inLast ? null : x[k]);
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
function onScroll(e) { scrollTop.value = e.target.scrollTop; rowLeave(); }
onMounted(() => {
  const ro = new ResizeObserver(() => { if (scroller.value) height.value = scroller.value.clientHeight; });
  if (scroller.value) ro.observe(scroller.value);
});
watch([search, quality, onlyLast, kind], () => { if (scroller.value) scroller.value.scrollTop = 0; scrollTop.value = 0; });

// Tooltip beim Ueberfahren einer Zeile, leicht verzoegert, damit Vorbeifahren keine Abfrage ausloest
const HOVER_MS = 250, TIP_W = 340, GAP = 18;
const hover = ref(null);
const tipEl = ref(null);
const tipPos = ref({ left: '0px', top: '0px', visibility: 'hidden' });
let hoverTimer = null, mouse = { x: 0, y: 0 };
function placeTip() {
  const h = tipEl.value ? tipEl.value.offsetHeight : 0;
  const left = mouse.x + GAP + TIP_W > window.innerWidth ? Math.max(8, mouse.x - GAP - TIP_W) : mouse.x + GAP;
  const top = Math.max(8, Math.min(mouse.y + 8, window.innerHeight - h - 8));
  tipPos.value = { left: `${left}px`, top: `${top}px`, visibility: 'visible' };
}
let hoverSeq = 0;   // spaete Antworten fuer eine schon verlassene Zeile verwerfen
async function showTip(it) {
  const seq = ++hoverSeq;
  hover.value = { it, info: null };
  await nextTick(); placeTip();
  const info = await api.itemInfo(it.key);
  if (seq !== hoverSeq) return;
  hover.value = { it, info };
  await nextTick(); placeTip();
}
function rowEnter(it, e) {
  clearTimeout(hoverTimer);
  hoverSeq++;
  hover.value = null;
  mouse = { x: e.clientX, y: e.clientY };
  hoverTimer = setTimeout(() => showTip(it), HOVER_MS);
}
function rowMove(e) {
  mouse = { x: e.clientX, y: e.clientY };
  if (hover.value) placeTip();
}
function rowLeave() { clearTimeout(hoverTimer); hoverSeq++; hover.value = null; }
onBeforeUnmount(() => clearTimeout(hoverTimer));

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
      <h1>{{ favorites ? 'Favoriten' : 'Gegenstände' }}</h1>
      <span class="muted" v-if="list">{{ num(rows.length) }} von {{ num(base.length) }}</span>
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
      <label class="check"><input type="checkbox" v-model="onlyLast" /> Nur im letzten Stand</label>
      <div class="colmenu" ref="colsEl">
        <button :aria-expanded="showCols" @click="showCols = !showCols">Spalten</button>
        <div class="menu" v-if="showCols">
          <label v-for="c in COLS" :key="c.key" class="check small"><input type="checkbox" :checked="chosen.has(c.key)" @change="toggleCol(c.key)" /> {{ c.label }}</label>
        </div>
      </div>
    </div>

    <div class="table" role="table" :aria-label="favorites ? 'Favoriten' : 'Gegenstände'">
      <div class="tr th" role="row" :style="gridStyle">
        <span class="cell" aria-hidden="true"></span>
        <button class="cell" :class="{ on: sortKey === 'name' }" role="columnheader" @click="sortBy('name')">Gegenstand<span v-if="sortKey === 'name'" class="dir">{{ sortDesc ? '▾' : '▴' }}</span></button>
        <button v-for="c in cols" :key="c.key" class="cell" :class="{ num: c.num, on: sortKey === c.key }" role="columnheader" @click="sortBy(c.key)" :title="c.tip || ''">
          {{ c.label }}<span v-if="sortKey === c.key" class="dir">{{ sortDesc ? '▾' : '▴' }}</span>
        </button>
      </div>
      <div class="body" ref="scroller" @scroll="onScroll">
        <div :style="{ height: rows.length * ROW + 'px', position: 'relative' }">
          <div v-for="(it, k) in visible.items" :key="it.key" class="tr" role="row" tabindex="0"
            :style="{ top: (visible.start + k) * ROW + 'px', ...gridStyle }" :class="{ gone: !it.inLast }"
            @click="emit('open', it.key)" @keydown.enter="emit('open', it.key)"
            @mouseenter="rowEnter(it, $event)" @mousemove="rowMove" @mouseleave="rowLeave">
            <span class="cell starcell"><Star :item-key="it.key" :size="15" /></span>
            <span class="cell name" :style="{ color: qualityColor(it.quality) }">{{ itemName(it) }}</span>
            <template v-for="c in cols" :key="c.key">
              <span v-if="c.key === 'min'" class="cell num"><Gold :copper="it.min" compact /></span>
              <span v-else-if="c.key === 'median'" class="cell num"><Gold :copper="it.median" compact /></span>
              <span v-else-if="c.key === 'vs'" class="cell num" :class="it.vs < -0.05 ? 'up' : it.vs > 0.05 ? 'down' : 'muted'">{{ pct(it.vs) }}</span>
              <span v-else-if="c.key === 'qty'" class="cell num">{{ it.inLast ? num(it.qty) : 'weg' }}</span>
              <span v-else-if="c.key === 'auctions'" class="cell num">{{ it.inLast ? num(it.auctions) : '' }}</span>
              <span v-else-if="c.key === 'avg7'" class="cell num muted"><Gold :copper="it.avg7" compact /></span>
              <span v-else-if="c.key === 'sales'" class="cell num"><Sales :s="it.sales" /></span>
              <span v-else-if="c.key === 'band'" class="cell num small muted"><template v-if="it.band"><Gold :copper="it.band.low" compact /> – <Gold :copper="it.band.high" compact /></template><span v-else class="faint">–</span></span>
              <span v-else-if="c.key === 'trend'" class="cell num" :class="it.trend > 0.05 ? 'up' : it.trend < -0.05 ? 'down' : 'muted'">{{ pct(it.trend) }}</span>
              <span v-else-if="c.key === 'seen'" class="cell num muted small">{{ it.seen ? ago(it.seen, now) : '' }}</span>
              <span v-else-if="c.key === 'src'" class="cell muted small src" :title="sourceText(it.sources)">{{ srcLetters(it.sources) }}</span>
            </template>
          </div>
        </div>
        <p v-if="list && !base.length && favorites" class="muted empty">Noch keine Favoriten. Klicke unter <button class="link" @click="emit('go', 'items')">Gegenstände</button> oder im Gegenstandsfenster auf den Stern.</p>
        <p v-else-if="list && !rows.length" class="muted empty">Nichts gefunden. Suche nach einem Teil des Namens oder der Nummer.</p>
      </div>
    </div>
    <div v-if="hover" ref="tipEl" class="hovertip" :style="tipPos">
      <ItemTip :info="hover.info" :name="itemName(hover.it)" :quality="hover.it.quality" :variant="String(hover.it.key).includes(':')" />
    </div>
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.items { display: flex; flex-direction: column; gap: 14px; height: 100%; }
.head { display: flex; align-items: baseline; gap: 14px; }
.filters { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.filters input[type="text"] { width: 300px; }
.check { display: flex; gap: 8px; align-items: center; white-space: nowrap; }
.colmenu { position: relative; margin-left: auto; }
.menu { position: absolute; right: 0; top: calc(100% + 6px); z-index: 20; display: grid; gap: 6px; padding: 10px 12px; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-m); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); }
.src { letter-spacing: 0.08em; }
.table { display: flex; flex-direction: column; flex: 1; min-height: 300px; border-top: 1px solid var(--line); }
.tr { display: grid; align-items: center; height: 36px; }
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
.starcell { padding: 0 0 0 8px; display: flex; align-items: center; }
.up { color: var(--up); }
.down { color: var(--down); }
.empty { padding: 24px 10px; }
.hovertip { position: fixed; z-index: 50; width: 340px; pointer-events: none; box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); border-radius: var(--radius-m); }
</style>
