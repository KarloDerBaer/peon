<script setup>
// Startseite Heute (ab Manager 0.56.0, Peon_Manager_Schlank.md Abschnitt 4): sagt, was jetzt zu tun ist.
// Hoechstens vier Karten, jede nur, wenn sie etwas zu sagen hat: Updates, Daten, Lohnt sich jetzt, Meine Listen.
// Kacheln und Diagramme der frueheren Uebersicht stehen unter Markt, Uebersicht (MarketSummary.vue).
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Checklist from '../components/Checklist.vue';
import { qualityColor, pl } from '../util.js';
import { statusLine, LAMP_TITLE } from '../status.js';

const props = defineProps({ data: Object, market: Object, now: Number, stamp: Number, settings: Object, updates: Object, broker: Boolean });
const emit = defineEmits(['go', 'open', 'save', 'updates', 'changed']);
const api = window.peon;

// ---------- Karte Updates ----------
const updateNames = computed(() => {
  const u = props.updates;
  if (!u || !u.count) return [];
  return [...(u.manager ? [`Peon Manager ${u.manager.version}`] : []), ...u.addons.map((a) => `${a.title || a.name} ${a.version}`)];
});

// ---------- Karte Daten ----------
const status = computed(() => {
  if (!props.broker) return { state: 'aus', text: 'Ohne Peon Broker Client sammelt der Manager keine Marktdaten.' };
  if (props.data.brokerLoading) return { state: 'alt', text: 'Marktdaten werden geladen' };
  return statusLine(props.data, props.market, props.now);
});
const reports = computed(() => props.data.reportCount || 0);

// ---------- Karte Lohnt sich jetzt: die fuenf besten aus Spekulation, Marktvergleich und Pakete ----------
const chances = ref(null);
const compare = ref(null);
const shop = ref(null);
const watchRows = ref(null);
async function load() {
  if (!props.broker || !props.market || props.data.brokerLoading) { chances.value = null; compare.value = null; shop.value = null; watchRows.value = null; return; }
  const key = props.market.key;
  const [c, m, s, w] = await Promise.all([
    api.chanceView(key).catch(() => null),
    api.compareView(key).catch(() => null),
    api.shopView(key).catch(() => null),
    api.watchView(key).catch(() => null),
  ]);
  chances.value = c;
  compare.value = m;
  shop.value = s;
  watchRows.value = w ? w.rows : null;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp, props.broker, props.data.brokerLoading], load);

const pairText = (dir) => {
  const p = compare.value && compare.value.pair;
  if (!p) return '';
  return dir === 'n' ? `nach ${p.neutralLabel} tauschen` : `nach ${p.homeLabel} tauschen`;
};
const worth = computed(() => {
  const out = [];
  if (chances.value) {
    const best = new Map();
    for (const x of chances.value.list) {
      if (!(x.gain > 0)) continue;
      const old = best.get(x.key);
      if (!old || x.gain > old.gain) best.set(x.key, x);
    }
    for (const x of best.values()) {
      out.push({ id: `s|${x.key}`, key: x.key, name: x.name, quality: x.quality, gain: x.gain, what: x.buy ? null : x.kindLabel, buy: x.buy || null, to: 'chances', label: 'Spekulation' });
    }
  }
  const m = compare.value;
  if (m && m.t) {
    for (const x of m.chances) {
      if (!x.pick || x.light !== 'green' || !(x.gainDay > 0)) continue;
      out.push({ id: `c|${x.key}|${x.dir}`, key: x.key, name: x.name, quality: x.quality, gain: x.gainDay, perDay: true, what: pairText(x.dir), to: 'compare', label: 'Marktvergleich' });
    }
    if (m.pkg) {
      for (const dir of ['n', 'h']) {
        const p = m.pkg[dir];
        if (!p || !p.offers.length || !(p.gain > 0)) continue;
        out.push({ id: `p|${dir}`, key: null, name: `Paket ${pairText(dir).replace(' tauschen', '')}`, gain: p.gain, what: pl(p.offers.length, 'Angebot', 'Angebote'), to: 'packages', label: 'Pakete' });
      }
    }
  }
  return out.sort((a, b) => b.gain - a.gain).slice(0, 5);
});

// ---------- Karte Meine Listen ----------
const shopOpen = computed(() => {
  if (!shop.value) return 0;
  let n = 0;
  for (const l of shop.value.lists) for (const r of l.items) if (!(r.wish != null && r.stock != null && r.stock >= r.wish)) n++;
  return n;
});
const shopBuyable = computed(() => {
  if (!shop.value) return 0;
  const keys = new Set();
  for (const l of shop.value.lists) for (const r of l.items) if (r.hits > 0 && !(r.wish != null && r.stock != null && r.stock >= r.wish)) keys.add(r.key);
  return keys.size;
});
const watchHits = computed(() => (watchRows.value ? watchRows.value.filter((r) => r.advice === 'buy' || r.advice === 'sell').length : 0));
const watchCount = computed(() => (watchRows.value ? watchRows.value.length : 0));
const listsShown = computed(() => props.broker && (shopOpen.value > 0 || watchCount.value > 0));

function openRow(r) {
  if (r.key) emit('open', r.key); else emit('go', r.to);
}
</script>

<template>
  <div class="today">
    <h1>Heute</h1>
    <Checklist :data="data" :settings="settings" :stamp="stamp" @go="emit('go', $event)" @save="emit('save', $event)" />

    <div class="pair">
      <section class="card upd" v-if="updateNames.length" aria-label="Updates">
        <h2>{{ updates.count === 1 ? '1 Update bereit' : `${updates.count} Updates bereit` }}</h2>
        <p class="small muted names">{{ updateNames.join(', ') }}</p>
        <div class="row"><button class="primary" @click="emit('updates')">Ansehen und installieren</button></div>
      </section>

      <section class="card" aria-label="Daten">
        <h2>Daten</h2>
        <button class="status" :class="status.state" :title="broker ? 'Zur Datenlage' : 'Zu den Addons'" @click="emit('go', broker ? 'sources' : 'modules')">
          <span class="lamp" :title="LAMP_TITLE[status.state]"></span><span>{{ status.text }}</span>
        </button>
        <p v-if="!data.wowOk" class="small warn">Peon_Bridge wurde im WoW-Ordner nicht gefunden. <button class="link" @click="emit('go', 'settings')">Einstellungen</button></p>
        <div v-if="reports" class="row between">
          <span class="small">{{ pl(reports, 'Rückmeldung', 'Rückmeldungen') }} noch nicht gesendet</span>
          <button @click="emit('go', 'reports')">Ansehen und senden</button>
        </div>
      </section>
    </div>

    <section class="card" v-if="broker" aria-label="Lohnt sich jetzt">
      <h2>Lohnt sich jetzt</h2>
      <p v-if="!market" class="muted small">Noch keine Marktdaten. Sie kommen über die Blizzard-API oder mit einem Komplettscan und „An Manager“ im Spiel.</p>
      <p v-else-if="!worth.length" class="muted small">Gerade steht nichts im Auktionshaus, das sich sicher lohnt.</p>
      <table v-else class="tbl">
        <tbody>
          <tr v-for="r in worth" :key="r.id">
            <td class="name"><span class="click" tabindex="0" :style="{ color: r.key ? qualityColor(r.quality) : null }" :title="r.name || r.key" @click="openRow(r)" @keydown.enter="openRow(r)">{{ r.name || r.key }}</span></td>
            <td class="small muted what"><template v-if="r.buy">kaufen bis <Gold :copper="r.buy" compact /></template><template v-else>{{ r.what }}</template></td>
            <td class="num win">+<Gold :copper="r.gain" compact /><span v-if="r.perDay" class="small muted"> je Tag</span></td>
            <td class="to"><button class="link small" @click="emit('go', r.to)">{{ r.label }} →</button></td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="card" v-if="listsShown" aria-label="Meine Listen">
      <h2>Meine Listen</h2>
      <div class="lists">
        <button class="link" @click="emit('go', 'shopping')">Einkaufslisten: {{ shopOpen }} offen<template v-if="shopBuyable">, {{ shopBuyable }} jetzt kaufbar</template> →</button>
        <button class="link" @click="emit('go', 'favorites')">Beobachten: {{ watchHits ? `${watchHits} ${watchHits === 1 ? 'Preis' : 'Preise'} erreicht` : `${watchCount} beobachtet, kein Preis erreicht` }} →</button>
      </div>
    </section>
  </div>
</template>

<style scoped>
.today { display: grid; gap: 18px; max-width: 1000px; }
.today h1 { margin: 0; }
.pair { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 18px; }
.card { display: grid; gap: 10px; align-content: start; padding: 14px 18px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.card h2 { margin: 0; }
.card.upd { border-color: var(--accent); }
.names { margin: 0; }
.row { display: flex; gap: 10px; align-items: center; }
.row.between { justify-content: space-between; }
.status { display: flex; align-items: center; gap: 10px; text-align: left; background: none; border: none; padding: 0; color: var(--text); }
.status:hover span:last-child { text-decoration: underline; }
.lamp { width: 10px; height: 10px; border-radius: 50%; background: var(--faint); flex: none; }
.ok .lamp { background: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
.alt .lamp { background: var(--warn); }
.bad .lamp { background: var(--bad); }
.warn { color: var(--warn); margin: 0; }
.tbl { width: 100%; border-collapse: collapse; table-layout: fixed; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); }
.tbl tr:last-child td { border-bottom: none; }
.tbl td.name { padding-left: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tbl td.what { width: 210px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tbl td.num { width: 140px; text-align: right; white-space: nowrap; }
.tbl td.to { width: 140px; text-align: right; padding-right: 0; }
.win { color: var(--up); }
.click { cursor: pointer; }
.click:hover { text-decoration: underline; }
.lists { display: flex; flex-wrap: wrap; gap: 8px 28px; }
</style>
