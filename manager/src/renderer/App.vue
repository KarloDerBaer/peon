<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, watch, nextTick, KeepAlive } from 'vue';
import Overview from './views/Overview.vue';
import Sources from './views/Sources.vue';
import Settings from './views/Settings.vue';
import Items from './views/Items.vue';
import Item from './views/Item.vue';
import Chances from './views/Chances.vue';
import Market from './views/Market.vue';
import Success from './views/Success.vue';
import Brief from './views/Brief.vue';
import Modules from './views/Modules.vue';
import Reports from './views/Reports.vue';
import Shopping from './views/Shopping.vue';
import Vendors from './views/Vendors.vue';
import Watch from './views/Watch.vue';
import UpdateDialog from './components/UpdateDialog.vue';
import Star from './components/Star.vue';
import { ago, qualityColor } from './util.js';
import { loadFavorites } from './store.js';

const api = window.peon;
const view = ref('overview');
const data = ref(null);
const settings = ref(null);
const market = ref(null);
const now = ref(Math.floor(Date.now() / 1000));
const itemKey = ref(null);
const origin = ref('items');      // Reiter, an dem der offene Gegenstand haengt
const stamp = ref(0);   // erhoeht sich bei neuen Daten, damit Listen neu laden
const updates = ref(null);        // Inhalt des Update-Fensters
const showUpdates = ref(false);
const pageEl = ref(null);
let startChecked = false;
async function closeUpdates() {
  showUpdates.value = false;
  await api.updatesShown();
}

// Ansichten der Manager-Module, je aktives Modul eine Gruppe mit Ueberschrift. Dazu immer Updates, Rueckmeldungen und Einstellungen
const ALL = [
  // ab 0.26.0 (Neuaufbau H5): Seiten und Reihenfolge wie im Spiel (Markt, Einkaufen mit Beobachtung, Radar, Mehr)
  { key: 'overview', label: 'Übersicht' },
  { key: 'items', label: 'Markt' },
  // ab 0.28.0 (KarloDerBaer): Einkaufen, Beobachtung, Radar und Händler muessen ueberarbeitet werden, nur ein Hinweis
  { key: 'shopping', label: 'Einkaufen' },   // ab 0.33.0 neu (A5)
  { key: 'favorites', label: 'Beobachten' },   // ab 0.32.0 neu (A4), Name wie im Spiel
  // ab 0.35.0 (Peon_Manager_Chancen.md): Chancen ersetzen Radar (WIP), dazu Marktuebersicht und Erfolgskontrolle
  { key: 'chances', label: 'Chancen' },
  { key: 'market', label: 'Marktübersicht' },
  { key: 'success', label: 'Erfolgskontrolle' },
  { key: 'vendors', label: 'Händler (WIP)', wip: true },
  { key: 'sources', label: 'Datenlage' },
  { key: 'modules', label: 'Updates', always: true },
  { key: 'reports', label: 'Rückmeldungen', always: true },
  { key: 'settings', label: 'Einstellungen', always: true },
];
const GROUPS = computed(() => (data.value ? data.value.modules.filter((m) => m.enabled).map((m) => ({
  key: m.key, title: m.navTitle || m.title, views: ALL.filter((n) => m.views.includes(n.key)),
})) : []));
const NAV_BOTTOM = ALL.filter((n) => n.always);
const watchFocus = ref(null);   // ab 0.32.0: Zeile, die Beobachten nach einer Meldung zeigt
const wipPage = computed(() => ALL.find((n) => n.wip && n.key === view.value) || null);
const broker = computed(() => !!(data.value && data.value.views.includes('overview')));

const current = computed(() => {
  const ms = data.value ? data.value.markets : [];
  return ms.find((m) => m.key === market.value) || ms[0] || null;
});
// Gleicher Anzeigename bei zwei Maerkten: Der interne Name unterscheidet sie
const marketOptions = computed(() => {
  const ms = data.value ? data.value.markets : [];
  return ms.map((m) => ({ key: m.key, label: ms.filter((x) => x.label === m.label).length > 1 ? `${m.label} (${m.key.split(' / ')[0]})` : m.label }));
});
function pickMarket(key) {
  market.value = key;
  if (entries.value[pos.value]) entries.value[pos.value].market = key;
  saveQuiet({ market: key });
}

// ---------- Navigation: Verlauf wie im Browser ----------
const ORIGINS = new Set(['overview', 'items', 'favorites', 'shopping', 'chances', 'market', 'success']);
const entries = ref([{ view: 'overview' }]);
const pos = ref(0);
const canBack = computed(() => pos.value > 0);
const canForward = computed(() => pos.value < entries.value.length - 1);
// Untertabs: je Reiter hoechstens ein offener Gegenstand
const subs = reactive({});
const scrolls = {};
const seenStamp = {};
// Neue Daten laden nur die Ansicht, die gerade zu sehen ist. Beim Zurueckkommen holt sie nach, was sie verpasst hat.
function stampOf(v) { if (view.value === v) seenStamp[v] = stamp.value; return seenStamp[v] ?? stamp.value; }

function show(e) {
  if (pageEl.value) scrolls[view.value] = pageEl.value.scrollTop;
  view.value = e.view;
  itemKey.value = e.view === 'item' || e.view === 'brief' ? e.itemKey : null;
  if (e.view === 'item') {
    origin.value = e.origin;
    subs[e.origin] = { key: e.itemKey, name: subs[e.origin] && subs[e.origin].key === e.itemKey ? subs[e.origin].name : null, quality: subs[e.origin] && subs[e.origin].key === e.itemKey ? subs[e.origin].quality : null };
  }
  if (e.market) market.value = e.market;
  nextTick(() => { if (pageEl.value) pageEl.value.scrollTop = e.view === 'item' || e.view === 'brief' ? 0 : scrolls[e.view] || 0; });
}
function push(e) {
  const entry = { market: market.value, ...e };
  const cur = entries.value[pos.value];
  if (cur && cur.view === entry.view && cur.itemKey === entry.itemKey) { show(entry); return; }
  entries.value = [...entries.value.slice(0, pos.value + 1), entry].slice(-100);
  pos.value = entries.value.length - 1;
  show(entry);
}
function back() { if (canBack.value) { pos.value--; show(entries.value[pos.value]); } }
function forward() { if (canForward.value) { pos.value++; show(entries.value[pos.value]); } }
function go(v) { push({ view: v }); }
function openItem(key) {
  const from = view.value === 'item' ? origin.value : ORIGINS.has(view.value) ? view.value : 'items';
  push({ view: 'item', itemKey: key, origin: from });
}
// Steckbrief (ab 0.35.0): eigene Seite mit Gegenstand, Zurueck fuehrt dorthin, woher man kam
function openBrief(key) { push({ view: 'brief', itemKey: key }); }
function openSub(o) { push({ view: 'item', itemKey: subs[o].key, origin: o }); }
function closeSub(o) {
  const open = view.value === 'item' && origin.value === o;
  subs[o] = null;
  if (open) go(o);
}
function itemLoaded(d) {
  const s = subs[origin.value];
  if (s && s.key === d.key) { s.name = d.name || `Gegenstand ${d.item}`; s.quality = d.quality; }
}
function onKey(e) {
  if (!e.altKey) return;
  if (e.key === 'ArrowLeft') { e.preventDefault(); back(); }
  if (e.key === 'ArrowRight') { e.preventDefault(); forward(); }
}
function onMouse(e) {
  if (e.button === 3) { e.preventDefault(); back(); }
  if (e.button === 4) { e.preventDefault(); forward(); }
}
onMounted(() => { window.addEventListener('keydown', onKey); window.addEventListener('mouseup', onMouse); });
onBeforeUnmount(() => { window.removeEventListener('keydown', onKey); window.removeEventListener('mouseup', onMouse); });

// ---------- Hinweis in der Kopfleiste: Was hat das Spiel noch nicht? ----------
const sync = computed(() => (data.value && data.value.sync) || null);
const syncNote = computed(() => {
  const x = sync.value;
  if (!x) return null;
  const n = x.inputs === 1 ? '1 Eingabe' : `${x.inputs} Eingaben`;
  if (x.inputs && x.running) return { warn: true, text: `${n} warten, im Spiel /reload`, tip: 'Das Spiel liest die Daten des Managers nur beim Laden. Nach /reload sind sie im Spiel.' };
  if (x.inputs) return { warn: false, text: `${n} kommen beim nächsten Start ins Spiel`, tip: 'Der Manager hat alles bereitgelegt, du musst nichts tun.' };
  if (x.values && x.running) return { warn: false, text: 'Neue Preiswerte nach /reload im Spiel', tip: 'Broker rechnet bis dahin mit den letzten Werten weiter.' };
  return null;
});

async function load() {
  const [o, s, u] = await Promise.all([api.overview(), api.settings(), api.updateInfo()]);
  data.value = o;
  settings.value = s;
  updates.value = u;
  // Von selbst nur einmal beim Programmstart, nach der ersten Suche. Die Suche im eingestellten Abstand zeigt nur den Knopf und meldet sich ueber Windows.
  if (u.ready && !startChecked) {
    startChecked = true;
    if (u.popup) showUpdates.value = true;
  }
  if (!market.value && o.markets.length) market.value = (o.markets.find((m) => m.key === s.market) || o.markets[0]).key;
  // Ansicht eines entfernten Moduls: zu den Modulen wechseln. Beim Start ohne Modul gleich dorthin.
  const ok = ALL.some((n) => n.key === view.value && (n.always || o.views.includes(n.key))) || (view.value === 'item' && o.views.includes('items'));
  if (!ok) go(o.views.includes('overview') ? 'overview' : 'modules');
  if (o.views.includes('favorites')) await loadFavorites();
  stamp.value++;
  document.documentElement.dataset.theme = s.theme === 'light' ? 'light' : 'dark';
}

async function pickWow() {
  const p = await api.pickFolder();
  if (p) await saveSettings({ wowDir: p });
}

// Filter und Auswahl merken, ohne alles neu zu laden
async function saveQuiet(patch) { settings.value = await api.saveSettings(patch); }

async function saveSettings(patch) {
  settings.value = await api.saveSettings(patch);
  await load();
}

onMounted(() => {
  load();
  api.onChanged(() => load());
  // Klick auf die Meldung der Einkaufsliste
  api.onOpenUpdates(() => load().then(() => { showUpdates.value = true; }));
  api.onOpenItem(({ market: mk, key }) => { market.value = mk; push({ view: 'item', itemKey: key, origin: 'shopping' }); });
  // Klick auf die Meldung von Beobachten (ab 0.32.0): Seite Beobachten mit der Zeile
  api.onOpenWatch(({ market: mk, key }) => { market.value = mk; watchFocus.value = { key, at: Date.now() }; go('favorites'); load(); });
  setInterval(() => { now.value = Math.floor(Date.now() / 1000); }, 30000);
});
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
        <select v-if="g.key === 'broker-client' && marketOptions.length > 1" class="market small" :value="current && current.key" aria-label="Markt" @change="pickMarket($event.target.value)">
          <option v-for="m in marketOptions" :key="m.key" :value="m.key">{{ m.label }}</option>
        </select>
        <template v-for="n in g.views" :key="n.key">
          <button class="nav" :class="{ on: view === n.key, parent: view === 'item' && origin === n.key }" @click="go(n.key)">{{ n.label }}</button>
          <div v-if="subs[n.key]" class="sub" :class="{ on: view === 'item' && origin === n.key }">
            <Star :item-key="subs[n.key].key" :size="14" />
            <button class="sub-name" :style="{ color: qualityColor(subs[n.key].quality) }" :title="subs[n.key].name || ''" @click="openSub(n.key)">{{ subs[n.key].name || 'Lade' }}</button>
            <button class="sub-x" aria-label="Untertab schließen" title="Schließen" @click="closeSub(n.key)">×</button>
          </div>
        </template>
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
      <header class="top" v-if="data">
        <div class="arrows">
          <button class="arrow" :disabled="!canBack" aria-label="Zurück" title="Zurück (Alt+Pfeil links)" @click="back">
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" /></svg>
          </button>
          <button class="arrow" :disabled="!canForward" aria-label="Vor" title="Vor (Alt+Pfeil rechts)" @click="forward">
            <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" /></svg>
          </button>
        </div>
        <div class="top-right" v-if="broker">
          <span v-if="syncNote" class="sync small" :class="{ warn: syncNote.warn }" :title="syncNote.tip" role="status">{{ syncNote.text }}</span>
          <span class="small muted" v-if="current && current.lastScan">{{ current.lastScan.art === 'api' ? 'Letzter Stand' : 'Letzter Scan' }} {{ ago(current.lastScan.t, now) }}</span>
        </div>
      </header>

      <div class="page" ref="pageEl" v-if="data && settings">
        <KeepAlive :include="['Overview', 'Items', 'Chances', 'Shopping', 'Watch', 'Market']">
          <Overview v-if="view === 'overview'" :data="data" :market="current" :now="now" :theme="settings.theme" :stamp="stampOf('overview')" :settings="settings" @go="go($event)" @open="openItem" @save="saveSettings" />
          <section v-else-if="wipPage" class="wip">
            <h1>{{ wipPage.label }}</h1>
            <p class="wip-note">Überarbeitung notwendig! Derzeit nur im Spiel verfügbar.</p>
          </section>
          <Items v-else-if="view === 'items'" key="items" :market="current" :now="now" :stamp="stampOf('items')" :settings="settings" @open="openItem" @save="saveQuiet" />
          <Watch v-else-if="view === 'favorites'" :market="current" :now="now" :stamp="stampOf('favorites')" :settings="settings" :focus="watchFocus" @open="openItem" @save="saveQuiet" @go="go($event)" />
          <Shopping v-else-if="view === 'shopping'" :market="current" :now="now" :stamp="stampOf('shopping')" :settings="settings" @open="openItem" @save="saveQuiet" @go="go($event)" />
          <Vendors v-else-if="view === 'vendors'" :market="current" :now="now" :stamp="stampOf('vendors')" @open="openItem" />
          <Item v-else-if="view === 'item'" :market="current" :item-key="itemKey" :now="now" :theme="settings.theme" :stamp="stamp" @loaded="itemLoaded" @go="go($event)" @open="openItem" @brief="openBrief" />
          <Chances v-else-if="view === 'chances'" :market="current" :now="now" :stamp="stampOf('chances')" :settings="settings" @open="openItem" @brief="openBrief" @save="saveQuiet" />
          <Market v-else-if="view === 'market'" :market="current" :now="now" :stamp="stampOf('market')" @open="openItem" @brief="openBrief" />
          <Success v-else-if="view === 'success'" :market="current" :now="now" :stamp="stampOf('success')" @open="openItem" @brief="openBrief" />
          <Brief v-else-if="view === 'brief'" :market="current" :item-key="itemKey" :now="now" :stamp="stamp" :theme="settings.theme" @open="openItem" />
          <Sources v-else-if="view === 'sources'" :data="data" :market="current" :now="now" :stamp="stamp" @go="go($event)" />
          <Modules v-else-if="view === 'modules'" :data="data" :settings="settings" :now="now" :stamp="stamp" @changed="load" @save="saveSettings" @pick-folder="pickWow" @go="go($event)" @updates="load().then(() => { showUpdates = true; })" />
          <Reports v-else-if="view === 'reports'" :now="now" :stamp="stamp" @go="go($event)" @changed="load" />
          <Settings v-else-if="view === 'settings'" :data="data" :settings="settings" :stamp="stamp" :broker="broker" :now="now" @save="saveSettings" @go="go($event)" />
        </KeepAlive>
      </div>
      <div class="page muted" v-else>Lade Daten</div>
    </main>
    <UpdateDialog v-if="showUpdates && updates && settings" :info="updates" :settings="settings" @close="closeUpdates" @changed="load" @save="saveQuiet" />
  </div>
</template>

<style scoped>
.wip { display: grid; gap: 12px; }
.wip h1 { margin: 0; }
.wip-note { margin: 0; padding: 12px 14px; border: 1px solid var(--warn); border-radius: var(--radius-s); color: var(--warn); font-weight: 500; }
.shell { display: grid; grid-template-columns: 196px 1fr; grid-template-rows: minmax(0, 1fr); height: 100%; }
.rail { background: var(--panel); border-right: 1px solid var(--line-soft); display: flex; flex-direction: column; padding: 18px 12px; gap: 2px; }
.mark { display: flex; align-items: center; gap: 10px; padding: 0 8px 22px; font-family: var(--font-cond); font-weight: 600; font-size: 18px; }
.nav { text-align: left; background: none; border: none; border-left: 3px solid transparent; border-radius: 0 var(--radius-s) var(--radius-s) 0;
  padding: 9px 12px; color: var(--muted); font-weight: 500; display: flex; justify-content: space-between; align-items: center; }
.nav:hover { color: var(--text); background: var(--line-soft); }
.nav.on { color: var(--text); border-left-color: var(--accent); background: var(--accent-soft); }
.group { display: flex; flex-direction: column; gap: 2px; margin-bottom: 12px; padding: 8px 6px; background: var(--raised); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.group-title { padding: 0 8px 6px; font-family: var(--font-cond); font-weight: 600; font-size: 14px; color: var(--text); }
.nav.parent { color: var(--text); border-left-color: var(--line); }
.market { margin: 0 2px 6px; width: calc(100% - 4px); }
.sub { display: flex; align-items: center; gap: 4px; margin: 0 0 2px 10px; padding: 3px 4px 3px 6px; border-left: 3px solid var(--line); min-width: 0; }
.sub.on { border-left-color: var(--accent); background: var(--accent-soft); border-radius: 0 var(--radius-s) var(--radius-s) 0; }
.sub-name { flex: 1; min-width: 0; background: none; border: none; padding: 0; text-align: left; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sub-name:hover { text-decoration: underline; }
.sub-x { background: none; border: none; padding: 0 3px; color: var(--faint); line-height: 1; font-size: 15px; }
.sub-x:hover { color: var(--text); }
.count { font-size: 12px; font-weight: 600; min-width: 18px; padding: 0 5px; border-radius: 9px; text-align: center; background: var(--accent); color: var(--accent-ink); }
.rail-bottom { margin-top: auto; display: flex; flex-direction: column; gap: 2px; }
.rail-update { display: flex; justify-content: space-between; align-items: center; gap: 6px; margin-bottom: 10px; padding: 8px 10px; text-align: left; }
.rail-count { font-size: 12px; font-weight: 600; min-width: 18px; padding: 0 5px; border-radius: 9px; text-align: center; background: var(--accent-ink); color: var(--accent); }
.rail-sep { width: 100%; border: none; border-top: 1px solid var(--line-soft); margin: 0 0 8px; }
.rail-foot { padding: 12px 12px 0; }
.main { display: flex; flex-direction: column; min-width: 0; height: 100%; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 16px; padding: 10px 28px; border-bottom: 1px solid var(--line-soft); min-height: 52px; }
.arrows { display: flex; gap: 4px; }
.arrow { display: inline-flex; padding: 6px; }
.sync { padding: 3px 10px; color: var(--muted); border: 1px solid var(--line); border-radius: var(--radius-s); }
.sync.warn { color: var(--warn); border-color: var(--warn); }
.top-right { display: flex; align-items: center; gap: 16px; }
.page { padding: 26px 28px 40px; overflow: auto; flex: 1; display: flex; flex-direction: column; }
.page > * { flex: none; }
.page > .items { flex: 1; min-height: 0; }
</style>
