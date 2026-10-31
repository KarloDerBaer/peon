<script setup>
import { computed } from 'vue';
import Gold from '../components/Gold.vue';
import MarketChart from '../components/MarketChart.vue';
import { ago, when, num, pct, bytes, qualityColor, freshness, pl } from '../util.js';

const props = defineProps({ data: Object, market: Object, now: Number, theme: String });
const emit = defineEmits(['import', 'go', 'open']);
const api = window.peon;

const ahl = computed(() => {
  if (!props.market || !props.market.ext) return null;
  return props.data.ahledger.markets.find((x) => x.market === props.market.ext) || { market: props.market.ext };
});

const gameFile = computed(() => {
  const files = props.data.game.files || [];
  if (!files.length) return null;
  return files.reduce((a, b) => (b.mtime > a.mtime ? b : a));
});

// Datenweg Spiel -> Manager -> Broker, AHledger als Zuweg
const stations = computed(() => {
  const m = props.market, d = props.data, now = props.now;
  const last = m && m.lastScan;
  const back = d.back;
  return [
    { key: 'spiel', title: 'Spiel', state: gameFile.value ? freshness(gameFile.value.mtime, 3 * 86400, now) : 'aus',
      fact: gameFile.value ? `${pl(gameFile.value.entries, 'Momentaufnahme', 'Momentaufnahmen')} in der WTF-Datei` : 'Keine Peon_Bridge.lua gefunden',
      time: gameFile.value ? `geschrieben ${ago(gameFile.value.mtime, now)}` : 'Komplettscan im Spiel, dann „An Manager“' },
    { key: 'client', title: 'Manager', state: last ? freshness(last.t, 2 * 86400, now) : 'aus',
      fact: m ? `${pl(m.scans, 'Scan', 'Scans')}, ${pl(m.lives, 'Live-Abfrage', 'Live-Abfragen')}, ${pl(m.items, 'Gegenstand', 'Gegenstände')}` : 'Noch nichts gespeichert',
      time: `Datenbank ${bytes(d.dbSize)}` + (d.brokerHist && d.brokerHist.items ? `, Broker-Verlauf ${pl(d.brokerHist.days, 'Tag', 'Tage')}` : '') },
    { key: 'broker', title: 'Broker', state: back ? freshness(back.t, 2 * 86400, now) : 'aus',
      fact: back ? (back.items || back.sales ? `Üblicher Bereich für ${num(back.items)}, Absatz für ${pl(back.sales || 0, 'Gegenstand', 'Gegenstände')}` : `${pl(back.count, 'Momentaufnahme', 'Momentaufnahmen')} bestätigt`) : 'Noch keine Rückgabe geschrieben',
      time: back ? `Data.lua ${bytes(back.bytes)} ${ago(back.t, now)}, wirkt nach /reload` : 'Ab 3 Tagen mit Daten bekommt Broker Werte' },
  ];
});

const ahlStation = computed(() => {
  const a = ahl.value, now = props.now;
  if (!props.data.ahledger.enabled) return { state: 'aus', fact: 'Abruf ist ausgeschaltet', time: '' };
  if (!a) return { state: 'aus', fact: 'Markt noch nicht zugeordnet', time: 'Zuordnung unter Quellen' };
  if (a.ok === false && !a.tData) return { state: 'bad', fact: a.text || 'Abruf fehlgeschlagen', time: '' };
  return { state: a.tData ? freshness(a.tData, 6 * 3600, now) : 'aus',
    fact: a.tData ? `${num(a.rows)} Gegenstände, nur zum Vergleich` : 'Noch nicht abgerufen',
    time: a.tData ? `Stand ${ago(a.tData, now)}, abgerufen ${ago(a.tFetch, now)}` : '' };
});

function lampTitle(s) { return { ok: 'aktuell', alt: 'älter', aus: 'keine Daten', bad: 'Fehler' }[s]; }
</script>

<template>
  <div v-if="!market" class="empty">
    <h1>Noch keine Momentaufnahmen</h1>
    <p class="muted">Mach im Spiel einen Komplettscan und klicke danach unter dem Scan-Knopf auf „An Manager“. Das Spiel speichert die Daten beim Neuladen, der Manager liest sie dann von selbst ein.</p>
    <p class="muted" v-if="!data.wowOk">Peon_Bridge wurde im WoW-Ordner nicht gefunden: {{ data.wowDir }}. Den Ordner stellst du unter <button class="link" @click="emit('go', 'settings')">Einstellungen</button> ein.</p>
  </div>

  <div v-else class="ov">
    <section class="flow" aria-label="Datenweg">
      <template v-for="(s, k) in stations" :key="s.key">
        <div class="station" :class="s.state">
          <div class="st-head"><span class="lamp" :title="lampTitle(s.state)"></span><h3>{{ s.title }}</h3></div>
          <p>{{ s.fact }}</p>
          <p class="small muted">{{ s.time }}</p>
        </div>
        <div v-if="k < stations.length - 1" class="link-line" aria-hidden="true"></div>
      </template>
      <div class="station side" :class="ahlStation.state">
        <div class="st-head"><span class="lamp" :title="lampTitle(ahlStation.state)"></span><h3>AHledger</h3></div>
        <p>{{ ahlStation.fact }}</p>
        <p class="small muted">{{ ahlStation.time }}</p>
        <p class="small"><button class="link" @click="api.openLink(data.ahledger.link)">Daten von AHledger (ahledger.com)</button></p>
      </div>
    </section>

    <section class="block">
      <div class="block-head">
        <h2>Markt in den letzten 30 Tagen</h2>
        <span class="small muted" v-if="market.lastScan">Letzter Scan {{ when(market.lastScan.t) }}: {{ num(market.lastScan.offers) }} Angebote, {{ num(market.lastScan.items) }} Gegenstände<template v-if="market.lastScan.char">, von {{ market.lastScan.char }}</template></span>
      </div>
      <MarketChart v-if="market.history.length > 1" :history="market.history" :theme="theme" />
      <p v-else class="muted chart-empty">Ab dem zweiten Komplettscan steht hier, wie sich Angebote und Gegenstände entwickeln.</p>
    </section>

    <section class="block moves" v-if="market.moves">
      <div class="block-head">
        <h2>Größte Preisänderungen</h2>
        <span class="small muted" v-if="market.moves.base">Median im letzten Scan gegenüber {{ when(market.moves.base) }}, nur Gegenstände ab 1 Silber und 3 Stück</span>
      </div>
      <p v-if="!market.moves.base" class="muted">Sobald es einen zweiten Komplettscan gibt, siehst du hier, was am stärksten gestiegen und gefallen ist.</p>
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

    <section class="block">
      <h2>Protokoll</h2>
      <p v-if="!data.log.length" class="muted small">Noch keine Einträge.</p>
      <ul class="log" v-else>
        <li v-for="(l, k) in data.log" :key="k" :class="{ fail: !l.ok }">
          <span class="faint small">{{ when(l.t) }}</span>
          <span class="small kind">{{ l.kind === 'spiel' ? 'Spiel' : l.kind === 'ahledger' ? 'AHledger' : l.kind }}</span>
          <span class="small">{{ l.text }}</span>
        </li>
      </ul>
    </section>
  </div>
</template>

<style scoped>
.empty { max-width: 640px; display: grid; gap: 14px; padding-top: 40px; }
.empty .primary { justify-self: start; }
.ov { display: grid; gap: 34px; max-width: 1180px; }

.flow { display: grid; grid-template-columns: minmax(0, 1fr) 30px minmax(0, 1fr) 30px minmax(0, 1fr) minmax(0, 1fr); align-items: stretch; gap: 0; }
.station { padding: 14px 16px 16px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); display: grid; gap: 4px; align-content: start; }
.station.side { margin-left: 18px; border-style: dashed; background: transparent; }
.st-head { display: flex; align-items: center; gap: 9px; margin-bottom: 2px; }
.lamp { width: 10px; height: 10px; border-radius: 50%; background: var(--faint); flex: none; }
.ok .lamp { background: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
.alt .lamp { background: var(--warn); }
.bad .lamp { background: var(--bad); }
.link-line { align-self: center; height: 2px; background: var(--line); position: relative; }
.link-line::after { content: ''; position: absolute; right: -1px; top: -4px; border: 5px solid transparent; border-left-color: var(--line); border-right: 0; }

.block { display: grid; grid-template-columns: minmax(0, 1fr); gap: 12px; }
.block-head { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }
.chart-empty { padding: 26px 0; }
.cols { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 36px; }
.cols > div { min-width: 0; }
.side-title { color: var(--muted); margin-bottom: 6px; }
.tbl { width: 100%; border-collapse: collapse; table-layout: fixed; }
.tbl td.num:not(.pct) { width: 110px; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); }
.tbl td.name { padding-left: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.num { text-align: right; white-space: nowrap; }
.click { cursor: pointer; }
.click:hover td, .click:focus-visible td { background: var(--raised); }
.pct { font-weight: 600; width: 84px; padding-right: 0 !important; }
.pct.up { color: var(--up); }
.pct.down { color: var(--down); }
.log { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; }
.log li { display: grid; grid-template-columns: 110px 80px 1fr; gap: 10px; }
.log li.fail .kind, .log li.fail span:last-child { color: var(--bad); }
.kind { color: var(--muted); }

@media (max-width: 1100px) {
  .flow { grid-template-columns: minmax(0, 1fr) 26px minmax(0, 1fr) 26px minmax(0, 1fr); row-gap: 14px; }
  .station.side { grid-column: 1 / -1; margin-left: 0; }
  .cols { grid-template-columns: 1fr; }
}
</style>
