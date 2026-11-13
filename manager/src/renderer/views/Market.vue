<script setup>
// Marktuebersicht (ab Manager 0.35.0, Peon_Manager_Chancen.md Abschnitt 8): alles Beschreibende. Fallend, Steigend und
// Lohnend kommen aus der frueheren Seite Radar, neu sind Prognosen, groesste Preisaenderungen, Stufenbereiche und Feste.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Sales from '../components/Sales.vue';
import Spark from '../components/Spark.vue';
import { num, pct, fold, qualityColor, itemName, when } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number });
const emit = defineEmits(['open', 'brief']);
const TABS = [
  { key: 'forecasts', label: 'Prognosen' },
  { key: 'down', label: 'Fallend' },
  { key: 'up', label: 'Steigend' },
  { key: 'worth', label: 'Lohnend' },
  { key: 'biggest', label: 'Größte Änderungen' },
  { key: 'index', label: 'Stufenbereiche' },
  { key: 'fests', label: 'Feste' },
];
const tab = ref('forecasts');
const d = ref(null);
const search = ref('');
const limit = ref(60);
async function load() { if (props.market) d.value = await window.peon.marketOverview(props.market.key); }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
watch([tab, search], () => { limit.value = 60; });
const SURE = { low: 'niedrig', mid: 'mittel', high: 'hoch' };
const list = computed(() => {
  if (!d.value || !Array.isArray(d.value[tab.value])) return [];
  const q = fold(search.value.trim());
  return q ? d.value[tab.value].filter((x) => fold(itemName(x)).includes(q)) : d.value[tab.value];
});
const intro = computed(() => ({
  forecasts: 'Richtung, Zeitraum und Sicherheit je Gegenstand, mit den Signalen, aus denen die Prognose entsteht. Jede Prognose wird nach ihrem Zeitraum nachgeprüft.',
  down: 'Median im letzten Stand mindestens 15 % unter dem Langzeitwert und unter dem üblichen Bereich. Rotes ▼: Dumping, das günstigste Angebot liegt mehr als 30 % unter dem Langzeitwert.',
  up: 'Median im letzten Stand mindestens 15 % über dem Langzeitwert und über dem üblichen Bereich.',
  worth: 'Gegenstände mit sicherem Absatz, sortiert nach dem, was zwischen Unter- und Obergrenze am Tag zu holen ist.',
  biggest: 'Fallend und Steigend zusammen, nach der Größe der Änderung.',
  index: 'Je 10 Stufen nach benötigter Stufe, getrennt nach Ausrüstung und Sonstigem: neu eingestellt (steht für Drops) und verkauft, diese Woche gegen die Woche davor. Fällt das Eingestellte um mindestens 25 % und das Verkaufte weniger, wird der Bereich knapper.',
  fests: 'Feste aus dem Kalender im Spiel und eigene Ereignisse. Betroffen ist, was beim letzten gleichen Fest um mindestens 20 % stieg oder fiel.',
}[tab.value]));
</script>

<template>
  <div class="mk" v-if="market">
    <div class="head"><h1>Marktübersicht</h1><span class="small muted" v-if="d && d.t">Stand {{ when(d.t) }}</span></div>
    <div class="tabs" role="tablist">
      <button v-for="t in TABS" :key="t.key" role="tab" :aria-selected="tab === t.key" :class="{ on: tab === t.key }" @click="tab = t.key">{{ t.label }}</button>
    </div>
    <div class="filters" v-if="!['index', 'fests'].includes(tab)"><input type="text" v-model="search" placeholder="Name suchen" aria-label="Suchen" spellcheck="false" /></div>
    <p class="small muted intro">{{ intro }}</p>

    <template v-if="d && tab === 'forecasts'">
      <p class="small">
        <span v-for="s in d.signals" :key="s.id" class="sig">{{ s.label }}: <template v-if="s.on === false">aus</template><template v-else-if="s.n < 20">neu ({{ s.n }} geprüft)</template><template v-else>{{ Math.round(s.rate * 100) }} % Treffer</template></span>
      </p>
      <table class="tbl" v-if="list.length">
        <thead><tr><th>Gegenstand</th><th class="num">Aussicht</th><th class="num">Zeitraum</th><th class="num">Erwartet</th><th class="num">Sicherheit</th><th>Signale</th></tr></thead>
        <tbody>
          <tr v-for="x in list.slice(0, limit)" :key="x.key" class="click" @click="emit('brief', x.key)">
            <td class="name" :style="{ color: qualityColor(x.quality) }">{{ itemName(x) }}</td>
            <td class="num" :class="x.dir > 0 ? 'up' : 'down'">{{ x.dir > 0 ? '▲ steigt' : '▼ fällt' }}</td>
            <td class="num">{{ x.days }} Tage</td>
            <td class="num">{{ Math.round(x.expect * 100) }} %</td>
            <td class="num">{{ SURE[x.sure] }}</td>
            <td class="small muted">{{ x.signals.map((s) => s.label + (s.isNew ? ' (neu)' : '')).join(', ') }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else class="muted">Gerade keine Prognosen. Sie brauchen Absatz und Mengen über mehrere Tage.</p>
    </template>

    <template v-else-if="d && (tab === 'up' || tab === 'down' || tab === 'biggest')">
      <table class="tbl" v-if="list.length">
        <thead><tr><th>Gegenstand</th><th class="num">Median jetzt</th><th class="num">Langzeitwert</th><th class="num">Änderung</th><th class="num">Bereich</th><th class="num">14 Tage</th><th class="num">Min jetzt</th><th class="num">Menge</th></tr></thead>
        <tbody>
          <tr v-for="r in list.slice(0, limit)" :key="r.key" class="click" @click="emit('brief', r.key)">
            <td class="name" :style="{ color: qualityColor(r.quality) }">{{ itemName(r) }}</td>
            <td class="num"><Gold :copper="r.now" compact /></td>
            <td class="num muted"><Gold :copper="r.lang" compact /></td>
            <td class="num strong" :class="r.change > 0 ? 'up' : 'down'">{{ pct(r.change) }}</td>
            <td class="num muted small"><Gold :copper="r.low" compact /> – <Gold :copper="r.high" compact /></td>
            <td class="num spark"><Spark :values="r.spark" :low="r.low" :high="r.high" /></td>
            <td class="num"><Gold :copper="r.min" compact /><span v-if="r.dump && r.change < 0" class="dump" title="Dumping">▼</span></td>
            <td class="num">{{ num(r.qty) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else class="muted">Gerade nichts. Dafür braucht es den üblichen Bereich, also Daten an mindestens 3 Tagen.</p>
    </template>

    <template v-else-if="d && tab === 'worth'">
      <table class="tbl" v-if="list.length">
        <thead><tr><th>Gegenstand</th><th class="num">Absatz/Tag</th><th class="num">Verkauft</th><th class="num">Langzeitwert</th><th class="num">Bereich</th><th class="num">Umsatz/Tag</th><th class="num">Spanne/Tag</th></tr></thead>
        <tbody>
          <tr v-for="r in list.slice(0, limit)" :key="r.key" class="click" @click="emit('brief', r.key)">
            <td class="name" :style="{ color: qualityColor(r.quality) }">{{ itemName(r) }}</td>
            <td class="num"><Sales :s="r" /></td>
            <td class="num muted">{{ r.rate == null ? '–' : Math.round(r.rate * 100) + ' %' }}</td>
            <td class="num"><Gold :copper="r.lang" compact /></td>
            <td class="num muted small"><Gold :copper="r.low" compact /> – <Gold :copper="r.high" compact /></td>
            <td class="num"><Gold :copper="r.turnover" compact /></td>
            <td class="num strong"><Gold :copper="r.spanDay" compact /></td>
          </tr>
        </tbody>
      </table>
      <p v-else class="muted">Dafür braucht es Absatz, also Stände höchstens 24 Std. auseinander.</p>
    </template>

    <template v-else-if="d && tab === 'index'">
      <p v-if="!d.index.length" class="muted">Noch keine Stufen bekannt ({{ num(d.levelsKnown) }} Gegenstände geholt). Der Manager holt sie im Hintergrund von der Blizzard-API, etwa 6000 je Stunde.</p>
      <div v-for="x in d.index" :key="x.id" class="lvl" :class="{ sig: x.signal }">
        <div class="lh">
          <strong>Stufe {{ x.from }} bis {{ x.to }}, {{ x.equip ? 'Ausrüstung' : 'Sonstiges' }}</strong>
          <span class="small muted">{{ num(x.items) }} Gegenstände</span>
          <span class="small">eingestellt <b :class="x.listedChange < 0 ? 'down' : 'up'">{{ x.listedChange == null ? '–' : pct(x.listedChange) }}</b></span>
          <span class="small">verkauft <b :class="x.soldChange < 0 ? 'down' : 'up'">{{ x.soldChange == null ? '–' : pct(x.soldChange) }}</b></span>
          <span class="small" v-if="x.price != null">Preis {{ Math.round(x.price * 100) }} % des Üblichen</span>
          <span v-if="x.signal" class="badge">wird knapper</span>
        </div>
        <div class="rank small" v-if="x.rank.length">Droppt oft und verkauft sich trotzdem:
          <button v-for="r in x.rank" :key="r.key" class="link" :style="{ color: qualityColor(r.quality) }" @click="emit('brief', r.key)">{{ itemName(r) }} ({{ Math.round(r.rate * 100) }} %)</button>
        </div>
      </div>
    </template>

    <template v-else-if="d && tab === 'fests'">
      <p v-if="!d.fests.length" class="muted">Keine Feste bekannt. Broker liest sie beim Anmelden aus dem Kalender im Spiel. Eigene Ereignisse lassen sich unter Chancen, Einstellen eintragen.</p>
      <div v-for="f in d.fests" :key="f.n + f.s" class="lvl">
        <div class="lh"><strong>{{ f.n }}</strong><span class="small muted">{{ new Date(f.s * 1000).toLocaleDateString('de-DE') }}<template v-if="f.e && f.e !== f.s"> bis {{ new Date(f.e * 1000).toLocaleDateString('de-DE') }}</template></span></div>
        <div class="rank small" v-if="f.items.length">
          <button v-for="r in f.items" :key="r.key" class="link" :style="{ color: qualityColor(r.quality) }" @click="emit('brief', r.key)">{{ itemName(r) }} ({{ pct(r.change) }})</button>
        </div>
        <div class="small muted" v-else>Kein früheres gleiches Fest in den Daten oder keine deutliche Änderung.</div>
      </div>
    </template>

    <p v-if="list.length > limit" class="small muted">{{ num(limit) }} von {{ num(list.length) }} <button class="link" @click="limit += 60">60 weitere zeigen</button></p>
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.mk { display: grid; gap: 14px; max-width: 1180px; align-content: start; }
.head { display: flex; align-items: baseline; gap: 16px; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); flex-wrap: wrap; }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 8px 14px; color: var(--muted); font-weight: 500; margin-bottom: -1px; }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.filters input { width: 260px; }
.intro { max-width: 100ch; margin: 0; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 7px 8px; border-bottom: 1px solid var(--line-soft); white-space: nowrap; }
.tbl th:first-child, .tbl td:first-child { padding-left: 0; }
.num { text-align: right !important; }
.click { cursor: pointer; }
.click:hover td { background: var(--raised); }
.strong { font-weight: 600; }
.up { color: var(--up); }
.down { color: var(--bad); }
.spark :deep(svg) { margin-left: auto; }
.dump { margin-left: 6px; font-size: 11px; color: var(--bad); }
.sig { margin-right: 16px; }
.lvl { border: 1px solid var(--line-soft); border-radius: var(--radius-m); padding: 10px 14px; display: grid; gap: 6px; }
.lvl.sig { border-color: var(--accent); }
.lh { display: flex; gap: 16px; align-items: baseline; flex-wrap: wrap; }
.badge { font-size: 12px; padding: 1px 8px; border-radius: 8px; background: var(--accent); color: var(--accent-ink); }
.rank { display: flex; gap: 10px; flex-wrap: wrap; align-items: baseline; }
</style>
