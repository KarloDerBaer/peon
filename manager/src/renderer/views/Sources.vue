<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { ago, when, num, pl } from '../util.js';

const props = defineProps({ data: Object, now: Number, stamp: Number });
const emit = defineEmits(['go']);
const api = window.peon;

const view = ref(null);
const busy = ref('');
const error = ref('');
const result = ref(null);

async function load() { view.value = await api.blizzardHouses(); }
onMounted(load);
watch(() => props.stamp, load);

const scansTotal = computed(() => props.data.markets.reduce((s, m) => s + m.scans, 0));
const livesTotal = computed(() => props.data.markets.reduce((s, m) => s + m.lives, 0));
const apiInfo = computed(() => props.data.api || { selected: 0, stands: 0, last: null, error: null });

const sources = computed(() => [
  { name: 'Eigene Komplettscans', kind: 'Momentaufnahme', use: 'Gespeichert und ausgewertet',
    state: scansTotal.value ? pl(scansTotal.value, 'Scan', 'Scans') : 'Noch keine' },
  { name: 'Eigene Live-Abfragen', kind: 'Momentaufnahme (ein Gegenstand)', use: 'Gespeichert und ausgewertet',
    state: livesTotal.value ? pl(livesTotal.value, 'Abfrage', 'Abfragen') : 'Noch keine' },
  { name: 'Broker-Verlauf', kind: 'Momentaufnahme, gemittelt je Tag', use: 'Gespeichert und im Verlauf gezeigt, wenn es für einen Tag keinen eigenen Scan gibt',
    state: props.data.brokerHist && props.data.brokerHist.items ? `${num(props.data.brokerHist.items)} Gegenstände, ${num(props.data.brokerHist.days)} Tage` : 'Noch keine' },
  { name: 'Blizzard-API', kind: 'Momentaufnahme, stündlich', use: 'Gespeichert und ausgewertet, der Absatz wird damit genauer',
    state: !view.value || !view.value.saved ? 'Kein Zugang eingetragen' : !apiInfo.value.selected ? 'Kein Auktionshaus gewählt' : apiInfo.value.last ? `${pl(apiInfo.value.stands, 'Stand', 'Stände')}, zuletzt ${ago(apiInfo.value.last, props.now)}` : 'Noch nicht abgerufen' },
]);

// Der leere Satz von Haeusern wird nie gebraucht
const houses = computed(() => (view.value ? view.value.houses.filter((h) => !h.empty || h.selected) : []));
const unsure = (h) => (h.sure ? h.ruleset : h.group === 1 ? `${h.ruleset} (vermutet)` : `${h.ruleset} (noch unklar)`);
const howText = (h) => (h.how === 'scan' ? `Über deinen Scan zugeordnet${h.score != null ? `, ${Math.round(h.score * 100)} % gleich` : ''}` : h.how === 'ruleset' ? 'Über den Regelsatz zugeordnet' : h.how === 'guess' ? 'Vermutet über den Regelsatz. Ein Komplettscan macht es sicher.' : 'Von dir gewählt');

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
const anySelected = computed(() => houses.value.some((h) => h.selected));
</script>

<template>
  <div class="src">
    <section class="block">
      <h1>Quellen</h1>
      <p class="muted lead">Alle Quellen sind Momentaufnahmen: Sie zeigen genau, was zu einem Zeitpunkt im Auktionshaus stand.</p>
      <table class="tbl">
        <thead><tr><th>Quelle</th><th>Art</th><th>Verwendung</th><th>Stand</th></tr></thead>
        <tbody>
          <tr v-for="s in sources" :key="s.name">
            <td>{{ s.name }}</td><td class="muted">{{ s.kind }}</td><td>{{ s.use }}</td><td class="muted">{{ s.state }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block" v-if="view">
      <div class="head">
        <h2>Auktionshäuser von der Blizzard-API</h2>
        <div class="actions" v-if="view.saved && view.reachable">
          <button :disabled="!!busy" @click="suggest" title="Wählt die Häuser, auf denen du laut deinen Addons Charaktere hast">{{ busy === 'suggest' ? 'Sucht' : 'Vorschlag' }}</button>
          <button :disabled="!!busy || !anySelected" @click="fetchNow">{{ busy === 'fetch' ? 'Ruft ab' : 'Jetzt abrufen' }}</button>
        </div>
      </div>

      <p v-if="!view.saved" class="muted lead">Dafür brauchst du einen eigenen Zugang zur Blizzard-API. Du richtest ihn unter <button class="link" @click="emit('go', 'settings')">Einstellungen</button> ein, dort steht auch eine Anleitung.</p>
      <p v-else-if="!view.reachable" class="warn">Blizzard ist gerade nicht erreichbar, die Liste der Auktionshäuser fehlt. Bitte später erneut versuchen.</p>

      <template v-else>
        <p class="muted lead">Gewählte Häuser ruft der Manager stündlich ab, solange er läuft. Der Knopf „Vorschlag“ wählt die Häuser, auf denen du laut deinen Addons Charaktere hast. Ein großes Haus braucht etwa 8 MB am Tag, siehe Aufbewahrung unter Einstellungen.</p>
        <p v-if="error" class="small warn" role="alert">{{ error }}</p>

        <div v-if="result" class="note small">
          <p v-if="!result.length">Deine Addons kennen noch keinen Charakter in dieser Region. Spiele einmal mit Peon_Ledger oder mache einen Komplettscan, oder wähle die Häuser von Hand.</p>
          <p v-for="r in result" :key="r.market">
            <template v-if="r.house">{{ r.market }}: Haus {{ r.house }}</template>
            <template v-else>{{ r.market }}: Kein Haus gefunden. Mache auf diesem Markt einen Komplettscan und frage dann erneut.</template>
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
                <template v-if="h.selected">{{ h.market }}<div class="small muted">{{ howText(h) }}</div></template>
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
    </section>
  </div>
</template>

<style scoped>
.src { display: grid; gap: 36px; max-width: 980px; }
.block { display: grid; gap: 12px; }
.lead { max-width: 72ch; }
.head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
.actions { display: flex; gap: 10px; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 10px 6px 0; border-bottom: 1px solid var(--line); }
.tbl td { padding: 9px 10px 9px 0; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
.houses input[type="checkbox"] { accent-color: var(--accent); width: 16px; height: 16px; margin: 2px 0 0; }
.houses tr.on td:nth-child(2) { font-weight: 600; }
.note { display: grid; gap: 4px; padding: 10px 14px; border: 1px solid var(--line); border-radius: var(--radius-s); }
.note p { margin: 0; }
.warn { color: var(--warn); }
</style>
