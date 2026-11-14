<script setup>
// Seite Chancen (ab Manager 0.35.0, Peon_Manager_Chancen.md Abschnitt 8): eine Liste aller Arten mit Satz, Pruefliste
// zum Aufklappen, Rueckmeldung, Beobachten und Uebergabe an Broker. Ersetzt die Seite Radar (WIP).
// Fallend, Steigend und Lohnend stehen in der Marktuebersicht, Wiederverkauf ist in Spekulation schnell aufgegangen.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import ChecksList from '../components/ChecksList.vue';
import RateDialog from '../components/RateDialog.vue';
import WhyNot from '../components/WhyNot.vue';
import ChanceRules from '../components/ChanceRules.vue';
import { num, fold, qualityColor, itemName, ago, when } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number, settings: Object });
const emit = defineEmits(['open', 'save', 'brief']);
const api = window.peon;

const TABS = [
  { key: 'list', label: 'Vorschläge' },
  { key: 'live', label: 'Nur live erreichbar' },
  { key: 'ratings', label: 'Rückmeldungen' },
  { key: 'rules', label: 'Einstellen' },
];
const tab = ref('list');
const d = ref(null);
const loading = ref(false);
const kind = ref('all');
const minGold = ref(Math.round((props.settings.chances?.minProfit ?? 0) / 10000));
const quality = ref(String(props.settings.chances?.quality ?? 0));
const search = ref('');
const open = ref(null);
const rating = ref(null);
const ratings = ref({ list: [], reasons: [] });
const items = ref(null);
const why = ref(null);
const limit = ref(60);

async function load() {
  if (!props.market) return;
  loading.value = true;
  try {
    d.value = await api.chanceView(props.market.key);
    if (tab.value === 'ratings') ratings.value = await api.chanceRatings();
  } finally { loading.value = false; }
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
watch(tab, (t) => { if (t === 'ratings') api.chanceRatings().then((r) => { ratings.value = r; }); });
watch([minGold, quality], () => emit('save', { chances: { ...(props.settings.chances || {}), minProfit: Math.max(0, Number(minGold.value) || 0) * 10000, quality: Number(quality.value) } }));
watch([search, kind, minGold, quality, tab], () => { limit.value = 60; why.value = null; });

const RISK = { low: 'gering', mid: 'mittel', high: 'hoch' };
const SURE = { low: 'niedrig', mid: 'mittel', high: 'hoch' };
const KIND_SHORT = { s: 'Spekulation', l: 'Langfristig', b: 'Aufkauf', v: 'Händler' };

const source = computed(() => (!d.value ? [] : tab.value === 'live' ? d.value.live : d.value.list));
const rows = computed(() => {
  const q = fold(search.value.trim());
  const minP = Math.max(0, Number(minGold.value) || 0) * 10000;
  return source.value.filter((x) => (kind.value === 'all' || x.kind === kind.value)
    && (!q || fold(itemName(x)).includes(q) || String(x.item) === q)
    && (Number(quality.value) <= 0 || (x.quality ?? -1) >= Number(quality.value))
    && (x.gain ?? 0) >= minP);
});
const shown = computed(() => rows.value.slice(0, limit.value));
const counts = computed(() => {
  const c = { all: 0, s: 0, l: 0, b: 0, v: 0 };
  for (const x of source.value) { c.all++; c[x.kind]++; }
  return c;
});

// Warum nicht? Gegenstaende, die zur Suche passen, aber nicht in der Liste stehen
const misses = computed(() => {
  const q = fold(search.value.trim());
  if (q.length < 3 || !items.value) return [];
  const inList = new Set(rows.value.map((x) => x.key));
  return items.value.filter((x) => !inList.has(x.key) && (fold(itemName(x)).includes(q) || String(x.item) === q)).slice(0, 8);
});
watch(search, async (s) => {
  if (s.trim().length >= 3 && !items.value && props.market) items.value = (await api.items(props.market.key)).items || [];
});

function daysText(x) {
  if (x.kind === 'v') return 'sofort';
  if (x.days == null) return '–';
  if (x.days < 1) return `${Math.max(1, Math.round(x.days * 24))} Std.`;
  return `${(Math.round(x.days * 10) / 10).toLocaleString('de-DE')} Tage`;
}
function holdText(h) {
  if (!h) return '–';
  if (h.hours < 1) return 'unter 1 Std.';
  return `${Math.round(h.hours)} Std.`;
}
async function watchIt(x) { await api.setFavorite(x.key, !x.watched); x.watched = !x.watched; }
async function pin(x) { await api.pinChance(props.market.key, x.key, !x.pinned); x.pinned = !x.pinned; }
async function deleteRating(id) { await api.deleteChanceRating(id); ratings.value = await api.chanceRatings(); }
async function exportRatings() { await api.exportChanceRatings(); }
const ratingLabel = (r) => [r.up === 1 ? '👍' : r.up === 0 ? '👎' : null, r.reason].filter(Boolean).join(' ');
</script>

<template>
  <div class="ch" v-if="market">
    <div class="head">
      <h1>Chancen</h1>
      <span class="small muted" v-if="d">
        <template v-if="d.t">Stand {{ when(d.t) }} ({{ ago(d.t, now) }})</template><template v-else>Noch kein vollständiger Stand</template>,
        belegte Verkaufspreise für {{ num(d.proven) }}, Haltbarkeit für {{ num(d.holdKnown) }}, Prognosen für {{ num(d.forecasts) }} Gegenstände
      </span>
    </div>
    <p class="small muted intro">Der Manager rechnet mit den Ständen der Blizzard-API, höchstens einmal je Stunde. Er liefert Kandidaten, gekauft wird nach der Prüfung im Spiel.
      Belegte Verkaufspreise sammelt er erst ab Version 0.35.0<template v-if="d && d.start"> (hier seit {{ when(d.start) }})</template>, bis dahin gibt es kaum Spekulation.</p>

    <!-- ab 0.37.0: Markt noch jung, Gold fuer den Einsatz -->
    <p class="small warn" v-if="d && d.histDays < 7" role="status">Erst {{ d.histDays }} {{ d.histDays === 1 ? 'Tag' : 'Tage' }} Preisverlauf. Spekulation schnell braucht 7 Tage, bis dahin pendelt sich der Markt erst ein und es gibt dafür keine Vorschläge.</p>
    <p class="small muted" v-if="d">
      <template v-if="d.gold != null">Dein Gold laut Ledger: <Gold :copper="d.gold" /> auf {{ d.goldChars }} {{ d.goldChars === 1 ? 'Charakter' : 'Charakteren' }}. Je Chance setzt der Manager höchstens {{ Math.round(d.rules.s.share * 100) }} % davon ein (Reiter Einstellen).</template>
      <template v-else>Dein Gold ist unbekannt, weil Peon Ledger fehlt. Der Einsatz je Chance ist darum nicht begrenzt.</template>
    </p>
    <div class="tabs" role="tablist">
      <button v-for="t in TABS" :key="t.key" role="tab" :aria-selected="tab === t.key" :class="{ on: tab === t.key }" @click="tab = t.key">
        {{ t.label }}<span class="cnt" v-if="d && t.key === 'list' && d.list.length">{{ num(d.list.length) }}</span><span class="cnt" v-if="d && t.key === 'live' && d.live.length">{{ num(d.live.length) }}</span>
      </button>
    </div>

    <template v-if="tab === 'list' || tab === 'live'">
      <p class="small muted" v-if="tab === 'live'">Unter dem Händlerpreis, aber solche Angebote sind meist nach weniger als einer Stunde weg. Sie gehen als Kandidaten an das Radar in Broker.</p>
      <div class="filters">
        <input type="text" v-model="search" placeholder="Name oder Nummer suchen" aria-label="Suchen" spellcheck="false" />
        <select v-model="kind" aria-label="Art">
          <option value="all">Alle Arten ({{ counts.all }})</option>
          <option value="s">Spekulation schnell ({{ counts.s }})</option>
          <option value="l">Spekulation langfristig ({{ counts.l }})</option>
          <option value="b">Aufkauf ({{ counts.b }})</option>
          <option value="v">Händler ({{ counts.v }})</option>
        </select>
        <label>Gewinn ab <input class="short" type="number" min="0" step="1" v-model.number="minGold" aria-label="Mindestgewinn in Gold" /> Gold</label>
        <select v-model="quality" aria-label="Qualität">
          <option value="0">Alle Qualitäten</option><option value="1">Ab Gewöhnlich</option><option value="2">Ab Selten</option><option value="3">Ab Rar</option><option value="4">Ab Episch</option>
        </select>
        <span class="small faint" v-if="loading">rechnet</span>
      </div>

      <table class="tbl" v-if="rows.length">
        <thead>
          <tr>
            <th>Gegenstand</th><th>Art</th>
            <th class="num" title="Erwarteter Gewinn nach 5 % Gebühr und Einstellgebühren">Gewinn</th>
            <th class="num" title="Wie lange es dauert, bis alles verkauft ist: Stück vor dir plus deine Menge, geteilt durch den Absatz je Tag">Verkaufsdauer</th>
            <th class="num" title="Wie lange solche Angebote meist stehen, bevor sie jemand kauft. Unter 1 Std. ist nur live im Spiel erreichbar">Haltbarkeit</th>
            <th class="num" title="Ampel aus Verkaufsdauer, Zahl der Belege, Schwankung, Haltbarkeit und Alter des Stands">Risiko</th>
            <th class="num" title="Prognose: Richtung, Zeitraum, Sicherheit">Aussicht</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="x in shown" :key="x.kind + x.key">
            <tr class="click" tabindex="0" @click="open = open === x.kind + x.key ? null : x.kind + x.key" @keydown.enter="open = open === x.kind + x.key ? null : x.kind + x.key">
              <td class="name"><span :style="{ color: qualityColor(x.quality) }">{{ itemName(x) }}</span><span v-if="x.pinned" class="tag" title="Geht sicher an Broker">Broker</span><span v-if="x.rated" class="tag">{{ ratingLabel(x.rated) || 'bewertet' }}</span></td>
              <td class="muted">{{ KIND_SHORT[x.kind] }}</td>
              <td class="num strong"><Gold :copper="x.gain" compact /></td>
              <td class="num">{{ daysText(x) }}</td>
              <td class="num" :class="{ warn: x.hold && x.hold.hours < 1 }">{{ holdText(x.hold) }}</td>
              <td class="num risk" :class="x.risk" :title="x.why && x.why.length ? x.why.join(' ') : 'Keine Bedenken'">{{ RISK[x.risk] }}</td>
              <td class="num small"><template v-if="x.outlook"><span :class="x.outlook.dir > 0 ? 'up' : 'down'">{{ x.outlook.dir > 0 ? '▲' : '▼' }}</span> {{ x.outlook.days }} T., {{ SURE[x.outlook.sure] }}</template><span v-else class="faint">–</span></td>
            </tr>
            <tr class="say"><td colspan="7">{{ x.say }}</td></tr>
            <tr v-if="open === x.kind + x.key" class="det">
              <td colspan="7">
                <div class="det-grid">
                  <div class="money small">
                    <span>Kaufen bis <Gold :copper="x.buy" /></span>
                    <span v-if="x.target">Zielpreis <Gold :copper="x.target" /></span>
                    <span v-if="x.qty">Menge {{ num(x.qty) }}</span>
                    <span v-if="x.cost">Einsatz <Gold :copper="x.cost" /></span>
                    <span v-if="x.ref">Belegter Verkaufspreis <Gold :copper="x.ref" /></span>
                    <span v-if="x.loss != null">Möglicher Verlust <Gold :copper="x.loss" /></span>
                  </div>
                  <ChecksList :checks="x.checks" :signals="x.outlook && x.outlook.signals ? x.outlook.signals : null" />
                  <div class="btns">
                    <button @click="emit('brief', x.key)">Steckbrief</button>
                    <button @click="rating = x">Rückmeldung</button>
                    <button @click="watchIt(x)">{{ x.watched ? 'Nicht mehr beobachten' : 'Beobachten' }}</button>
                    <button @click="pin(x)" :title="'Geht beim nächsten Laden im Spiel sicher an das Radar in Broker, auch wenn er nicht unter den besten 200 ist'">{{ x.pinned ? 'Nicht mehr an Broker' : 'An Broker' }}</button>
                    <button class="link" @click="emit('open', x.key)">Gegenstand</button>
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
      <p v-else-if="d" class="muted empty">{{ source.length ? 'Nichts passt zu den Filtern.' : tab === 'live' ? 'Gerade nichts.' : 'Gerade keine Chancen. Fehlen belegte Verkäufe, kommen sie mit den nächsten Ständen der Blizzard-API.' }}</p>
      <!-- ab 0.36.0: mit Daumen runter bewertete Chancen sind ausgeblendet, auch fuer Broker -->
      <p v-if="d && d.rejected && d.rejected.length" class="small muted">
        {{ d.rejected.length === 1 ? '1 Chance ist' : `${num(d.rejected.length)} Chancen sind` }} nach deiner Bewertung mit Daumen runter ausgeblendet und gehen nicht an Broker:
        {{ d.rejected.map((x) => itemName(x)).join(', ') }}. Löschst du die Bewertung im Reiter Rückmeldungen, kommt die Chance zurück.
      </p>
      <p v-if="rows.length > shown.length" class="more small muted">{{ num(shown.length) }} von {{ num(rows.length) }} <button class="link" @click="limit += 60">60 weitere zeigen</button></p>

      <div v-if="misses.length" class="whybox">
        <h3>Warum nicht?</h3>
        <div class="row"><button v-for="m in misses" :key="m.key" class="chip" :class="{ on: why === m.key }" :style="{ color: qualityColor(m.quality) }" @click="why = why === m.key ? null : m.key">{{ itemName(m) }}</button></div>
        <WhyNot v-if="why" :market="market.key" :item-key="why" :stamp="stamp" @brief="emit('brief', $event)" />
      </div>
    </template>

    <template v-else-if="tab === 'ratings'">
      <div class="row">
        <p class="small muted grow">Rückmeldungen aus dem Manager und Einschätzungen aus Broker. Die Datei für die Auswertung enthält keine Konto- oder Charakternamen. Claude schlägt daraus geänderte Startwerte oder neue Bedingungen vor, du entscheidest.</p>
        <button @click="exportRatings">Datei für die Auswertung</button>
      </div>
      <table class="tbl" v-if="ratings.list.length">
        <thead><tr><th>Wann</th><th>Gegenstand</th><th>Art</th><th>Woher</th><th>Bewertung</th><th>Bemerkung</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in ratings.list" :key="r.id">
            <td class="small muted">{{ when(r.t) }}</td>
            <td><button class="link" @click="emit('open', r.item_key)">{{ r.item_name || r.item_key }}</button><div class="small faint" v-if="r.say">{{ r.say }}</div></td>
            <td class="small">{{ KIND_SHORT[r.kind] || '–' }}</td>
            <td class="small">{{ r.origin === 'broker' ? 'Broker' : 'Manager' }}</td>
            <td>{{ ratingLabel(r) || '–' }}</td>
            <td class="small">{{ r.note }}</td>
            <td class="num"><button v-if="r.origin === 'manager'" class="link small" @click="deleteRating(r.id)">löschen</button></td>
          </tr>
        </tbody>
      </table>
      <p v-else class="muted empty">Noch keine Rückmeldungen.</p>
    </template>

    <ChanceRules v-else :market="market.key" :stamp="stamp" @open="emit('open', $event)" />

    <RateDialog v-if="rating" :chance="rating" :market="market.key" :reasons="ratings.reasons" @close="rating = null" @saved="load" />
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.ch { display: grid; gap: 14px; max-width: 1180px; align-content: start; }
.head { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }
.intro { max-width: 100ch; margin: -6px 0 0; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 8px 14px; color: var(--muted); font-weight: 500; margin-bottom: -1px; }
.tabs button:hover { color: var(--text); }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.cnt { margin-left: 8px; font-size: 12px; color: var(--faint); font-weight: 400; }
.filters, .row { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }
.filters input[type="text"] { width: 260px; }
.filters label { display: flex; gap: 8px; align-items: center; color: var(--muted); }
.short { width: 70px; }
.grow { flex: 1; margin: 0; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 6px 8px; }
.tbl tr.click td { padding-bottom: 0; }
.tbl tr.say td { padding-top: 0; color: var(--muted); font-size: 13px; border-bottom: 1px solid var(--line-soft); }
.tbl th:first-child, .tbl td:first-child { padding-left: 0; }
.num { text-align: right !important; }
.click { cursor: pointer; }
.click:hover td, .click:hover + .say td { background: var(--raised); }
.strong { font-weight: 600; }
.tag { margin-left: 8px; font-size: 11px; padding: 1px 6px; border: 1px solid var(--line); border-radius: 8px; color: var(--muted); }
.risk { font-weight: 600; }
.risk.low, .up { color: var(--up); }
.risk.mid, .warn { color: var(--warn); }
.risk.high, .down { color: var(--bad); }
.det td { background: var(--raised); border-bottom: 1px solid var(--line-soft); padding: 12px 12px 14px !important; }
.det-grid { display: grid; gap: 12px; }
.money { display: flex; gap: 18px; flex-wrap: wrap; }
.btns { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.empty { padding: 18px 0; }
.more { display: flex; gap: 12px; align-items: baseline; }
.whybox { display: grid; gap: 10px; padding-top: 10px; border-top: 1px solid var(--line); }
.whybox h3 { margin: 0; }
.chip { padding: 4px 10px; font-size: 13px; }
.chip.on { border-color: var(--accent); background: var(--accent-soft); }
</style>
