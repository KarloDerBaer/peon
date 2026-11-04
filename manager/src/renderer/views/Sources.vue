<script setup>
import { ref, computed, onMounted } from 'vue';
import { ago, num } from '../util.js';
import BlizzardCheck from '../components/BlizzardCheck.vue';

const props = defineProps({ data: Object, settings: Object, now: Number });
const emit = defineEmits(['save']);
const api = window.peon;

// Bekannte AHledger-Märkte (Stand 22.10.2026), wird beim Öffnen durch die Liste von AHledger ersetzt
const FALLBACK = ['normal', 'pvp', 'rp'].flatMap((r) => ['us', 'eu', 'cn'].flatMap((g) => ['alliance', 'horde'].map((f) => ({ id: `forever.${r}.${f}.${g}`, label: '' }))));
const extList = ref(FALLBACK);
const listNote = ref('');
const map = ref(JSON.parse(JSON.stringify(props.settings.marketMap || {})));
const saved = ref(false);
const fetching = ref(false);
const blizzard = ref(null);

onMounted(async () => {
  const r = await api.ahledgerMarkets();
  if (Array.isArray(r) && r.length) extList.value = r.filter((m) => m.game === 'forever');
  else if (r && r.error) listNote.value = `Liste von AHledger nicht erreichbar (${r.error}), es gilt die gespeicherte Auswahl.`;
});

const scansTotal = computed(() => props.data.markets.reduce((s, m) => s + m.scans, 0));
const livesTotal = computed(() => props.data.markets.reduce((s, m) => s + m.lives, 0));
const ahlLast = computed(() => props.data.ahledger.markets.reduce((a, b) => (!a || (b.tData || 0) > (a.tData || 0) ? b : a), null));

const sources = computed(() => [
  { name: 'Eigene Komplettscans', kind: 'Momentaufnahme', use: 'Gespeichert und ausgewertet',
    state: scansTotal.value ? `${num(scansTotal.value)} Scans` : 'Noch keine' },
  { name: 'Eigene Live-Abfragen', kind: 'Momentaufnahme (ein Gegenstand)', use: 'Gespeichert und ausgewertet',
    state: livesTotal.value ? `${num(livesTotal.value)} Abfragen` : 'Noch keine' },
  { name: 'Broker-Verlauf', kind: 'Momentaufnahme, gemittelt je Tag', use: 'Gespeichert und im Verlauf gezeigt, wenn es für einen Tag keinen eigenen Scan gibt',
    state: props.data.brokerHist && props.data.brokerHist.items ? `${num(props.data.brokerHist.items)} Gegenstände, ${num(props.data.brokerHist.days)} Tage` : 'Noch keine' },
  { name: 'AHledger', kind: 'Fremdmessung (Scans vieler Spieler)', use: 'Nur zum Vergleich, bis die Quellenprüfung abgeschlossen ist',
    state: !props.data.ahledger.enabled ? 'Ausgeschaltet' : ahlLast.value && ahlLast.value.tData ? `Stand ${ago(ahlLast.value.tData, props.now)}` : 'Noch nicht abgerufen' },
  { name: 'Blizzard-API', kind: 'Momentaufnahme', use: 'Wird eingelesen, sobald Blizzard Daten für Forever liefert',
    state: !blizzard.value || !blizzard.value.report ? 'Noch nicht geprüft' : blizzard.value.report.result === 'auctions' ? 'Daten gefunden, noch nicht eingelesen' : `Keine Daten (${ago(blizzard.value.report.t, props.now)})` },
]);

function setExt(key, ext) {
  map.value[key] = { ext, confirmed: map.value[key] ? map.value[key].confirmed : false };
  saved.value = false;
}
function confirm(key) {
  if (!map.value[key]) return;
  map.value[key].confirmed = true;
  emit('save', { marketMap: map.value });
  saved.value = true;
}
async function fetchNow() {
  fetching.value = true;
  try { await api.fetchAhledger(); } finally { fetching.value = false; }
}
</script>

<template>
  <div class="src">
    <section class="block">
      <h1>Quellen</h1>
      <p class="muted lead">Momentaufnahmen zeigen genau, was zu einem Zeitpunkt im Auktionshaus stand. Fremdmessungen fassen Scans vieler Spieler zusammen und fließen erst in die Auswertung ein, wenn ein Vergleich mit deinen eigenen Scans zeigt, wofür sie taugen.</p>
      <table class="tbl">
        <thead><tr><th>Quelle</th><th>Art</th><th>Verwendung</th><th>Stand</th></tr></thead>
        <tbody>
          <tr v-for="s in sources" :key="s.name">
            <td>{{ s.name }}</td><td class="muted">{{ s.kind }}</td><td>{{ s.use }}</td><td class="muted">{{ s.state }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block">
      <div class="head">
        <h2>Zuordnung zu AHledger</h2>
        <button :disabled="fetching || !data.ahledger.enabled" @click="fetchNow">{{ fetching ? 'Ruft ab' : 'Jetzt abrufen' }}</button>
      </div>
      <p class="muted">AHledger kennt keine Realms, sondern Regelsatz, Fraktion und Region. Der Vorschlag beruht auf dem Namen deines Markts. Bitte prüfen und bestätigen.</p>
      <p v-if="listNote" class="small warn">{{ listNote }}</p>
      <p v-if="!data.markets.length" class="muted">Sobald der erste Scan eingelesen ist, erscheint dein Markt hier.</p>
      <div v-for="m in data.markets" :key="m.key" class="map-row">
        <span class="mkey">{{ m.key }}</span>
        <select :value="map[m.key] ? map[m.key].ext : ''" @change="setExt(m.key, $event.target.value)" :aria-label="'AHledger-Markt für ' + m.key">
          <option value="">Keine Zuordnung</option>
          <option v-for="x in extList" :key="x.id" :value="x.id">{{ x.label ? `${x.label} (${x.id})` : x.id }}</option>
        </select>
        <span v-if="map[m.key] && map[m.key].confirmed && settings.marketMap[m.key] && settings.marketMap[m.key].ext === map[m.key].ext" class="small ok">Bestätigt</span>
        <button v-else class="primary" :disabled="!map[m.key]" @click="confirm(m.key)">Bestätigen</button>
      </div>
      <p class="small muted">Preise von AHledger werden mit Quellenangabe gezeigt und nie als eigener Scan ausgegeben. <button class="link" @click="api.openLink(data.ahledger.link)">ahledger.com</button></p>
    </section>

    <BlizzardCheck :now="now" @state="blizzard = $event" />
  </div>
</template>

<style scoped>
.src { display: grid; gap: 36px; max-width: 980px; }
.block { display: grid; gap: 12px; }
.lead { max-width: 72ch; }
.head { display: flex; justify-content: space-between; align-items: center; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 10px 6px 0; border-bottom: 1px solid var(--line); }
.tbl td { padding: 9px 10px 9px 0; border-bottom: 1px solid var(--line-soft); vertical-align: top; }
.map-row { display: grid; grid-template-columns: minmax(220px, 1fr) minmax(280px, 1.4fr) auto; gap: 14px; align-items: center; padding: 8px 0; border-bottom: 1px solid var(--line-soft); }
.mkey { font-weight: 500; }
.ok { color: var(--accent); }
.warn { color: var(--warn); }
</style>
