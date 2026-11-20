<script setup>
// Marktvergleich mit dem neutralen Haus (ab Manager 0.50.0, docs/konzepte/broker/Peon_Broker_Marktvergleich.md Abschnitt 4).
// Die Rechnung laeuft im Rechen-Prozess nach jedem neuen Stand (compare.js), die Seite liest das gespeicherte Ergebnis.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import { fold, qualityColor, ago, num, perDay } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, now: Number, settings: Object });
const emit = defineEmits(['open', 'save']);
const api = window.peon;

const TABS = [{ key: 'chances', label: 'Chancen' }, { key: 'all', label: 'Alle Gegenstände' }, { key: 'sum', label: 'Übersicht' }, { key: 'rules', label: 'Einstellen' }];
const saved = (props.settings && props.settings.compareView) || {};
const tab = ref(saved.tab || 'chances');
const d = ref(null);
const busy = ref(false);
const search = ref('');
const dir = ref(saved.dir || 'all');            // all, n (nach Neutral), h (nach Fraktion)
const light = ref(saved.light || 'all');        // all, green, pick (ab 0.51.0: Auswahl fuer Broker)
const onlyCommodity = ref(!!saved.commodity);
const quality = ref(saved.quality || 0);
const showHidden = ref(false);
const open = ref(null);
const sortKey = ref('score');
const sortDesc = ref(true);
const limit = ref(300);
const form = ref(null);

async function load() {
  busy.value = true;
  try { d.value = await api.compareView(props.market ? props.market.key : ''); } finally { busy.value = false; }
  if (d.value && d.value.rules) form.value = toForm(d.value.rules);
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
watch([tab, dir, light, onlyCommodity, quality], () => {
  emit('save', { compareView: { tab: tab.value, dir: dir.value, light: light.value, commodity: onlyCommodity.value, quality: quality.value } });
});
watch([search, dir, light, onlyCommodity, quality, tab], () => { limit.value = 300; });

const hidden = computed(() => new Set(d.value && d.value.hidden ? d.value.hidden : []));
const pins = computed(() => new Set(d.value && d.value.pins ? d.value.pins : []));
const home = computed(() => (d.value && d.value.pair ? d.value.pair.homeLabel : 'Fraktion'));
const neutral = computed(() => (d.value && d.value.pair ? d.value.pair.neutralLabel : 'Neutral'));
const dirText = (x) => (x === 'n' ? `${home.value} → ${neutral.value}` : `${neutral.value} → ${home.value}`);

function pass(r) {
  const q = fold(search.value.trim());
  if (q && !fold(`${r.name || ''} ${r.item}`).includes(q)) return false;
  if (onlyCommodity.value && !r.commodity) return false;
  if (quality.value && (r.quality ?? 0) < quality.value) return false;
  if (dir.value !== 'all' && r.dir !== dir.value) return false;
  if (light.value === 'green' && r.light !== 'green') return false;
  if (light.value === 'pick' && !r.pick && !pins.value.has(r.key)) return false;
  return true;
}
function sorted(list) {
  const k = sortKey.value, s = sortDesc.value ? -1 : 1;
  return [...list].sort((a, b) => {
    const x = a[k], y = b[k];
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    if (typeof x === 'string') return s * x.localeCompare(y, 'de');
    return s * (x - y);
  });
}
const chances = computed(() => {
  if (!d.value || !d.value.chances) return [];
  return sorted(d.value.chances.filter((r) => pass(r) && (showHidden.value || !hidden.value.has(r.key))));
});
const all = computed(() => {
  if (!d.value || !d.value.items) return [];
  return sorted(d.value.items.filter(pass));
});
const shown = computed(() => (tab.value === 'all' ? all.value : chances.value).slice(0, limit.value));
const total = computed(() => (tab.value === 'all' ? all.value.length : chances.value.length));

function sortBy(k) {
  if (sortKey.value === k) sortDesc.value = !sortDesc.value;
  else { sortKey.value = k; sortDesc.value = k !== 'name'; }
}
watch(tab, (t) => { sortKey.value = t === 'all' ? 'pct' : 'score'; sortDesc.value = true; });
const arrow = (k) => (sortKey.value === k ? (sortDesc.value ? ' ▾' : ' ▴') : '');

const LIGHT = { green: 'Grün', yellow: 'Gelb', red: 'Rot' };
const WHY = { spanne: 'Spanne zu klein', netto: 'Gewinn je Stück zu klein', absatz: 'zu wenig Absatz im Ziel', bestaendig: 'Unterschied hält nicht', vorrat: 'Ziel voll' };
const pctText = (v) => (v == null ? '–' : `${v > 0 ? '+' : ''}${Math.round(v * 100)} %`);
const consText = (v) => `${Math.round((v || 0) * 100)} %`;
const supplyText = (v) => (v == null ? '–' : v >= 100 ? '99+' : perDay(v));

async function pin(r) { await api.pinCompare(r.key, !pins.value.has(r.key)); await load(); }
async function hide(r) { busy.value = true; await api.hideCompare(r.key, !hidden.value.has(r.key)); await load(); }

// Einstellen: Prozente als ganze Zahlen, Silber statt Kupfer
function toForm(ru) {
  return { days: ru.days, share: Math.round(ru.share * 100), hold: ru.hold, minPct: Math.round(ru.minPct * 100), minNet: ru.minNet / 100,
    minSales: ru.minSales, minCons: Math.round(ru.minCons * 100), cutN: Math.round(ru.cutN * 100), top: ru.top };
}
function fromForm(f) {
  return { days: Number(f.days), share: Number(f.share) / 100, hold: Number(f.hold), minPct: Number(f.minPct) / 100, minNet: Number(f.minNet) * 100,
    minSales: Number(f.minSales), minCons: Number(f.minCons) / 100, cutN: Number(f.cutN) / 100, top: Number(f.top) };
}
const ruleNote = ref('');
async function saveRules() {
  await api.setCompareRules(fromForm(form.value));
  ruleNote.value = 'Gespeichert. Der Manager rechnet gleich neu, das dauert einige Sekunden.';
  await load();
}
async function resetRules() {
  await api.resetCompareRules();
  ruleNote.value = 'Standardwerte. Der Manager rechnet gleich neu.';
  await load();
}
</script>

<template>
  <div class="compare">
    <div class="head">
      <h1>Marktvergleich</h1>
      <span class="muted small" v-if="d && d.pair">{{ home }} ↔ {{ neutral }}<template v-if="d.t">, gerechnet {{ ago(d.t, now) }}</template></span>
    </div>
    <p v-if="!d" class="muted">Lädt …</p>
    <template v-else-if="!d.pair">
      <p class="muted">Für diesen Markt gibt es kein neutrales Gegenstück. Der Marktvergleich braucht Daten aus dem eigenen und aus dem neutralen Haus desselben Regelsatzes, zum Beispiel über die Blizzard-API (Einstellungen) oder einen Scan im neutralen Auktionshaus.</p>
    </template>
    <template v-else>
      <p class="small muted">Im einen Haus kaufen, im anderen verkaufen. Grundlage sind die günstigsten Preise und die echten Verkäufe der letzten {{ d.rules.days }} Tage.
        Anteil {{ neutral }}: {{ Math.round((d.cutN ?? d.rules.cutN) * 100) }} %<span v-if="!d.cutSure" class="warn"> (angenommen, Broker hat ihn noch nicht gemessen)</span>,
        {{ home }}: {{ Math.round((d.cutH ?? 0.05) * 100) }} %.</p>
      <p class="small warn" v-if="d.stale">Die Einstellungen wurden geändert. Die Liste zeigt noch die letzte Rechnung.</p>
      <p class="small muted" v-if="!d.t">Noch nicht gerechnet. Das passiert nach dem nächsten Stand der Blizzard-API oder dem nächsten Einlesen.</p>

      <div class="tabs" role="tablist">
        <button v-for="t in TABS" :key="t.key" role="tab" :aria-selected="tab === t.key" :class="{ on: tab === t.key }" @click="tab = t.key">
          {{ t.label }}<span class="cnt" v-if="t.key === 'chances' && d.chances">{{ num(d.chances.length) }}</span>
        </button>
      </div>

      <template v-if="(tab === 'chances' || tab === 'all') && d.t">
        <div class="filters">
          <input type="search" v-model="search" placeholder="Name oder Nummer suchen" aria-label="Suchen" spellcheck="false" />
          <select v-model="dir" aria-label="Richtung">
            <option value="all">Beide Richtungen</option>
            <option value="n">{{ home }} → {{ neutral }}</option>
            <option value="h">{{ neutral }} → {{ home }}</option>
          </select>
          <select v-model="light" aria-label="Ampel" v-if="tab === 'chances'">
            <option value="all">Grün und Gelb</option>
            <option value="green">Nur Grün</option>
            <option value="pick">Nur Auswahl für Broker</option>
          </select>
          <select v-model.number="quality" aria-label="Qualität">
            <option :value="0">Jede Qualität</option>
            <option :value="1">ab Gewöhnlich</option>
            <option :value="2">ab Selten</option>
            <option :value="3">ab Rar</option>
            <option :value="4">ab Episch</option>
          </select>
          <label class="check small"><input type="checkbox" v-model="onlyCommodity" /> Nur Massenware</label>
          <label class="check small" v-if="tab === 'chances' && hidden.size"><input type="checkbox" v-model="showHidden" /> Ausgeblendete zeigen ({{ hidden.size }})</label>
          <span class="muted small">{{ num(total) }} Gegenstände</span>
        </div>

        <table class="tbl" v-if="tab === 'chances'">
          <thead><tr>
            <th class="click" @click="sortBy('name')">Gegenstand{{ arrow('name') }}</th>
            <th>Richtung</th>
            <th class="num click" @click="sortBy('buy')" title="Üblicher günstigster Preis in der Quelle (Kaufen bis)">Kaufen{{ arrow('buy') }}</th>
            <th class="num click" @click="sortBy('sell')" title="Echter Verkaufspreis im Ziel, höchstens das übliche günstigste Angebot dort">Verkaufen{{ arrow('sell') }}</th>
            <th class="num click" @click="sortBy('net')" title="Je Stück nach dem Anteil des Zielhauses">Gewinn{{ arrow('net') }}</th>
            <th class="num click" @click="sortBy('pct')">Spanne{{ arrow('pct') }}</th>
            <th class="num click" @click="sortBy('perDay')" title="Verkaufte Stück je Tag im Ziel">Absatz{{ arrow('perDay') }}</th>
            <th class="num click" @click="sortBy('supply')" title="Angebot im Ziel geteilt durch den Absatz: Tage, bis alles weg ist">Vorrat{{ arrow('supply') }}</th>
            <th class="num click" @click="sortBy('cons')" title="Anteil der Tage mit Gewinn">Hält{{ arrow('cons') }}</th>
            <th class="num click" @click="sortBy('qty')" title="Eigener Anteil am Absatz mal Haltedauer">Menge{{ arrow('qty') }}</th>
            <th class="num click" @click="sortBy('gainDay')" title="Gewinn je Stück mal Absatz mal eigener Anteil">Je Tag{{ arrow('gainDay') }}</th>
            <th class="click" @click="sortBy('score')">Ampel{{ arrow('score') }}</th>
            <th></th>
          </tr></thead>
          <tbody>
            <template v-for="r in shown" :key="r.key + r.dir">
              <tr :class="{ dim: hidden.has(r.key), sel: open === r.key + r.dir }" @click="open = open === r.key + r.dir ? null : r.key + r.dir">
                <td class="name"><span class="click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click.stop="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name || r.key }}</span>
                  <span v-if="pins.has(r.key)" class="pin small" title="Geht immer an Broker">An Broker</span>
                  <span v-else-if="r.pick" class="pin small" title="Unter den besten, geht an Broker">Auswahl</span></td>
                <td class="small">{{ dirText(r.dir) }}</td>
                <td class="num"><Gold :copper="r.buy" compact /></td>
                <td class="num"><Gold :copper="r.sell" compact /></td>
                <td class="num good"><Gold :copper="r.net" compact /></td>
                <td class="num">{{ pctText(r.pct) }}</td>
                <td class="num">{{ perDay(r.perDay) }}</td>
                <td class="num">{{ supplyText(r.supply) }}</td>
                <td class="num">{{ consText(r.cons) }}</td>
                <td class="num">{{ num(r.qty) }}</td>
                <td class="num"><Gold :copper="r.gainDay" compact /></td>
                <td><span class="light" :class="r.light">{{ LIGHT[r.light] }}</span></td>
                <td class="acts" @click.stop>
                  <button class="small" @click="pin(r)" :title="pins.has(r.key) ? 'Nicht mehr immer an Broker' : 'Immer an Broker geben'">{{ pins.has(r.key) ? 'Lösen' : 'An Broker' }}</button>
                  <button class="small" @click="hide(r)" :title="hidden.has(r.key) ? 'Wieder zeigen' : 'Ausblenden, auch in Broker'">{{ hidden.has(r.key) ? 'Zeigen' : 'Ausblenden' }}</button>
                </td>
              </tr>
              <tr v-if="open === r.key + r.dir" class="more"><td colspan="13">
                <p>{{ r.say }}</p>
                <p class="small muted">Kaufen jetzt: <Gold v-if="r.srcNow != null" :copper="r.srcNow" compact /><span v-else>kein Angebot</span>.
                  Ziel jetzt: <Gold v-if="r.dstNow != null" :copper="r.dstNow" compact /><span v-else>kein Angebot</span>, {{ num(Math.round(r.stock)) }} im Angebot.
                  Echte Verkäufe: <template v-if="r.soldPx != null">im Mittel <Gold :copper="r.soldPx" compact /></template><template v-else>keine gesehen, gerechnet mit dem günstigsten Angebot</template>.
                  Absatzquote: {{ r.rate != null ? Math.round(r.rate * 100) + ' %' : '–' }}. Gewinn an {{ r.plus }} von {{ r.days }} Tagen.</p>
                <p class="small muted" v-if="r.days14 != null">Langfristig: Gewinn an {{ r.plus14 }} von {{ r.days14 }} Tagen, im Ziel an {{ Math.round((r.even || 0) * 100) }} % der Tage verkauft,
                  Unterschied {{ r.trend >= 1.1 ? 'wachsend' : r.trend <= 0.8 ? 'schrumpfend' : 'gleichbleibend' }}. Das ergibt den Faktor {{ (r.longF || 0).toFixed(2).replace('.', ',') }} in der Bewertung.</p>
              </td></tr>
            </template>
          </tbody>
        </table>

        <table class="tbl" v-else>
          <thead><tr>
            <th class="click" @click="sortBy('name')">Gegenstand{{ arrow('name') }}</th>
            <th class="num click" @click="sortBy('hm')">{{ home }}{{ arrow('hm') }}</th>
            <th class="num click" @click="sortBy('nm')">{{ neutral }}{{ arrow('nm') }}</th>
            <th class="num click" @click="sortBy('sh')" title="Verkaufte Stück je Tag">Absatz {{ home }}{{ arrow('sh') }}</th>
            <th class="num click" @click="sortBy('sn')" title="Verkaufte Stück je Tag">Absatz {{ neutral }}{{ arrow('sn') }}</th>
            <th>Bessere Richtung</th>
            <th class="num click" @click="sortBy('pct')" title="Gewinn in Prozent des Kaufpreises nach dem Anteil des Zielhauses">Spanne{{ arrow('pct') }}</th>
            <th class="num click" @click="sortBy('net')">Gewinn{{ arrow('net') }}</th>
            <th>Ampel</th>
          </tr></thead>
          <tbody>
            <tr v-for="r in shown" :key="r.key">
              <td class="name click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name || r.key }}</td>
              <td class="num"><Gold v-if="r.hm != null" :copper="r.hm" compact /><span v-else class="muted">–</span></td>
              <td class="num"><Gold v-if="r.nm != null" :copper="r.nm" compact /><span v-else class="muted">–</span></td>
              <td class="num">{{ perDay(r.sh) }}</td>
              <td class="num">{{ perDay(r.sn) }}</td>
              <td class="small">{{ dirText(r.dir) }}</td>
              <td class="num" :class="{ good: r.pct > 0 }">{{ r.pct > 0 ? '+' : '' }}{{ r.pct }} %</td>
              <td class="num"><Gold v-if="r.net > 0" :copper="r.net" compact /><span v-else class="muted">–</span></td>
              <td><span class="light" :class="r.light">{{ LIGHT[r.light] }}</span></td>
            </tr>
          </tbody>
        </table>
        <p v-if="total > shown.length"><button @click="limit += 300">Weitere {{ Math.min(300, total - shown.length) }} zeigen</button></p>
        <p v-if="!total" class="muted">Nichts gefunden.</p>
      </template>

      <template v-if="tab === 'sum' && d.t">
        <div class="cards">
          <div class="card"><div class="big">{{ num(d.sum.n) }}</div><div class="muted small">Chancen {{ home }} → {{ neutral }}</div></div>
          <div class="card"><div class="big">{{ num(d.sum.h) }}</div><div class="muted small">Chancen {{ neutral }} → {{ home }}</div></div>
          <div class="card"><div class="big">{{ num(d.sum.green) }}</div><div class="muted small">davon grün</div></div>
          <div class="card"><div class="big"><Gold :copper="d.sum.gainGreen" compact /></div><div class="muted small">Gewinn je Tag aller grünen</div></div>
          <div class="card"><div class="big">{{ num(d.sum.both) }}</div><div class="muted small">Gegenstände in beiden Häusern</div></div>
        </div>
        <p class="small muted">Absatzdaten: {{ home }} {{ d.days.home }} Tage, {{ neutral }} {{ d.days.neutral }} Tage.
          Letzter Stand: {{ home }} {{ d.stand.home ? ago(d.stand.home, now) : 'keiner' }}, {{ neutral }} {{ d.stand.neutral ? ago(d.stand.neutral, now) : 'keiner' }}.</p>
        <p class="small muted">Eine Chance braucht mindestens {{ Math.round(d.rules.minPct * 100) }} % Spanne, {{ d.rules.minNet / 100 }} Silber Gewinn je Stück,
          {{ d.rules.minSales }} verkauftes Stück am Tag im Ziel und Gewinn an {{ Math.round(d.rules.minCons * 100) }} % der Tage. Ab 10 Tagen Vorrat im Ziel fällt sie weg, ab 3 Tagen zählt sie weniger.
          Grün heißt: Gewinn an mindestens 70 % der Tage und höchstens 3 Tage Vorrat.</p>
        <p class="small muted">An Broker gehen die besten {{ d.rules.top }} ({{ num(d.sum.picked || 0) }} gerade ausgewählt), dazu alle mit „An Broker“. Ausgeblendete gehen nicht an Broker, für sie rückt die nächste nach.
          Die Bewertung nimmt Gewinn je Tag, Beständigkeit und den Vorrat im Ziel, dazu die letzten 14 Tage: wie beständig der Unterschied war, wie gleichmäßig im Ziel verkauft wird und ob der Unterschied wächst oder schrumpft.</p>
      </template>

      <template v-if="tab === 'rules' && form">
        <div class="form">
          <label>Zeitraum
            <select v-model.number="form.days"><option v-for="x in d.choices.days" :key="x" :value="x">{{ x }} Tage</option></select></label>
          <label>Eigener Anteil am Absatz <input type="number" min="1" max="100" v-model.number="form.share" /> %</label>
          <label>Haltedauer <input type="number" min="0.25" max="14" step="0.25" v-model.number="form.hold" /> Tage</label>
          <label>Spanne mindestens <input type="number" min="0" max="500" v-model.number="form.minPct" /> %</label>
          <label>Gewinn je Stück mindestens <input type="number" min="0" v-model.number="form.minNet" /> Silber</label>
          <label>Absatz im Ziel mindestens <input type="number" min="0" step="0.5" v-model.number="form.minSales" /> je Tag</label>
          <label>Gewinn an mindestens <input type="number" min="0" max="100" v-model.number="form.minCons" /> % der Tage</label>
          <label>An Broker die besten <input type="number" min="1" max="100" v-model.number="form.top" /></label>
          <label>Anteil des neutralen Hauses, solange nicht gemessen <input type="number" min="0" max="50" v-model.number="form.cutN" /> %</label>
        </div>
        <p class="small muted">Eigener Anteil und Haltedauer bestimmen die Menge: so viel, wie du in der Haltedauer bei deinem Anteil am Absatz los wirst.
          Vorgabe {{ Math.round(d.defaults.share * 100) }} % und {{ d.defaults.hold }} Tag.</p>
        <p><button @click="saveRules">Speichern</button> <button @click="resetRules">Standardwerte</button> <span class="small muted">{{ ruleNote }}</span></p>
      </template>
    </template>
  </div>
</template>

<style scoped>
.head { display: flex; align-items: baseline; gap: 12px; }
.filters { display: flex; gap: 10px; align-items: center; margin: 10px 0 12px; flex-wrap: wrap; }
.filters input[type="search"] { min-width: 240px; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); margin-top: 8px; }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 8px 14px; color: var(--muted); font-weight: 500; margin-bottom: -1px; }
.tabs button:hover { color: var(--text); }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.cnt { margin-left: 6px; font-size: 0.85em; color: var(--muted); }
.good { color: var(--good, #60e060); }
.warn { color: var(--warn, #ff7070); }
.light { padding: 1px 8px; border-radius: 8px; font-size: 0.85em; }
.light.green { background: rgba(96, 224, 96, 0.18); color: var(--good, #60e060); }
.light.yellow { background: rgba(255, 209, 0, 0.18); color: #e0b000; }
.light.red { background: rgba(255, 112, 112, 0.15); color: var(--warn, #ff7070); }
.pin { margin-left: 6px; color: var(--accent); }
tr.dim td { opacity: 0.5; }
tr.more td { background: var(--panel, rgba(127, 127, 127, 0.06)); }
.acts { white-space: nowrap; }
.acts button { padding: 2px 6px; margin-left: 2px; }
th.click, .click { cursor: pointer; }
.cards { display: flex; gap: 12px; flex-wrap: wrap; margin: 12px 0; }
.card { border: 1px solid var(--line); border-radius: 8px; padding: 10px 14px; min-width: 150px; }
.big { font-size: 1.4em; font-weight: 600; }
.form { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 10px 20px; margin: 12px 0; }
.form input[type="number"] { width: 80px; }
</style>
