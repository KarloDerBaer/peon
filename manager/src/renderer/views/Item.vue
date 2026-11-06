<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import ItemChart from '../components/ItemChart.vue';
import LevelsChart from '../components/LevelsChart.vue';
import Sales from '../components/Sales.vue';
import ItemTip from '../components/ItemTip.vue';
import Star from '../components/Star.vue';
import ShopButton from '../components/ShopButton.vue';
import { ago, when, num, perDay, qualityColor, itemName, pl, verdict } from '../util.js';

const props = defineProps({ market: Object, itemKey: String, now: Number, theme: String, stamp: Number });
const emit = defineEmits(['loaded', 'go']);
const api = window.peon;
const range = ref('30d');
const tab = ref('offers');
const d = ref(null);
const RANGES = [['1d', '24 Std.'], ['7d', '7 Tage'], ['30d', '30 Tage'], ['90d', '90 Tage'], ['all', 'Alles']];
const TABS = [['offers', 'Angebote jetzt'], ['pattern', 'Wann günstig?'], ['sales', 'Absatz im Detail'], ['broker', 'Werte für Broker']];
const DAYS = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const SLOTS = ['0-3', '3-6', '6-9', '9-12', '12-15', '15-18', '18-21', '21-24'];

const info = ref(null);
async function load() {
  if (!props.market || !props.itemKey) return;
  const key = props.itemKey;
  const r = await api.item(props.market.key, key, range.value);
  if (props.itemKey !== key) return;
  d.value = r;
  if (r) emit('loaded', r);
}
// Werte des Gegenstands, unabhaengig vom Zeitraum
async function loadInfo() {
  info.value = null;
  const key = props.itemKey;
  if (!key) return;
  const r = await api.itemInfo(key);
  if (props.itemKey === key) info.value = r;
}
onMounted(() => { load(); loadInfo(); });
watch(() => [props.itemKey, props.market && props.market.key, props.stamp, range.value], load);
watch(() => props.itemKey, loadInfo);

const hasHistory = computed(() => d.value && (d.value.own.length + d.value.hours.length + d.value.days.length + d.value.broker.length) > 0);
const datalage = computed(() => {
  if (!d.value) return '';
  const c = d.value.counts, p = [];
  if (c.scan) p.push(pl(c.scan, 'Stand', 'Stände'));
  if (c.live) p.push(pl(c.live, 'Live-Abfrage', 'Live-Abfragen'));
  if (c.hour) p.push(pl(c.hour, 'Stundenwert', 'Stundenwerte'));
  if (c.day) p.push(pl(c.day, 'Tageswert', 'Tageswerte'));
  if (c.broker) p.push(`${pl(c.broker, 'Tag', 'Tage')} aus dem Broker-Verlauf`);
  return p.length ? `Im Zeitraum: ${p.join(', ')}.` : 'Im Zeitraum keine Daten.';
});

// Farbe einer Zelle im Muster: gruen = teurer als ueblich, rot = guenstiger
function cellStyle(c) {
  if (!c) return {};
  const a = Math.min(1, Math.abs(c.rel) / 0.25);
  const col = c.rel >= 0 ? '140, 207, 77' : '226, 99, 79';
  return { background: `rgba(${col}, ${0.12 + a * 0.55})` };
}
function relText(c) {
  if (!c) return '';
  const v = Math.round(c.rel * 100);
  return (v > 0 ? '+' : '') + v + ' %';
}
const LT_SRC = { e: 'eigenen Ständen', b: 'dem Broker-Verlauf', eb: 'eigenen Ständen und dem Broker-Verlauf' };
const lt = computed(() => {
  const l = d.value && d.value.longterm;
  if (!l) return null;
  return { ...l, low: Math.floor(l.lang * (1 - l.schw)), high: Math.floor(l.lang * (1 + l.schw)), pct: Math.round(l.schw * 100), from: LT_SRC[l.src] || 'Tageswerten' };
});
const say = computed(() => verdict(d.value));
function hoursText(min) {
  if (min < 60) return `${Math.round(min)} Min.`;
  const h = min / 60;
  return `${h < 10 ? h.toLocaleString('de-DE', { maximumFractionDigits: 1 }) : Math.round(h)} Std.`;
}
const levelsTop = computed(() => (d.value && d.value.levels ? d.value.levels.list.slice(0, 10) : []));
</script>

<template>
  <div class="item" v-if="d">
    <div class="title">
      <h1 :style="{ color: qualityColor(d.quality) }">{{ itemName(d) }}</h1>
      <Star :item-key="itemKey" :size="24" />
      <div class="actions"><ShopButton :item-key="itemKey" :stamp="stamp" @go="emit('go', $event)" /></div>
    </div>

    <div class="main">
      <aside class="side">
        <ItemTip :info="info" :name="itemName(d)" :quality="d.quality" :variant="!!d.variant" />
        <p class="muted small">Nummer {{ d.item }}<template v-if="d.variant">, Gegenstand mit Zusatz (eigener Preis je Variante)</template><template v-else-if="d.commodity === 1">, Massenware</template><template v-else-if="d.commodity === 0">, Einzelgegenstand</template></p>
      </aside>

      <div class="body">
        <p v-if="say" class="say" :class="say.tone">{{ say.text }}</p>
        <dl class="facts">
          <div><dt>Min jetzt</dt><dd><Gold :copper="d.current && d.current.min" /></dd></div>
          <div><dt>Median jetzt</dt><dd><Gold :copper="d.current && d.current.median" /></dd></div>
          <div><dt>Ø 7 Tage</dt><dd><Gold :copper="d.median7" /><span class="faint small" v-if="d.days7"> aus {{ pl(d.days7, 'Tag', 'Tagen') }}</span></dd></div>
          <div><dt>Absatz je Tag</dt><dd>{{ d.sales ? `${perDay(d.sales.perDay)} Stück` : '–' }}</dd></div>
          <div><dt>Angebote</dt><dd>{{ d.current && d.current.qty ? num(d.current.auctions) : '–' }}<span class="faint small" v-if="d.current && d.current.qty"> mit {{ pl(d.current.qty, 'Stück', 'Stück') }}</span></dd></div>
          <div><dt>Spanne 14 Tage</dt><dd v-if="d.low14 != null"><Gold :copper="d.low14" /> bis <Gold :copper="d.high14" /></dd><dd v-else>–</dd></div>
        </dl>
        <p class="small muted" v-if="d.current">
          Stand {{ when(d.current.t) }} ({{ ago(d.current.t, now) }}) aus {{ d.current.source === 'live' ? 'einer Live-Abfrage' : d.current.art === 'api' ? 'der Blizzard-API' : 'dem letzten Komplettscan' }}.
        </p>
        <p class="small others" v-if="d.others && d.others.length">
          <span class="muted">In anderen Märkten:</span>
          <span v-for="o in d.others" :key="o.market" class="other">{{ o.label }} ab <Gold :copper="o.min" compact /> <span class="muted">({{ pl(o.qty, 'Stück', 'Stück') }})</span></span>
        </p>

        <section class="block">
          <div class="block-head">
            <h2>Verlauf</h2>
            <div class="seg" role="group" aria-label="Zeitraum">
              <button v-for="r in RANGES" :key="r[0]" :class="{ on: range === r[0] }" @click="range = r[0]">{{ r[1] }}</button>
            </div>
          </div>
          <ItemChart v-if="hasHistory" :detail="d" :theme="theme" />
          <p v-else class="muted empty">In diesem Zeitraum gibt es keine Daten. Wähle einen längeren Zeitraum.</p>
          <p class="small muted">{{ datalage }} Der übliche Bereich zeigt je Tag den Stand, den Broker an diesem Tag bekommen hätte.</p>
        </section>
      </div>
    </div>

    <div class="tabs" role="tablist" aria-label="Weitere Angaben">
      <button v-for="t in TABS" :key="t[0]" role="tab" :aria-selected="tab === t[0]" :class="{ on: tab === t[0] }" @click="tab = t[0]">{{ t[1] }}</button>
    </div>

    <section class="block" v-if="tab === 'offers'">
      <template v-if="d.levels && d.levels.list.length">
        <p class="small muted">Wie viele Stück es bis zu welchem Preis gibt, Stand {{ when(d.levels.t) }}.</p>
        <div class="cols">
          <LevelsChart :levels="d.levels" :theme="theme" />
          <div>
            <table class="tbl">
              <thead><tr><th class="num">Preis je Stück</th><th class="num">Stück</th><th class="num">Angebote</th><th class="num">Summe Stück</th></tr></thead>
              <tbody>
                <tr v-for="l in levelsTop" :key="l.price">
                  <td class="num"><Gold :copper="l.price" /></td><td class="num">{{ num(l.qty) }}</td><td class="num">{{ num(l.auctions) }}</td><td class="num muted">{{ num(l.cum) }}</td>
                </tr>
              </tbody>
            </table>
            <p class="small faint" v-if="d.levels.list.length > 10">und {{ pl(d.levels.list.length - 10, 'weitere Preisstufe', 'weitere Preisstufen') }}</p>
          </div>
        </div>
      </template>
      <p v-else class="muted">Für diesen Gegenstand liegt kein vollständiger Stand mit Angeboten vor.</p>
    </section>

    <section class="block" v-else-if="tab === 'pattern'">
      <template v-if="d.pattern && d.pattern.scans >= 10">
        <p class="small muted">Median gegenüber dem Mittel aller Stände der letzten 60 Tage, nach Wochentag und Uhrzeit ({{ pl(d.pattern.scans, 'Stand', 'Stände') }}). Grün ist teurer, Rot günstiger.</p>
        <table class="heat">
          <thead><tr><th></th><th v-for="s in SLOTS" :key="s" class="small faint">{{ s }}</th></tr></thead>
          <tbody>
            <tr v-for="(row, i) in d.pattern.cells" :key="i">
              <th class="small muted">{{ DAYS[i] }}</th>
              <td v-for="(c, j) in row" :key="j" :style="cellStyle(c)" :title="c ? `${pl(c.n, 'Stand', 'Stände')}` : 'kein Stand'">{{ relText(c) }}</td>
            </tr>
          </tbody>
        </table>
      </template>
      <p v-else class="muted">Ab 10 Ständen zu verschiedenen Zeiten zeigt sich hier, an welchen Tagen und Uhrzeiten der Preis meist tiefer oder höher liegt. Bisher {{ d.pattern ? pl(d.pattern.scans, 'Stand', 'Stände') : 'keiner' }}.</p>
    </section>

    <section class="block" v-else-if="tab === 'sales'">
      <p v-if="d.sales">
        Absatz <Sales :s="d.sales" /> Stück am Tag<template v-if="d.sales.rate != null">, {{ Math.round(d.sales.rate * 100) }} % der beendeten Angebote verkauft</template>.
      </p>
      <p class="muted" v-if="d.sales">Beobachtet {{ hoursText(d.sales.minutes) }} in {{ pl(d.sales.cmp, 'Vergleich', 'Vergleichen') }} (14 Tage), dabei {{ num(Math.round(d.sales.sold)) }} verkauft, {{ num(Math.round(d.sales.expired)) }} abgelaufen, {{ num(Math.round(d.sales.cancelled)) }} abgebrochen<template v-if="d.sales.avgPrice">, im Mittel zu <Gold :copper="d.sales.avgPrice" compact /></template>.</p>
      <p v-else class="muted">Absatz: noch kein Vergleich. Dafür braucht es zwei Stände höchstens 24 Std. auseinander.</p>
    </section>

    <section class="block" v-else>
      <p v-if="lt">
        Langzeitwert <Gold :copper="lt.lang" />, Bereich <Gold :copper="lt.low" /> bis <Gold :copper="lt.high" /> (Schwankung {{ lt.pct }} %).
        <span class="muted">Aus {{ pl(lt.days, 'Tag', 'Tagen') }} mit {{ lt.from }}, Mitte <Gold :copper="lt.mitte" compact />. Broker rechnet den heutigen Tag und den aktuellen Preis selbst dazu.</span>
      </p>
      <p v-else class="muted">Üblicher Bereich: noch zu wenig Tage. Ab 3 Tagen mit Daten in den letzten 14 Tagen bekommt Broker hier einen Bereich, bis dahin rechnet Broker selbst.</p>
      <p class="muted" v-if="d.sales">Den Absatz nimmt Broker, wenn er selbst in den letzten 6 Std. weniger als 1 Std. beobachtet hat.</p>
      <p class="small muted">Die Spanne ist der tiefste und höchste Tagesmedian. Broker-Werte sind Mittel aller Scans eines Tages und gelten nur für Tage ohne eigenen Stand.</p>
    </section>
  </div>
  <p v-else class="muted">Lade Gegenstand</p>
</template>

<style scoped>
.item { display: grid; gap: 18px; }
.title { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.actions { margin-left: auto; }
.main { display: grid; grid-template-columns: minmax(280px, 340px) minmax(0, 1fr); gap: 24px; align-items: start; }
.side { display: grid; gap: 8px; }
.body { display: grid; gap: 12px; min-width: 0; }
.say { padding: 8px 12px; border-radius: var(--radius-s); background: var(--panel); border: 1px solid var(--line-soft); }
.say.good { color: var(--up); border-color: var(--up); }
.say.bad { color: var(--down); border-color: var(--down); }
.facts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; margin: 0; }
.facts > div { padding: 8px 12px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-s); }
dt { color: var(--muted); font-size: 13px; margin-bottom: 2px; }
dd { margin: 0; font-size: 16px; font-weight: 500; }
.others { display: flex; gap: 6px 16px; flex-wrap: wrap; }
.block { display: grid; grid-template-columns: minmax(0, 1fr); gap: 10px; align-content: start; }
.block-head { display: flex; justify-content: space-between; align-items: center; gap: 16px; }
.seg { display: flex; border: 1px solid var(--line); border-radius: var(--radius-s); overflow: hidden; }
.seg button { border: none; border-radius: 0; background: none; color: var(--muted); padding: 5px 12px; }
.seg button + button { border-left: 1px solid var(--line); }
.seg button.on { background: var(--accent-soft); color: var(--text); }
.empty { padding: 40px 0; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; color: var(--muted); padding: 8px 14px; }
.tabs button:hover { color: var(--text); }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.cols { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 36px; }
.cols > * { min-width: 0; }
.heat { border-collapse: separate; border-spacing: 3px; width: 100%; max-width: 900px; }
.heat td { height: 30px; text-align: center; font-size: 12px; border-radius: 3px; background: var(--panel); color: var(--text); }
.heat th { font-weight: 500; text-align: center; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { color: var(--muted); font-weight: 500; padding: 4px 8px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 5px 8px; border-bottom: 1px solid var(--line-soft); }
.num { text-align: right; }
@media (max-width: 1100px) { .cols { grid-template-columns: 1fr; } .main { grid-template-columns: minmax(0, 1fr); } }
</style>
