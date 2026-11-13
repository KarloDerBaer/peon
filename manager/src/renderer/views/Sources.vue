<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { ago, when, num, pl } from '../util.js';
import { gameStation, apiStation, managerStation, brokerStation, LAMP_TITLE } from '../status.js';

const props = defineProps({ data: Object, market: Object, now: Number, stamp: Number });
const emit = defineEmits(['go']);
const api = window.peon;

const view = ref(null);
const busy = ref('');
const error = ref('');
const result = ref(null);

// Konten (ab 0.29.0): Einkaufslisten und Beobachtung je WoW-Konto
const accts = ref({ list: [], waiting: [], selected: null });
async function load() {
  const [v, a] = await Promise.all([api.blizzardHouses(), api.accounts()]);
  view.value = v;
  accts.value = a;
}
const showAccts = computed(() => accts.value.list.length > 0 || accts.value.waiting.length > 0);
const charText = (a) => (a.chars.length ? (a.chars.length > 5 ? `${a.chars.slice(0, 5).join(', ')} und ${a.chars.length - 5} weitere` : a.chars.join(', ')) : 'keine Charaktere bekannt');
async function selectAcct(id) { await api.accountSelect(id); }
async function nameAcct(a, name) { if ((name || '').trim() !== (a.name || '')) await api.accountName(a.id, name); }
onMounted(load);
watch(() => props.stamp, load);

// Datenweg: zwei Zuwege, der Manager, die Rueckgabe an Broker
const game = computed(() => gameStation(props.data, props.now));
const apiSt = computed(() => apiStation(props.data, props.now));
const manager = computed(() => managerStation(props.data, props.market, props.now));
const back = computed(() => brokerStation(props.data, props.now));

const scansTotal = computed(() => props.data.markets.reduce((s, m) => s + m.scans, 0));
const livesTotal = computed(() => props.data.markets.reduce((s, m) => s + m.lives, 0));
const apiInfo = computed(() => props.data.api || { selected: 0, stands: 0, last: null, error: null });

// Welche Quelle wofuer zaehlt. "Luecken" = nur, wo es nichts Besseres gibt
const sources = computed(() => [
  { name: 'Blizzard-API', history: 'Ja', band: 'Ja', sales: 'Genau', chances: 'Ja', renew: 'Stündlich, solange der Manager läuft',
    state: !view.value || !view.value.saved ? 'Kein Zugang eingetragen' : !apiInfo.value.selected ? 'Kein Auktionshaus gewählt' : apiInfo.value.last ? `${pl(apiInfo.value.stands, 'Stand', 'Stände')}, zuletzt ${ago(apiInfo.value.last, props.now)}` : 'Noch nicht abgerufen' },
  { name: 'Komplettscan', history: 'Ja', band: 'Ja', sales: 'Lücken', chances: 'Ja', renew: 'Wenn du im Spiel scannst und neu lädst',
    state: scansTotal.value ? pl(scansTotal.value, 'Scan', 'Scans') : 'Noch keine' },
  { name: 'Live-Abfrage', history: 'Ja', band: 'Nein', sales: 'Ergänzt', chances: 'Nein', renew: 'Beim Verkaufen und im Radar im Spiel',
    state: livesTotal.value ? pl(livesTotal.value, 'Abfrage', 'Abfragen') : 'Noch keine' },
  { name: 'Broker-Verlauf', history: 'Lücken', band: 'Lücken', sales: 'Nein', chances: 'Nein', renew: 'Bei /reload oder beim Ausloggen',
    state: props.data.brokerHist && props.data.brokerHist.items ? `${num(props.data.brokerHist.items)} Gegenstände, ${pl(props.data.brokerHist.days, 'Tag', 'Tage')}` : 'Noch keiner' },
]);

// Der leere Satz von Haeusern wird nie gebraucht
const houses = computed(() => (view.value ? view.value.houses.filter((h) => !h.empty || h.selected) : []));
const unsure = (h) => (h.sure ? h.ruleset : h.group === 1 ? `${h.ruleset} (vermutet)` : `${h.ruleset} (noch unklar)`);
const howText = (h) => (h.how === 'scan' ? `Über deinen Scan zugeordnet${h.score != null ? `, ${Math.round(h.score * 100)} % gleich` : ''}` : h.how === 'ruleset' ? 'Über den Regelsatz zugeordnet' : h.how === 'guess' ? 'Vermutet über den Regelsatz. Ein Komplettscan macht es sicher.' : 'Von dir gewählt');
const chosen = computed(() => houses.value.filter((h) => h.selected));
const anySelected = computed(() => chosen.value.length > 0);
const housesText = computed(() => {
  if (!view.value || !view.value.saved) return 'Kein Zugang eingetragen';
  if (!chosen.value.length) return 'Noch keines gewählt';
  return `${pl(chosen.value.length, 'gewählt', 'gewählt')}: ${chosen.value.map((h) => `Haus ${h.id}, ${h.factionLabel}`).join(', ')}`;
});

const message = (e) => String(e && e.message || e).replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
async function run(what, fn) {
  busy.value = what;
  error.value = '';
  try { return await fn(); } catch (e) { error.value = message(e); return null; } finally { busy.value = ''; }
}
function toggle(h, on) {
  return run('toggle', async () => { view.value = await api.blizzardSetHouse(h.id, on, h.factionLabel); });
}
function suggest() {
  return run('suggest', async () => {
    const r = await api.blizzardSuggest();
    view.value = r.view;
    result.value = r.result;
  });
}
function fetchNow() {
  return run('fetch', async () => { view.value = (await api.blizzardFetch()).view; });
}

const logFails = computed(() => props.data.log.filter((l) => !l.ok).length);
const logText = computed(() => {
  const n = props.data.log.length;
  if (!n) return 'Noch keine Einträge';
  return `Letzte ${pl(n, 'Eintrag', 'Einträge')}, ${logFails.value ? pl(logFails.value, 'Fehler', 'Fehler') : 'keine Fehler'}`;
});
</script>

<template>
  <div class="src">
    <section class="block">
      <h1>Datenlage</h1>
      <div class="flow" aria-label="Datenweg">
        <div class="stack">
          <div v-for="s in [game, apiSt]" :key="s.key" class="station" :class="s.state">
            <div class="st-head"><span class="lamp" :title="LAMP_TITLE[s.state]"></span><h3>{{ s.title }}</h3></div>
            <p>{{ s.fact }}</p>
            <p class="small muted">{{ s.time }}</p>
          </div>
        </div>
        <div class="arrow" aria-hidden="true"></div>
        <div class="station" :class="manager.state">
          <div class="st-head"><span class="lamp" :title="LAMP_TITLE[manager.state]"></span><h3>{{ manager.title }}</h3></div>
          <p>{{ manager.fact }}</p>
          <p class="small muted">{{ manager.time }}</p>
        </div>
        <div class="arrow" aria-hidden="true"></div>
        <div class="station" :class="back.state">
          <div class="st-head"><span class="lamp" :title="LAMP_TITLE[back.state]"></span><h3>{{ back.title }}</h3></div>
          <p>{{ back.fact }}</p>
          <p class="small muted">{{ back.time }}</p>
        </div>
      </div>
    </section>

    <section class="block">
      <h2>Märkte</h2>
      <p v-if="!data.markets.length" class="muted small">Noch kein Markt bekannt.</p>
      <table v-else class="tbl markets">
        <thead><tr><th>Markt</th><th>Interner Name im Spiel</th><th>Letzter Stand</th></tr></thead>
        <tbody><tr v-for="m in data.markets" :key="m.key"><td>{{ m.label }}</td><td class="muted small">{{ m.key }}</td><td class="muted small">{{ m.lastScan ? ago(m.lastScan.t, now) : 'noch keiner' }}</td></tr></tbody>
      </table>
      <p class="small muted">Forever hat keine Realms: Je Region gibt es ein Auktionshaus je Regelsatz und Fraktion, dazu die neutralen Häuser. Den internen Namen meldet das Spiel, für dich ist er ohne Bedeutung.</p>
    </section>

    <section class="block" v-if="showAccts">
      <h2>Konten</h2>
      <p class="small muted lead">Einkaufslisten und Beobachtung gelten je WoW-Konto, wie im Spiel. Stern, Einkaufslisten und die Seiten dazu zeigen das gewählte Konto.</p>
      <table class="tbl accts" v-if="accts.list.length">
        <thead><tr><th>Gewählt</th><th>Name</th><th>Ordner</th><th>Charaktere</th><th>Listen</th><th>Beobachtet</th><th>Zuletzt gespielt</th></tr></thead>
        <tbody>
          <tr v-for="a in accts.list" :key="a.id" :class="{ on: a.selected }">
            <td><input type="radio" name="acct" :checked="a.selected" :aria-label="`Konto ${a.name || a.folder || a.id} wählen`" @change="selectAcct(a.id)" /></td>
            <td><input class="name" type="text" maxlength="40" :value="a.name || ''" :placeholder="a.folder || 'Name'" aria-label="Eigener Name des Kontos" @change="nameAcct(a, $event.target.value)" /></td>
            <td class="muted small">{{ a.folder || 'Ordner nicht mehr da' }}<div v-if="a.dup" class="warn">Dieselbe Kennung auch in {{ a.folders.slice(1).join(', ') }}. Abgeglichen wird nur der zuletzt gespeicherte Ordner.</div></td>
            <td class="muted small">{{ charText(a) }}</td>
            <td>{{ num(a.lists) }}</td>
            <td>{{ num(a.watch) }}</td>
            <td class="muted small"><span v-if="a.mt" :title="when(a.mt)">{{ ago(a.mt, now) }}</span></td>
          </tr>
        </tbody>
      </table>
      <p v-if="accts.waiting.length" class="small muted">Noch ohne Kennung: {{ accts.waiting.join(', ') }}. Das Konto erscheint hier, sobald du dort mit Broker ab 0.85 spielst und neu lädst oder dich ausloggst.</p>
      <p v-if="accts.migrated" class="small muted">Die Einkaufslisten und die Beobachtung von vor der Umstellung hat das erste Konto übernommen ({{ when(accts.migrated.t) }}).</p>
    </section>

    <section class="block">
      <p class="small muted" v-if="data.tips">Genaue Werte aus dem Spiel: {{ num(data.tips.known) }} Gegenstände bekannt<template v-if="data.tips.open">, {{ num(data.tips.open) }} noch offen. Das Spiel liest sie im Hintergrund und gibt sie bei /reload oder beim Ausloggen weiter</template>.</p>
      <h2>Welche Daten wofür</h2>
      <table class="tbl use">
        <thead><tr><th>Quelle</th><th>Stand</th><th class="c" title="Preisverlauf eines Gegenstands">Verlauf</th><th class="c" title="Üblicher Preisbereich, den Broker bekommt">Üblicher Preis</th><th class="c" title="Wie viel sich verkauft">Absatz</th><th class="c">Chancen</th><th>Erneuert</th></tr></thead>
        <tbody>
          <tr v-for="s in sources" :key="s.name">
            <td>{{ s.name }}</td><td class="muted small">{{ s.state }}</td>
            <td v-for="k in ['history', 'band', 'sales', 'chances']" :key="k" class="c" :class="{ muted: s[k] === 'Nein' }">{{ s[k] }}</td>
            <td class="muted small">{{ s.renew }}</td>
          </tr>
        </tbody>
      </table>
      <p class="small muted">„Lücken“ heißt: zählt nur dort, wo es nichts Besseres gibt.</p>
    </section>

    <details class="fold" v-if="view" :open="!anySelected">
      <summary><h2>Auktionshäuser</h2><span class="small muted">{{ housesText }}</span></summary>
      <div class="inner">
        <p v-if="!view.saved" class="muted lead">Dafür brauchst du einen eigenen Zugang zur Blizzard-API. Du richtest ihn unter <button class="link" @click="emit('go', 'settings')">Einstellungen</button> ein, dort steht auch eine Anleitung.</p>
        <p v-else-if="!view.reachable" class="warn">Blizzard ist gerade nicht erreichbar, die Liste der Auktionshäuser fehlt. Bitte später erneut versuchen.</p>

        <template v-else>
          <div class="head">
            <p class="muted lead small">Gewählte Häuser ruft der Manager stündlich ab, solange er läuft. „Vorschlag“ wählt die Häuser, auf denen du laut deinen Addons Charaktere hast. Ein großes Haus braucht etwa 8 MB am Tag.</p>
            <div class="actions">
              <button :disabled="!!busy" @click="suggest" title="Wählt die Häuser, auf denen du laut deinen Addons Charaktere hast">{{ busy === 'suggest' ? 'Sucht' : 'Vorschlag' }}</button>
              <button :disabled="!!busy || !anySelected" @click="fetchNow">{{ busy === 'fetch' ? 'Ruft ab' : 'Jetzt abrufen' }}</button>
            </div>
          </div>
          <p v-if="error" class="small warn" role="alert">{{ error }}</p>

          <div v-if="result" class="note small">
            <p v-if="!result.length">Deine Addons kennen noch keinen Charakter in dieser Region. Spiele einmal mit Peon_Ledger oder mache einen Komplettscan, oder wähle die Häuser von Hand.</p>
            <p v-for="r in result" :key="r.market">
              <template v-if="r.house">{{ r.label }}: Haus {{ r.house }}</template>
              <template v-else>{{ r.label }}: Kein Haus gefunden. Mache auf diesem Markt einen Komplettscan und frage dann erneut.</template>
            </p>
          </div>

          <table class="tbl houses">
            <thead><tr><th></th><th>Haus</th><th>Fraktion</th><th>Regelsatz</th><th>Markt</th><th>Stand</th></tr></thead>
            <tbody>
              <tr v-for="h in houses" :key="h.id" :class="{ on: h.selected }">
                <td><input type="checkbox" :checked="h.selected" :disabled="!!busy" :aria-label="`Haus ${h.id} abrufen`" @change="toggle(h, $event.target.checked)" /></td>
                <td>{{ h.id }}</td>
                <td>{{ h.factionLabel }}</td>
                <td class="muted">{{ unsure(h) }}</td>
                <td>
                  <template v-if="h.selected">{{ h.marketLabel }}<div class="small muted">{{ howText(h) }}</div></template>
                </td>
                <td class="muted">
                  <template v-if="h.error"><span class="warn">Fehler{{ h.error.status ? ` ${h.error.status}` : '' }}</span></template>
                  <template v-else-if="h.t"><span :title="when(h.t)">{{ ago(h.t, now) }}</span><div class="small">{{ num(h.offers) }} Angebote</div></template>
                  <template v-else-if="h.selected">Wird abgerufen</template>
                </td>
              </tr>
            </tbody>
          </table>
        </template>
      </div>
    </details>

    <details class="fold" :open="logFails > 0">
      <summary><h2>Protokoll</h2><span class="small" :class="logFails ? 'warn' : 'muted'">{{ logText }}</span></summary>
      <div class="inner">
        <p v-if="!data.log.length" class="muted small">Noch keine Einträge.</p>
        <ul class="log" v-else>
          <li v-for="(l, k) in data.log" :key="k" :class="{ fail: !l.ok }">
            <span class="faint small">{{ when(l.t) }}</span>
            <span class="small kind">{{ l.kind === 'spiel' ? 'Spiel' : l.kind === 'blizzard' ? 'Blizzard' : l.kind }}</span>
            <span class="small">{{ l.text }}</span>
          </li>
        </ul>
      </div>
    </details>
  </div>
</template>

<style scoped>
.src { display: grid; gap: 30px; max-width: 1180px; }
.block { display: grid; gap: 12px; }
.lead { max-width: 72ch; }
.head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; flex-wrap: wrap; }
.actions { display: flex; gap: 10px; }

.flow { display: grid; grid-template-columns: minmax(0, 1.1fr) 30px minmax(0, 1fr) 30px minmax(0, 1fr); align-items: stretch; }
.stack { display: grid; gap: 10px; }
.station { padding: 12px 14px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); display: grid; gap: 4px; align-content: start; }
.st-head { display: flex; align-items: center; gap: 9px; margin-bottom: 2px; }
.lamp { width: 10px; height: 10px; border-radius: 50%; background: var(--faint); flex: none; }
.ok .lamp { background: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
.alt .lamp { background: var(--warn); }
.bad .lamp { background: var(--bad); }
.arrow { align-self: center; height: 2px; background: var(--line); position: relative; }
.arrow::after { content: ''; position: absolute; right: -1px; top: -4px; border: 5px solid transparent; border-left-color: var(--line); border-right: 0; }

.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 10px 6px 0; border-bottom: 1px solid var(--line); }
.tbl td { padding: 9px 10px 9px 0; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
.tbl .c { text-align: center; }
.accts input[type="radio"] { accent-color: var(--accent); width: 16px; height: 16px; margin: 2px 0 0; }
.accts input.name { width: 14ch; }
.accts tr.on td:nth-child(2) input { font-weight: 600; }
.houses input[type="checkbox"] { accent-color: var(--accent); width: 16px; height: 16px; margin: 2px 0 0; }
.houses tr.on td:nth-child(2) { font-weight: 600; }
.note { display: grid; gap: 4px; padding: 10px 14px; border: 1px solid var(--line); border-radius: var(--radius-s); }
.note p { margin: 0; }
.warn { color: var(--warn); }

.fold { border-top: 1px solid var(--line-soft); padding-top: 14px; }
.fold summary { display: flex; align-items: baseline; gap: 14px; cursor: pointer; list-style: none; flex-wrap: wrap; }
.fold summary::-webkit-details-marker { display: none; }
.fold summary h2::before { content: '▸'; display: inline-block; width: 18px; color: var(--muted); }
.fold[open] summary h2::before { content: '▾'; }
.inner { display: grid; gap: 12px; padding-top: 14px; }
.log { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; max-height: 360px; overflow: auto; }
.log li { display: grid; grid-template-columns: 110px 90px 1fr; gap: 10px; }
.log li.fail .kind, .log li.fail span:last-child { color: var(--bad); }
.kind { color: var(--muted); }

@media (max-width: 1100px) {
  .flow { grid-template-columns: minmax(0, 1fr); row-gap: 10px; }
  .arrow { display: none; }
}
</style>
