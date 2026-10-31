<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import Overview from './views/Overview.vue';
import Sources from './views/Sources.vue';
import Settings from './views/Settings.vue';
import Items from './views/Items.vue';
import Item from './views/Item.vue';
import Chances from './views/Chances.vue';
import Modules from './views/Modules.vue';
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

// Ansichten der Manager-Module (nur wenn das Modul installiert ist), dazu immer Module und Einstellungen
const ALL = [
  { key: 'overview', label: 'Übersicht' },
  { key: 'items', label: 'Gegenstände' },
  { key: 'chances', label: 'Chancen' },
  { key: 'sources', label: 'Quellen' },
  { key: 'modules', label: 'Module', always: true },
  { key: 'settings', label: 'Einstellungen', always: true },
];
const NAV = computed(() => ALL.filter((n) => n.always || (data.value && data.value.views.includes(n.key))));
const broker = computed(() => !!(data.value && data.value.views.includes('overview')));

const current = computed(() => {
  const ms = data.value ? data.value.markets : [];
  return ms.find((m) => m.key === market.value) || ms[0] || null;
});

async function load() {
  const [o, s] = await Promise.all([api.overview(), api.settings()]);
  data.value = o;
  settings.value = s;
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
function go(v) { view.value = v; if (v !== 'item') itemKey.value = null; }

// Filter der Chancen merken, ohne alles neu zu laden
async function saveQuiet(patch) { settings.value = await api.saveSettings(patch); }

async function saveSettings(patch) {
  settings.value = await api.saveSettings(patch);
  await load();
}

onMounted(() => {
  load();
  api.onChanged(() => load());
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
      <button v-for="n in NAV" :key="n.key" class="nav" :class="{ on: view === n.key || (n.key === back && view === 'item') }" :disabled="n.soon"
        @click="go(n.key)" :title="n.soon ? 'Folgt in einer späteren Version' : ''">
        {{ n.label }}<span v-if="n.soon" class="soon">folgt</span>
      </button>
      <div class="rail-foot faint small" v-if="data">Version {{ data.version }}</div>
    </nav>

    <main class="main">
      <header class="top" v-if="data && broker">
        <div class="market">
          <select v-if="data.markets.length > 1" v-model="market" aria-label="Markt">
            <option v-for="m in data.markets" :key="m.key" :value="m.key">{{ m.key }}</option>
          </select>
          <span v-else-if="current" class="market-name">{{ current.key }}</span>
          <span v-else class="muted">Noch kein Markt</span>
        </div>
        <div class="top-right">
          <span class="note small" v-if="note" role="status">{{ note }}</span>
          <span class="small muted" v-if="current && current.lastScan">Letzter Scan {{ ago(current.lastScan.t, now) }}</span>
          <button class="primary" :disabled="busy" @click="importNow">{{ busy ? 'Liest ein' : 'Jetzt einlesen' }}</button>
        </div>
      </header>

      <div class="page" v-if="data && settings">
        <Overview v-if="view === 'overview'" :data="data" :market="current" :now="now" :theme="settings.theme" @import="importNow" @go="go($event)" @open="openItem" />
        <Items v-else-if="view === 'items'" :market="current" :now="now" :stamp="stamp" @open="openItem" />
        <Item v-else-if="view === 'item'" :market="current" :item-key="itemKey" :now="now" :theme="settings.theme" :stamp="stamp" @back="go(back === 'chances' ? 'chances' : 'items')" :back-label="back === 'chances' ? 'Zurück zu Chancen' : 'Alle Gegenstände'" />
        <Chances v-else-if="view === 'chances'" :market="current" :now="now" :stamp="stamp" :settings="settings" @open="openItem" @save="saveQuiet" />
        <Sources v-else-if="view === 'sources'" :data="data" :settings="settings" :now="now" @save="saveSettings" />
        <Modules v-else-if="view === 'modules'" :data="data" @changed="load" />
        <Settings v-else-if="view === 'settings'" :data="data" :settings="settings" :stamp="stamp" :broker="broker" @save="saveSettings" />
      </div>
      <div class="page muted" v-else>Lade Daten</div>
    </main>
  </div>
</template>

<style scoped>
.shell { display: grid; grid-template-columns: 196px 1fr; height: 100%; }
.rail { background: var(--panel); border-right: 1px solid var(--line-soft); display: flex; flex-direction: column; padding: 18px 12px; gap: 2px; }
.mark { display: flex; align-items: center; gap: 10px; padding: 0 8px 22px; font-family: var(--font-cond); font-weight: 600; font-size: 18px; }
.nav { text-align: left; background: none; border: none; border-left: 3px solid transparent; border-radius: 0 var(--radius-s) var(--radius-s) 0;
  padding: 9px 12px; color: var(--muted); font-weight: 500; display: flex; justify-content: space-between; align-items: center; }
.nav:hover:not(:disabled) { color: var(--text); background: var(--raised); }
.nav.on { color: var(--text); border-left-color: var(--accent); background: var(--accent-soft); }
.nav:disabled { opacity: 1; color: var(--faint); }
.soon { font-size: 12px; color: var(--faint); font-weight: 400; }
.rail-foot { margin-top: auto; padding: 0 12px; }
.main { display: flex; flex-direction: column; min-width: 0; height: 100%; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 14px 28px; border-bottom: 1px solid var(--line-soft); }
.market-name { font-family: var(--font-cond); font-weight: 500; font-size: 17px; }
.top-right { display: flex; align-items: center; gap: 16px; }
.note { color: var(--accent); }
.page { padding: 26px 28px 40px; overflow: auto; flex: 1; display: flex; flex-direction: column; }
.page > * { flex: none; }
.page > .items { flex: 1; min-height: 0; }
</style>
