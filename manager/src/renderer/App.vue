<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import Overview from './views/Overview.vue';
import Sources from './views/Sources.vue';
import Settings from './views/Settings.vue';
import Items from './views/Items.vue';
import Item from './views/Item.vue';
import Chances from './views/Chances.vue';
import Modules from './views/Modules.vue';
import Reports from './views/Reports.vue';
import UpdateDialog from './components/UpdateDialog.vue';
import QuickSearch from './components/QuickSearch.vue';
import Watch from './views/Watch.vue';
import { ago } from './util.js';

const api = window.peon;
const view = ref('overview');
const data = ref(null);
const settings = ref(null);
const market = ref(null);
const busy = ref(false);
const note = ref('');
const now = ref(Math.floor(Date.now() / 1000));
const itemKey = ref(null);
const stamp = ref(0);   // erhoeht sich bei neuen Daten, damit Listen neu laden
const updates = ref(null);        // Inhalt des Update-Fensters
const showUpdates = ref(false);
let startChecked = false;
async function closeUpdates() {
  showUpdates.value = false;
  await api.updatesShown();
}

// Ansichten der Manager-Module, je aktives Modul eine Gruppe mit Ueberschrift. Dazu immer Updates, Rueckmeldungen und Einstellungen
const ALL = [
  { key: 'overview', label: 'Übersicht' },
  { key: 'items', label: 'Gegenstände' },
  { key: 'chances', label: 'Chancen' },
  { key: 'watch', label: 'Merkliste' },
  { key: 'sources', label: 'Quellen' },
  { key: 'modules', label: 'Updates', always: true },
  { key: 'reports', label: 'Rückmeldungen', always: true },
  { key: 'settings', label: 'Einstellungen', always: true },
];
const GROUPS = computed(() => (data.value ? data.value.modules.filter((m) => m.enabled).map((m) => ({
  key: m.key, title: m.navTitle || m.title, views: ALL.filter((n) => m.views.includes(n.key)),
})) : []));
const NAV_BOTTOM = ALL.filter((n) => n.always);
const broker = computed(() => !!(data.value && data.value.views.includes('overview')));
// Markt und "Jetzt einlesen" gehoeren zum Broker und stehen nur bei seinen Reitern
const inBroker = computed(() => broker.value && (view.value === 'item' || data.value.views.includes(view.value)));
// Schnellsuche: alle Seiten, die gerade da sind
const PAGES = computed(() => ALL.filter((n) => n.always || (data.value && data.value.views.includes(n.key))));
const searching = ref(false);
function onGlobalKey(e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); searching.value = !searching.value; }
}
onMounted(() => window.addEventListener('keydown', onGlobalKey));
onBeforeUnmount(() => window.removeEventListener('keydown', onGlobalKey));

const current = computed(() => {
  const ms = data.value ? data.value.markets : [];
  return ms.find((m) => m.key === market.value) || ms[0] || null;
});

async function load() {
  const [o, s, u] = await Promise.all([api.overview(), api.settings(), api.updateInfo()]);
  data.value = o;
  settings.value = s;
  updates.value = u;
  // Von selbst nur einmal beim Programmstart, nach der ersten Suche. Die Suche alle 6 Stunden zeigt nur den Knopf.
  if (u.ready && !startChecked) {
    startChecked = true;
    if (u.popup) showUpdates.value = true;
  }
  if (!market.value && o.markets.length) market.value = o.markets[0].key;
  // Ansicht eines entfernten Moduls: zu den Modulen wechseln. Beim Start ohne Modul gleich dorthin.
  const ok = ALL.some((n) => n.key === view.value && (n.always || o.views.includes(n.key))) || (view.value === 'item' && o.views.includes('items'));
  if (!ok) view.value = o.views.includes('overview') ? 'overview' : 'modules';
  stamp.value++;
  document.documentElement.dataset.theme = s.theme === 'light' ? 'light' : 'dark';
}

async function importNow() {
  busy.value = true;
  try {
    const r = await api.importNow();
    if (!r) note.value = 'Einlesen läuft schon.';
    else if (r.error && !r.files) note.value = r.error;
    else if (r.error) note.value = 'Keine Peon_Bridge.lua gefunden. Stimmt der WoW-Ordner in den Einstellungen?';
    else if (r.failed && r.failed.length) note.value = `${r.imported} neu, ${r.failed.length} mit Fehler (siehe Protokoll).`;
    else note.value = r.imported ? `${r.imported} ${r.imported === 1 ? 'neue Momentaufnahme' : 'neue Momentaufnahmen'} übernommen.` : 'Nichts Neues im Spiel.';
    await load();
  } finally { busy.value = false; }
}

const back = ref('items');
function openItem(key) { back.value = view.value === 'item' ? back.value : view.value; itemKey.value = key; view.value = 'item'; }
const BACK_LABEL = { chances: 'Zurück zu Chancen', watch: 'Zurück zur Merkliste', overview: 'Zurück zur Übersicht', sources: 'Zurück zu den Quellen', modules: 'Zurück zu den Updates', reports: 'Zurück zu den Rückmeldungen', settings: 'Zurück zu den Einstellungen' };
function go(v) { view.value = v; if (v !== 'item') itemKey.value = null; }

async function pickWow() {
  const p = await api.pickFolder();
  if (p) await saveSettings({ wowDir: p });
}

// Filter der Chancen merken, ohne alles neu zu laden
async function saveQuiet(patch) { settings.value = await api.saveSettings(patch); }

async function saveSettings(patch) {
  settings.value = await api.saveSettings(patch);
  await load();
}

onMounted(() => {
  load();
  api.onChanged(() => load());
  // Klick auf die Meldung eines Preisalarms
  api.onOpenItem(({ market: mk, key }) => { market.value = mk; openItem(key); });
  setInterval(() => { now.value = Math.floor(Date.now() / 1000); }, 30000);
});
watch(note, (v) => { if (v) setTimeout(() => { if (note.value === v) note.value = ''; }, 6000); });
</script>

<template>
  <div class="shell">
    <nav class="rail">
      <div class="mark">
        <svg viewBox="0 0 32 32" width="28" height="28" aria-hidden="true">
          <circle cx="16" cy="16" r="13" fill="none" stroke="var(--accent)" stroke-width="2.5" />
          <path d="M11 22V10h6a4 4 0 0 1 0 8h-6" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linejoin="round" />
        </svg>
        <span>Peon Manager</span>
      </div>
      <div v-for="g in GROUPS" :key="g.key" class="group" role="group" :aria-label="g.title">
        <div class="group-title">{{ g.title }}</div>
        <button v-for="n in g.views" :key="n.key" class="nav" :class="{ on: view === n.key || (n.key === back && view === 'item') }" @click="go(n.key)">{{ n.label }}</button>
      </div>
      <div class="rail-bottom">
        <button class="primary rail-update" v-if="updates && updates.count" @click="showUpdates = true">
          {{ updates.manager || updates.addons.some((a) => a.kind === 'update') ? 'Jetzt aktualisieren' : 'Neues ansehen' }}<span class="rail-count">{{ updates.count }}</span>
        </button>
        <button v-for="n in NAV_BOTTOM" :key="n.key" class="nav" :class="{ on: view === n.key }" @click="go(n.key)">
          {{ n.label }}<span v-if="n.key === 'modules' && updates && updates.count" class="count" :title="`${updates.count} verfügbar`">{{ updates.count }}</span>
          <span v-if="n.key === 'reports' && data && data.reportCount" class="count" :title="`${data.reportCount} noch nicht gesendet`">{{ data.reportCount }}</span>
        </button>
        <div class="rail-foot faint small" v-if="data">Version {{ data.version }}</div>
      </div>
    </nav>

    <main class="main">
      <header class="top" v-if="data && inBroker">
        <div class="market">
          <select v-if="data.markets.length > 1" v-model="market" aria-label="Markt">
            <option v-for="m in data.markets" :key="m.key" :value="m.key">{{ m.key }}</option>
          </select>
          <span v-else-if="current" class="market-name">{{ current.key }}</span>
          <span v-else class="muted">Noch kein Markt</span>
        </div>
        <div class="top-right">
          <span class="note small" v-if="note" role="status">{{ note }}</span>
          <span class="small muted" v-if="current && current.lastScan">{{ current.lastScan.art === 'api' ? 'Letzter Stand' : 'Letzter Scan' }} {{ ago(current.lastScan.t, now) }}</span>
          <button class="search small" @click="searching = true" title="Schnellsuche">Suchen <kbd>Strg+K</kbd></button>
          <button class="primary" :disabled="busy" @click="importNow">{{ busy ? 'Liest ein' : 'Jetzt einlesen' }}</button>
        </div>
      </header>

      <div class="page" v-if="data && settings">
        <Overview v-if="view === 'overview'" :data="data" :market="current" :now="now" :theme="settings.theme" :stamp="stamp" :settings="settings" @import="importNow" @go="go($event)" @open="openItem" @save="saveSettings" />
        <Items v-else-if="view === 'items'" :market="current" :now="now" :stamp="stamp" @open="openItem" />
        <Item v-else-if="view === 'item'" :market="current" :item-key="itemKey" :now="now" :theme="settings.theme" :stamp="stamp" @back="go(back)" :back-label="BACK_LABEL[back] || 'Alle Gegenstände'" />
        <Chances v-else-if="view === 'chances'" :market="current" :now="now" :stamp="stamp" :settings="settings" @open="openItem" @save="saveQuiet" />
        <Watch v-else-if="view === 'watch'" :market="current" :stamp="stamp" :settings="settings" @open="openItem" @save="saveQuiet" @go="go($event)" />
        <Sources v-else-if="view === 'sources'" :data="data" :market="current" :now="now" :stamp="stamp" @go="go($event)" />
        <Modules v-else-if="view === 'modules'" :data="data" :settings="settings" :now="now" :stamp="stamp" @changed="load" @save="saveSettings" @pick-folder="pickWow" @go="go($event)" @updates="load().then(() => { showUpdates = true; })" />
        <Reports v-else-if="view === 'reports'" :now="now" :stamp="stamp" @go="go($event)" @changed="load" />
        <Settings v-else-if="view === 'settings'" :data="data" :settings="settings" :stamp="stamp" :broker="broker" :now="now" @save="saveSettings" />
      </div>
      <div class="page muted" v-else>Lade Daten</div>
    </main>
    <QuickSearch v-if="searching" :market="current" :pages="PAGES" @close="searching = false" @open="openItem" @go="go($event)" />
    <UpdateDialog v-if="showUpdates && updates && settings" :info="updates" :settings="settings" @close="closeUpdates" @changed="load" @save="saveQuiet" />
  </div>
</template>

<style scoped>
.shell { display: grid; grid-template-columns: 196px 1fr; grid-template-rows: minmax(0, 1fr); height: 100%; }
.rail { background: var(--panel); border-right: 1px solid var(--line-soft); display: flex; flex-direction: column; padding: 18px 12px; gap: 2px; }
.mark { display: flex; align-items: center; gap: 10px; padding: 0 8px 22px; font-family: var(--font-cond); font-weight: 600; font-size: 18px; }
.nav { text-align: left; background: none; border: none; border-left: 3px solid transparent; border-radius: 0 var(--radius-s) var(--radius-s) 0;
  padding: 9px 12px; color: var(--muted); font-weight: 500; display: flex; justify-content: space-between; align-items: center; }
.nav:hover { color: var(--text); background: var(--line-soft); }
.nav.on { color: var(--text); border-left-color: var(--accent); background: var(--accent-soft); }
.group { display: flex; flex-direction: column; gap: 2px; margin-bottom: 12px; padding: 8px 6px; background: var(--raised); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.group-title { padding: 0 8px 6px; font-family: var(--font-cond); font-weight: 600; font-size: 14px; color: var(--text); }
.search kbd { font: inherit; color: var(--faint); margin-left: 6px; }
.count { font-size: 12px; font-weight: 600; min-width: 18px; padding: 0 5px; border-radius: 9px; text-align: center; background: var(--accent); color: var(--accent-ink); }
.rail-bottom { margin-top: auto; display: flex; flex-direction: column; gap: 2px; }
.rail-update { display: flex; justify-content: space-between; align-items: center; gap: 6px; margin-bottom: 10px; padding: 8px 10px; text-align: left; }
.rail-count { font-size: 12px; font-weight: 600; min-width: 18px; padding: 0 5px; border-radius: 9px; text-align: center; background: var(--accent-ink); color: var(--accent); }
.rail-sep { width: 100%; border: none; border-top: 1px solid var(--line-soft); margin: 0 0 8px; }
.rail-foot { padding: 12px 12px 0; }
.main { display: flex; flex-direction: column; min-width: 0; height: 100%; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 14px 28px; border-bottom: 1px solid var(--line-soft); }
.market-name { font-family: var(--font-cond); font-weight: 500; font-size: 17px; }
.top-right { display: flex; align-items: center; gap: 16px; }
.note { color: var(--accent); }
.page { padding: 26px 28px 40px; overflow: auto; flex: 1; display: flex; flex-direction: column; }
.page > * { flex: none; }
.page > .items { flex: 1; min-height: 0; }
</style>
