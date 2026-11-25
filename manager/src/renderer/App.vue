<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, watch, nextTick, KeepAlive } from 'vue';
import Today from './views/Today.vue';   // ab 0.56.0: Startseite Heute (Peon_Manager_Schlank.md Abschnitt 4)
import Items from './views/Items.vue';
import Sources from './views/Sources.vue';
import Settings from './views/Settings.vue';
import Help from './views/Help.vue';
import Item from './views/Item.vue';
import Chances from './views/Chances.vue';
import Compare from './views/Compare.vue';   // ab 0.50.0
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
const view = ref('today');
const data = ref(null);
const settings = ref(null);
const market = ref(null);
const now = ref(Math.floor(Date.now() / 1000));
const itemKey = ref(null);
const origin = ref('market');      // Reiter, an dem der offene Gegenstand haengt
const stamp = ref(0);   // erhoeht sich bei neuen Daten, damit Listen neu laden
const updates = ref(null);        // Inhalt des Update-Fensters
const showUpdates = ref(false);
const pageEl = ref(null);
const marketTab = ref('sum');
const settingsTab = ref('gen');   // ab 0.56.0: Reiter der Einstellungen, 'settings:adv' oeffnet Erweitert   // ab 0.46.0: Reiter der Marktuebersicht, ab 0.56.0 zuerst Uebersicht
let startChecked = false;
let firstShown = false;
async function closeUpdates() {
  showUpdates.value = false;
  await api.updatesShown();
}

// ab 0.56.0 (Peon_Manager_Schlank.md Abschnitt 3): sechs Eintraege, jede Seite ist ein Unterreiter. Seiten des Broker Client
// erscheinen nur, wenn das Modul sie liefert (data.views). Ohne Broker Client bleiben Heute, Addons und Mehr.
const ALL = [
  { key: 'today', label: 'Heute', always: true },
  { key: 'chances', label: 'Spekulation' },
  { key: 'compare', label: 'Marktvergleich' },   // ab 0.50.0: Heimat gegen Neutral (Peon_Broker_Marktvergleich.md)
  { key: 'packages', label: 'Pakete', needs: 'compare' },   // ab 0.56.0 eigener Unterreiter, vorher Reiter im Marktvergleich
  { key: 'success', label: 'Erfolg' },
  { key: 'shopping', label: 'Einkaufslisten' },   // Name wie in Broker (Peon_Broker_Schlank.md)
  { key: 'favorites', label: 'Beobachten' },
  { key: 'market', label: 'Übersicht' },
  { key: 'items', label: 'Gegenstände' },
  { key: 'vendors', label: 'Händler' },
  { key: 'modules', label: 'Addons', always: true },
  { key: 'sources', label: 'Datenlage' },
  { key: 'reports', label: 'Rückmeldungen', always: true },
  { key: 'help', label: 'Hilfe', always: true },
  { key: 'settings', label: 'Einstellungen', always: true },
];
const SECTIONS = [
  { key: 'today', label: 'Heute', views: ['today'] },
  { key: 'chancen', label: 'Chancen', views: ['chances', 'compare', 'packages', 'success'] },
  { key: 'listen', label: 'Listen', views: ['shopping', 'favorites'] },
  { key: 'markt', label: 'Markt', views: ['market', 'items', 'vendors'] },
  { key: 'addons', label: 'Addons', views: ['modules'] },
  { key: 'mehr', label: 'Mehr', views: ['sources', 'reports', 'help', 'settings'] },
];
function hasView(v, o = data.value) {
  const n = ALL.find((x) => x.key === v);
  return !!n && (n.always || !!(o && o.views.includes(n.needs || n.key)));
}
const sections = computed(() => SECTIONS.map((s) => ({ ...s, subs: ALL.filter((n) => s.views.includes(n.key) && hasView(n.key)) })).filter((s) => s.subs.length));
const sectionOf = (v) => SECTIONS.find((s) => s.views.includes(v)) || null;
// Abschnitt der offenen Seite. Ein offener Gegenstand gehoert zum Abschnitt, aus dem er geoeffnet wurde.
const curSection = computed(() => {
  const v = view.value === 'item' ? origin.value : view.value;
  return sections.value.find((s) => s.views.includes(v)) || null;
});
const curSub = computed(() => (view.value === 'item' ? origin.value : view.value));
// Zuletzt gewaehlter Unterreiter je Eintrag, bleibt in den Einstellungen gemerkt
function openSection(s) {
  const last = settings.value && settings.value.navSubs ? settings.value.navSubs[s.key] : null;
  go(s.subs.some((n) => n.key === last) ? last : s.subs[0].key);
}
watch(view, (v) => {
  const s = sectionOf(v);
  if (!s || s.views.length < 2 || !settings.value) return;
  const cur = settings.value.navSubs || {};
  if (cur[s.key] !== v) saveQuiet({ navSubs: { ...cur, [s.key]: v } });
});
const watchFocus = ref(null);   // ab 0.32.0: Zeile, die Beobachten nach einer Meldung zeigt
const broker = computed(() => !!(data.value && data.value.views.includes('overview')));
// ab 0.36.0: Seiten, die ohne Marktdaten gehen, solange der Broker Client noch laedt
const NO_MARKET = new Set(['today', 'modules', 'reports', 'help', 'settings']);
const marketWait = computed(() => !!(data.value && data.value.brokerLoading) && !NO_MARKET.has(view.value));

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
const ORIGINS = new Set(['today', 'items', 'favorites', 'shopping', 'chances', 'compare', 'packages', 'market', 'success', 'vendors']);
const entries = ref([{ view: 'today' }]);
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
  if (e.tab && e.view === 'settings') settingsTab.value = e.tab;
  else if (e.tab) marketTab.value = e.tab;
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
// 'market:stab' oeffnet die Marktuebersicht mit einem Reiter. Alte Namen zeigen auf den neuen Platz (ab 0.56.0).
const MOVED = { overview: 'today', 'market:items': 'items', 'compare:pkg': 'packages' };
function go(v) {
  v = MOVED[v] || v;
  const [view, tab] = String(v).split(':');
  push(tab ? { view, tab } : { view });
}
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

// ab 0.36.0: Beim ersten Laden kommt der Grundteil sofort (Seitenleiste, Einstellungen, Updates, Rueckmeldungen),
// die Marktdaten danach. Bis dahin zeigen die Marktseiten einen Hinweis.
let loadSeq = 0;
async function load() {
  const seq = ++loadSeq;
  if (!data.value) {
    const [b, s0, u0] = await Promise.all([api.overviewBase(), api.settings(), api.updateInfo()]);
    if (!data.value) apply(b, s0, u0);
  }
  const [o, s, u] = await Promise.all([api.overview(), api.settings(), api.updateInfo()]);
  if (seq !== loadSeq) return;   // ein spaeterer Aufruf ist schon unterwegs
  apply(o, s, u);
  if (o.views.includes('favorites')) await loadFavorites();
  stamp.value++;
}
function apply(o, s, u) {
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
  const ok = hasView(view.value, o) || ((view.value === 'item' || view.value === 'brief') && o.views.includes('items'));
  if (!ok) go('today');
  // Erster Start: Der Vorschlag zum Einrichten steht unter Addons
  if (!firstShown) { firstShown = true; if (s.setup && !s.setup.done && view.value === 'today') go('modules'); }
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

// ab 0.49.0: Peon unterstuetzen (Buy Me a Coffee), oeffnet den Browser
const COFFEE_URL = 'https://buymeacoffee.com/karloderbaer';
function openCoffee() { window.peon.openLink(COFFEE_URL); }
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
      <!-- ab 0.56.0: sechs Eintraege (Peon_Manager_Schlank.md), Unterreiter oben auf der Seite -->
      <select v-if="broker && marketOptions.length > 1" class="market small" :value="current && current.key" aria-label="Markt" @change="pickMarket($event.target.value)">
        <option v-for="m in marketOptions" :key="m.key" :value="m.key">{{ m.label }}</option>
      </select>
      <template v-for="sec in sections" :key="sec.key">
        <button class="nav" :class="{ on: curSection && curSection.key === sec.key }" @click="openSection(sec)">
          {{ sec.label }}<span v-if="sec.key === 'addons' && updates && updates.count" class="count" :title="`${updates.count} verfügbar`">{{ updates.count }}</span>
        </button>
        <template v-for="n in sec.subs" :key="n.key">
          <div v-if="subs[n.key]" class="sub" :class="{ on: view === 'item' && origin === n.key }">
            <Star :item-key="subs[n.key].key" :size="14" />
            <button class="sub-name" :style="{ color: qualityColor(subs[n.key].quality) }" :title="subs[n.key].name || ''" @click="openSub(n.key)">{{ subs[n.key].name || 'Lade' }}</button>
            <button class="sub-x" aria-label="Untertab schließen" title="Schließen" @click="closeSub(n.key)">×</button>
          </div>
        </template>
      </template>
      <div class="rail-bottom">
        <button class="primary rail-update" v-if="updates && updates.count" @click="showUpdates = true">
          {{ updates.manager || updates.addons.some((a) => a.kind === 'update') ? 'Jetzt aktualisieren' : 'Neues ansehen' }}<span class="rail-count">{{ updates.count }}</span>
        </button>
        <!-- ab 0.49.0: Peon unterstuetzen, klein unter den Eintraegen -->
        <button class="nav coffee" title="Öffnet die Seite von KarloDerBaer bei Buy Me a Coffee im Browser" @click="openCoffee">☕ Peon unterstützen</button>
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

      <nav class="subtabs" v-if="data && settings && curSection && curSection.subs.length > 1" role="tablist" :aria-label="curSection.label">
        <button v-for="n in curSection.subs" :key="n.key" role="tab" :aria-selected="curSub === n.key" :class="{ on: curSub === n.key }" @click="go(n.key)">
          {{ n.label }}<span v-if="n.key === 'reports' && data.reportCount" class="count" :title="`${data.reportCount} noch nicht gesendet`">{{ data.reportCount }}</span>
        </button>
      </nav>
      <div class="page" ref="pageEl" v-if="data && settings">
        <section v-if="marketWait" class="wait" role="status">
          <h1>Marktdaten werden geladen</h1>
          <p class="muted">Bei einer großen Datenbank dauert das nach dem Start etwas. Einstellungen, Updates und Rückmeldungen kannst du schon öffnen.</p>
        </section>
        <KeepAlive v-else :include="['Today', 'Chances', 'Shopping', 'Watch', 'Market', 'Items']">
          <Today v-if="view === 'today'" :data="data" :market="current" :now="now" :stamp="stampOf('today')" :settings="settings" :updates="updates" :broker="broker" @go="go($event)" @open="openItem" @save="saveSettings" @updates="showUpdates = true" @changed="load" />
          <Watch v-else-if="view === 'favorites'" :market="current" :now="now" :stamp="stampOf('favorites')" :settings="settings" :focus="watchFocus" @open="openItem" @save="saveQuiet" @go="go($event)" />
          <Shopping v-else-if="view === 'shopping'" :market="current" :now="now" :stamp="stampOf('shopping')" :settings="settings" @open="openItem" @save="saveQuiet" @go="go($event)" />
          <Vendors v-else-if="view === 'vendors'" :market="current" :now="now" :stamp="stampOf('vendors')" @open="openItem" />
          <Item v-else-if="view === 'item'" :market="current" :item-key="itemKey" :now="now" :theme="settings.theme" :stamp="stamp" @loaded="itemLoaded" @go="go($event)" @open="openItem" @brief="openBrief" />
          <Chances v-else-if="view === 'chances'" :market="current" :now="now" :stamp="stampOf('chances')" :settings="settings" @open="openItem" @brief="openBrief" @save="saveQuiet" />
          <Compare v-else-if="view === 'compare'" key="compare" :market="current" :now="now" :stamp="stampOf('compare')" :settings="settings" @open="openItem" @save="saveQuiet" />
          <Compare v-else-if="view === 'packages'" key="packages" packages :market="current" :now="now" :stamp="stampOf('packages')" :settings="settings" @open="openItem" @save="saveQuiet" />
          <Items v-else-if="view === 'items'" :market="current" :now="now" :stamp="stampOf('items')" :settings="settings" @open="openItem" @save="saveQuiet" @go="go($event)" />
          <Market v-else-if="view === 'market'" :market="current" :now="now" :stamp="stampOf('market')" :settings="settings" :theme="settings.theme" :tab="marketTab" @tab="marketTab = $event" @open="openItem" @brief="openBrief" @save="saveQuiet" @go="go($event)" />
          <Success v-else-if="view === 'success'" :market="current" :now="now" :stamp="stampOf('success')" @open="openItem" @brief="openBrief" />
          <Brief v-else-if="view === 'brief'" :market="current" :item-key="itemKey" :now="now" :stamp="stamp" :theme="settings.theme" @open="openItem" />
          <Sources v-else-if="view === 'sources'" :data="data" :market="current" :now="now" :stamp="stamp" @go="go($event)" />
          <Modules v-else-if="view === 'modules'" :data="data" :settings="settings" :now="now" :stamp="stamp" @changed="load" @save="saveSettings" @pick-folder="pickWow" @go="go($event)" @updates="load().then(() => { showUpdates = true; })" />
          <Reports v-else-if="view === 'reports'" :now="now" :stamp="stamp" @go="go($event)" @changed="load" />
          <Help v-else-if="view === 'help'" />
          <Settings v-else-if="view === 'settings'" :data="data" :settings="settings" :stamp="stamp" :broker="broker" :now="now" :tab="settingsTab" @tab="settingsTab = $event" @save="saveSettings" @go="go($event)" />
        </KeepAlive>
      </div>
      <div class="page muted" v-else>Lade Daten</div>
    </main>
    <UpdateDialog v-if="showUpdates && updates && settings" :info="updates" :settings="settings" @close="closeUpdates" @changed="load" @save="saveQuiet" />
  </div>
</template>

<style scoped>
.wait { display: grid; gap: 8px; max-width: 70ch; }
.wait h1 { margin: 0; }
.wait p { margin: 0; }
.shell { display: grid; grid-template-columns: 196px 1fr; grid-template-rows: minmax(0, 1fr); height: 100%; }
.rail { background: var(--panel); border-right: 1px solid var(--line-soft); display: flex; flex-direction: column; padding: 18px 12px; gap: 2px; }
.mark { display: flex; align-items: center; gap: 10px; padding: 0 8px 22px; font-family: var(--font-cond); font-weight: 600; font-size: 18px; }
.nav { text-align: left; background: none; border: none; border-left: 3px solid transparent; border-radius: 0 var(--radius-s) var(--radius-s) 0;
  padding: 9px 12px; color: var(--muted); font-weight: 500; display: flex; justify-content: space-between; align-items: center; }
.nav:hover { color: var(--text); background: var(--line-soft); }
.nav.on { color: var(--text); border-left-color: var(--accent); background: var(--accent-soft); }
.nav.coffee { font-size: 13px; color: var(--muted); margin-top: 6px; }
.market { margin: 0 2px 10px; width: calc(100% - 4px); }
.subtabs { display: flex; gap: 4px; padding: 0 28px; border-bottom: 1px solid var(--line); flex-wrap: wrap; }
.subtabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 10px 14px 8px; color: var(--muted); font-weight: 500; margin-bottom: -1px; display: flex; gap: 6px; align-items: center; }
.subtabs button:hover { color: var(--text); }
.subtabs button.on { color: var(--text); border-bottom-color: var(--accent); }
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
.page > .items, .page > .mk.full { flex: 1; min-height: 0; }
</style>
