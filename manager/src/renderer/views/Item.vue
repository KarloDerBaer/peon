<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import ItemChart from '../components/ItemChart.vue';
import LevelsChart from '../components/LevelsChart.vue';
import Sales from '../components/Sales.vue';
import { ago, when, num, qualityColor, itemName, pl } from '../util.js';

const props = defineProps({ market: Object, itemKey: String, now: Number, theme: String, stamp: Number, backLabel: { type: String, default: 'Alle Gegenstände' } });
const emit = defineEmits(['back']);
const api = window.peon;
const range = ref('30d');
const d = ref(null);
const RANGES = [['1d', '24 Std.'], ['7d', '7 Tage'], ['30d', '30 Tage'], ['90d', '90 Tage'], ['all', 'Alles']];
const DAYS = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const SLOTS = ['0-3', '3-6', '6-9', '9-12', '12-15', '15-18', '18-21', '21-24'];

async function load() {
  if (!props.market || !props.itemKey) return;
  d.value = await api.item(props.market.key, props.itemKey, range.value);
}
onMounted(load);
watch(() => [props.itemKey, props.stamp, range.value], load);

const hasHistory = computed(() => d.value && (d.value.own.length + d.value.hours.length + d.value.days.length + d.value.broker.length) > 0);
const datalage = computed(() => {
  if (!d.value) return '';
  const c = d.value.counts, p = [];
  if (c.scan) p.push(pl(c.scan, 'Scan', 'Scans'));
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
const LT_SRC = { e: 'eigenen Scans', b: 'dem Broker-Verlauf', eb: 'eigenen Scans und dem Broker-Verlauf' };
const lt = computed(() => {
  const l = d.value && d.value.longterm;
  if (!l) return null;
  return { ...l, low: Math.floor(l.lang * (1 - l.schw)), high: Math.floor(l.lang * (1 + l.schw)), pct: Math.round(l.schw * 100), from: LT_SRC[l.src] || 'Tageswerten' };
});
function hoursText(min) {
  if (min < 60) return `${Math.round(min)} Min.`;
  const h = min / 60;
  return `${h < 10 ? h.toLocaleString('de-DE', { maximumFractionDigits: 1 }) : Math.round(h)} Std.`;
}
const levelsTop = computed(() => (d.value && d.value.levels ? d.value.levels.list.slice(0, 10) : []));
</script>

<template>
  <div class="item" v-if="d">
    <button class="link back" @click="emit('back')">{{ backLabel }}</button>
    <div class="title">
      <h1 :style="{ color: qualityColor(d.quality) }">{{ itemName(d) }}</h1>
      <p class="muted small">Nummer {{ d.item }}<template v-if="d.variant">, Gegenstand mit Zusatz (eigener Preis je Variante)</template><template v-else-if="d.commodity === 1">, Massenware</template><template v-else-if="d.commodity === 0">, Einzelgegenstand</template><template v-if="d.vendor">, Händler <Gold :copper="d.vendor" /></template></p>
    </div>

    <dl class="facts">
      <div><dt>Min jetzt</dt><dd><Gold :copper="d.current && d.current.min" /></dd></div>
      <div><dt>Median jetzt</dt><dd><Gold :copper="d.current && d.current.median" /></dd></div>
      <div><dt>Menge</dt><dd>{{ d.current ? (d.current.qty ? num(d.current.qty) : 'keine Angebote') : '–' }}</dd></div>
      <div><dt>Angebote</dt><dd>{{ d.current && d.current.qty ? num(d.current.auctions) : '–' }}</dd></div>
      <div><dt>Ø 7 Tage</dt><dd><Gold :copper="d.median7" /><span class="faint small" v-if="d.days7"> aus {{ pl(d.days7, 'Tag', 'Tagen') }}</span></dd></div>
      <div><dt>Spanne 14 Tage</dt><dd v-if="d.low14 != null"><Gold :copper="d.low14" /> bis <Gold :copper="d.high14" /></dd><dd v-else>–</dd></div>
    </dl>
    <p class="small muted" v-if="d.current">
      Stand {{ when(d.current.t) }} ({{ ago(d.current.t, now) }}) aus {{ d.current.source === 'live' ? 'einer Live-Abfrage' : d.current.art === 'api' ? 'der Blizzard-API' : 'dem letzten Komplettscan' }}.
      Die Spanne ist der tiefste und höchste Tagesmedian.
    </p>

    <section class="lt" aria-label="Werte für Broker">
      <h2>Werte für Broker</h2>
      <p v-if="lt">
        Langzeitwert <Gold :copper="lt.lang" />, Bereich <Gold :copper="lt.low" /> bis <Gold :copper="lt.high" /> (Schwankung {{ lt.pct }} %).
        <span class="muted">Aus {{ pl(lt.days, 'Tag', 'Tagen') }} mit {{ lt.from }}, Mitte <Gold :copper="lt.mitte" compact />. Broker rechnet den heutigen Tag und den aktuellen Preis selbst dazu.</span>
      </p>
      <p v-else class="muted">Üblicher Bereich: noch zu wenig Tage. Ab 3 Tagen mit Daten in den letzten 14 Tagen bekommt Broker hier einen Bereich, bis dahin rechnet Broker selbst.</p>
      <p v-if="d.sales">
        Absatz <Sales :s="d.sales" /> Stück am Tag<template v-if="d.sales.rate != null">, {{ Math.round(d.sales.rate * 100) }} % der beendeten Angebote verkauft</template>.
        <span class="muted">Beobachtet {{ hoursText(d.sales.minutes) }} in {{ pl(d.sales.cmp, 'Vergleich', 'Vergleichen') }} (14 Tage), dabei {{ num(Math.round(d.sales.sold)) }} verkauft, {{ num(Math.round(d.sales.expired)) }} abgelaufen, {{ num(Math.round(d.sales.cancelled)) }} abgebrochen<template v-if="d.sales.avgPrice">, im Mittel zu <Gold :copper="d.sales.avgPrice" compact /></template>. Broker nimmt ihn, wenn er selbst in den letzten 6 Std. weniger als 1 Std. beobachtet hat.</span>
      </p>
      <p v-else class="muted">Absatz: noch kein Vergleich. Dafür braucht es zwei Komplettscans höchstens 24 Std. auseinander.</p>
    </section>

    <section class="block">
      <div class="block-head">
        <h2>Verlauf</h2>
        <div class="seg" role="group" aria-label="Zeitraum">
          <button v-for="r in RANGES" :key="r[0]" :class="{ on: range === r[0] }" @click="range = r[0]">{{ r[1] }}</button>
        </div>
      </div>
      <ItemChart v-if="hasHistory" :detail="d" :theme="theme" />
      <p v-else class="muted empty">In diesem Zeitraum gibt es keine Daten. Wähle einen längeren Zeitraum.</p>
      <p class="small muted">{{ datalage }} Broker-Werte sind Mittel aller Scans eines Tages und gelten nur für Tage ohne eigenen Scan. Der übliche Bereich zeigt je Tag den Stand, den Broker an diesem Tag bekommen hätte. Absatz je Tag aus den Vergleichen der Scans.</p>
    </section>

    <div class="cols">
      <section class="block">
        <h2>Wann ist es günstig?</h2>
        <template v-if="d.pattern && d.pattern.scans >= 10">
          <p class="small muted">Median gegenüber dem Mittel aller Scans der letzten 60 Tage, nach Wochentag und Uhrzeit ({{ pl(d.pattern.scans, 'Scan', 'Scans') }}). Grün ist teurer, Rot günstiger.</p>
          <table class="heat">
            <thead><tr><th></th><th v-for="s in SLOTS" :key="s" class="small faint">{{ s }}</th></tr></thead>
            <tbody>
              <tr v-for="(row, i) in d.pattern.cells" :key="i">
                <th class="small muted">{{ DAYS[i] }}</th>
                <td v-for="(c, j) in row" :key="j" :style="cellStyle(c)" :title="c ? `${pl(c.n, 'Scan', 'Scans')}` : 'kein Scan'">{{ relText(c) }}</td>
              </tr>
            </tbody>
          </table>
        </template>
        <p v-else class="muted">Ab 10 Scans zu verschiedenen Zeiten zeigt sich hier, an welchen Tagen und Uhrzeiten der Preis meist tiefer oder höher liegt. Bisher {{ d.pattern ? pl(d.pattern.scans, 'Scan', 'Scans') : 'kein Scan' }}.</p>
      </section>

      <section class="block">
        <h2>Angebot im letzten Scan</h2>
        <template v-if="d.levels && d.levels.list.length">
          <p class="small muted">Wie viele Stück es bis zu welchem Preis gibt, Stand {{ when(d.levels.t) }}.</p>
          <LevelsChart :levels="d.levels" :theme="theme" />
          <table class="tbl">
            <thead><tr><th class="num">Preis je Stück</th><th class="num">Stück</th><th class="num">Angebote</th><th class="num">Summe Stück</th></tr></thead>
            <tbody>
              <tr v-for="l in levelsTop" :key="l.price">
                <td class="num"><Gold :copper="l.price" /></td><td class="num">{{ num(l.qty) }}</td><td class="num">{{ num(l.auctions) }}</td><td class="num muted">{{ num(l.cum) }}</td>
              </tr>
            </tbody>
          </table>
          <p class="small faint" v-if="d.levels.list.length > 10">und {{ pl(d.levels.list.length - 10, 'weitere Preisstufe', 'weitere Preisstufen') }}</p>
        </template>
        <p v-else class="muted">Für diesen Gegenstand liegt kein vollständiger Scan mit Angeboten vor.</p>
      </section>
    </div>
  </div>
  <p v-else class="muted">Lade Gegenstand</p>
</template>

<style scoped>
.item { display: grid; gap: 20px; max-width: 1180px; }
.back { justify-self: start; }
.title { display: grid; gap: 2px; }
.facts { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 0; margin: 0; border-top: 1px solid var(--line-soft); border-bottom: 1px solid var(--line-soft); }
.facts > div { padding: 12px 14px 12px 0; }
.facts > div + div { padding-left: 14px; border-left: 1px solid var(--line-soft); }
dt { color: var(--muted); font-size: 13px; margin-bottom: 4px; }
dd { margin: 0; font-size: 17px; font-weight: 500; }
.block { display: grid; grid-template-columns: minmax(0, 1fr); gap: 10px; align-content: start; }
.lt { display: grid; gap: 6px; padding: 12px 16px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.lt h2 { font-size: 15px; }
.block-head { display: flex; justify-content: space-between; align-items: center; gap: 16px; }
.seg { display: flex; border: 1px solid var(--line); border-radius: var(--radius-s); overflow: hidden; }
.seg button { border: none; border-radius: 0; background: none; color: var(--muted); padding: 5px 12px; }
.seg button + button { border-left: 1px solid var(--line); }
.seg button.on { background: var(--accent-soft); color: var(--text); }
.empty { padding: 40px 0; }
.cols { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 36px; }
.cols > .block { min-width: 0; }
.heat { border-collapse: separate; border-spacing: 3px; width: 100%; }
.heat td { height: 30px; text-align: center; font-size: 12px; border-radius: 3px; background: var(--panel); color: var(--text); }
.heat th { font-weight: 500; text-align: center; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { color: var(--muted); font-weight: 500; padding: 4px 8px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 5px 8px; border-bottom: 1px solid var(--line-soft); }
.num { text-align: right; }
@media (max-width: 1100px) { .cols { grid-template-columns: 1fr; } .facts { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
</style>
