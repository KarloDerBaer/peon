<script setup>
// Ansicht "Module" (Peon_GitHub_Design.md 5.3, 5.5): Addons und Manager-Module, Vorschlag beim ersten Start
import { ref, computed, watch, onMounted } from 'vue';
import { ago, bytes } from '../util.js';

const props = defineProps({ data: Object, now: Number, stamp: Number });
const emit = defineEmits(['changed', 'pickFolder']);
const api = window.peon;

const st = ref(null);
const busy = ref('');           // laufende Aktion: 'check', 'all', Addon-Name, Modul-Schluessel oder 'setup'
const error = ref('');
const message = ref('');
const confirmDelete = ref('');  // Daten eines Moduls loeschen
const confirmRemove = ref('');  // Addon entfernen
const open = ref('');           // aufgeklapptes "Was ist neu"

// Erster Start: Addons vorausgewaehlt, Broker Client nur als Angebot
const pick = ref({});
const pickModule = ref({});
const found = ref([]);

const LABEL = { current: 'Aktuell', update: 'Update verfügbar', missing: 'Nicht installiert', dev: 'Entwicklung (Repo)', newer: 'Neuer als das Release', unknown: 'Installiert' };
const items = computed(() => (st.value ? st.value.items : []));
const shown = computed(() => items.value.filter((a) => !a.managerOnly || a.present));
const choosable = computed(() => items.value.filter((a) => !a.managerOnly));
const showSetup = computed(() => st.value && !st.value.setup.done && choosable.value.length > 0);

const checkText = computed(() => {
  const c = st.value && st.value.check;
  if (!c) return 'Noch nicht gesucht.';
  if (!c.ok) return `Suche fehlgeschlagen ${ago(c.t, props.now)}: ${c.error}`;
  if (c.noRelease) return 'Es gibt noch kein Release.';
  return `Release ${st.value.release}, zuletzt gesucht ${ago(c.t, props.now)}.`;
});

async function load() {
  st.value = await api.addons();
  if (st.value.setup.done) return;
  for (const a of choosable.value) if (pick.value[a.name] === undefined) pick.value[a.name] = true;
  if (!st.value.wowValid && !found.value.length) found.value = await api.findWow();
}
onMounted(load);
watch(() => props.stamp, load);

// Aktion mit Sperre und Fehleranzeige
async function run(what, fn) {
  busy.value = what; error.value = ''; message.value = '';
  try { return await fn(); } catch (e) { error.value = String(e.message || e).replace(/^Error invoking remote method '[^']*': (Error: )?/, ''); return null; } finally { busy.value = ''; await load(); emit('changed'); }
}

// Ergebnis einer Installation in einem Satz
function report(r) {
  if (!r) return;
  const done = r.done.map((d) => `${d.name} ${d.version}`);
  if (r.failed.length) error.value = r.failed.map((f) => `${f.name}: ${f.error}`).join(' · ');
  if (done.length) message.value = `Installiert: ${done.join(', ')}.${st.value && st.value.wowRunning ? ' WoW läuft: Neue Dateien brauchen einen Neustart von WoW, sonst reicht /reload.' : ''}`;
  else if (!r.failed.length) message.value = 'Nichts zu tun.';
}

const check = () => run('check', () => api.checkAddons());
const updateAll = async () => report(await run('all', () => api.updateAddons()));
const installOne = async (a) => report(await run(a.name, () => api.installAddons([a.name])));
async function remove(a) {
  if (confirmRemove.value !== a.name) { confirmRemove.value = a.name; return; }
  confirmRemove.value = '';
  await run(a.name, async () => { await api.removeAddon(a.name); message.value = `${a.name} entfernt. Die Einstellungen im Spiel bleiben erhalten.`; });
}

async function toggle(m) {
  const r = await run(m.key, () => api.setModule(m.key, !m.enabled));
  if (r && r.install) report(r.install);
}
async function clearData(m) {
  if (confirmDelete.value !== m.key) { confirmDelete.value = m.key; return; }
  confirmDelete.value = '';
  await run(m.key, () => api.clearModuleData(m.key));
}

async function setup() {
  const addons = choosable.value.filter((a) => pick.value[a.name] || a.name === 'Peon').map((a) => a.name);
  const modules = Object.keys(pickModule.value).filter((k) => pickModule.value[k]);
  report(await run('setup', () => api.finishSetup({ addons, modules })));
}
const skipSetup = () => run('setup', () => api.saveSettings({ setup: { done: true } }));
const useWow = (dir) => run('setup', () => api.saveSettings({ wowDir: dir }));
</script>

<template>
  <div class="mods" v-if="st">
    <h1>Module</h1>

    <p class="banner warn" v-if="st.wowRunning" role="status">WoW läuft. Aktualisieren geht trotzdem: Neue Dateien brauchen danach einen Neustart von WoW, sonst reicht <code>/reload</code>.</p>
    <p class="banner warn" v-if="st.tooOld" role="alert">{{ st.tooOld }}</p>
    <div class="banner warn" v-if="!st.wowValid" role="alert">
      <p>Im eingestellten Ordner liegt kein WoW Forever: {{ st.wowDir }}</p>
      <div class="row" v-for="d in found" :key="d"><button @click="useWow(d)">{{ d }} verwenden</button></div>
      <button @click="emit('pickFolder')">Ordner wählen</button>
    </div>
    <p class="small warn" v-if="error" role="alert">{{ error }}</p>
    <p class="small ok" v-if="message" role="status">{{ message }}</p>

    <div class="banner ok-line" v-if="st.manager && st.manager.status === 'ready'" role="status">
      <p>Peon Manager {{ st.manager.version }} ist bereit (jetzt {{ st.manager.version && data.version }}). Zum Einspielen startet das Programm neu.</p>
      <button class="primary" @click="api.installManagerUpdate()">Jetzt neu starten</button>
    </div>
    <p class="small muted" v-else-if="st.manager && st.manager.status === 'downloading'" role="status">Peon Manager {{ st.manager.version }} wird geladen ({{ st.manager.percent }} %).</p>
    <p class="small warn" v-else-if="st.manager && st.manager.status === 'error'" role="status">Selbst-Update fehlgeschlagen: {{ st.manager.error }}</p>

    <section class="group setup" v-if="showSetup">
      <h2>Willkommen</h2>
      <p>Wähle, was der Manager installieren soll. Du kannst später alles hier ändern. {{ st.wowValid ? `WoW-Ordner: ${st.wowDir}` : '' }}</p>
      <label class="check" v-for="a in choosable" :key="a.name">
        <input type="checkbox" v-model="pick[a.name]" :disabled="a.name === 'Peon'" />
        <span><strong>{{ a.title }}</strong> <span class="small muted">{{ a.desc }}</span></span>
      </label>
      <h3>Dazu für den Manager</h3>
      <label class="check" v-for="m in data.modules" :key="m.key">
        <input type="checkbox" v-model="pickModule[m.key]" />
        <span><strong>{{ m.title }}</strong> <span class="small muted">{{ m.desc }}</span></span>
      </label>
      <div class="row">
        <button class="primary" :disabled="!!busy || !st.wowValid" @click="setup">{{ busy === 'setup' ? 'Installiert' : 'Installieren' }}</button>
        <button :disabled="!!busy" @click="skipSetup">Später</button>
      </div>
    </section>

    <section class="group">
      <div class="head">
        <h2>Addons</h2>
        <div class="row">
          <button :disabled="!!busy" @click="check">{{ busy === 'check' ? 'Sucht' : 'Nach Updates suchen' }}</button>
          <button class="primary" v-if="st.updates" :disabled="!!busy || !!st.tooOld" @click="updateAll">{{ busy === 'all' ? 'Aktualisiert' : `Alle aktualisieren (${st.updates})` }}</button>
        </div>
      </div>
      <p class="small" :class="st.check && !st.check.ok ? 'warn' : 'muted'">
        {{ checkText }} <template v-if="st.channel === 'test'">Kanal Test.</template>
        Installiert wird nur, wenn du es auslöst.
      </p>

      <article v-for="a in shown" :key="a.name" class="card">
        <div class="head">
          <div>
            <h3>{{ a.title }}</h3>
            <span class="small" :class="{ ok: a.status === 'current', warn: a.status === 'update', muted: !['current', 'update'].includes(a.status) }">
              {{ LABEL[a.status] }}
              <template v-if="a.installed"> · installiert {{ a.installed }}</template>
              <template v-if="a.available && a.available !== a.installed"> · verfügbar {{ a.available }}</template>
            </span>
          </div>
          <div class="row">
            <button class="primary" v-if="a.status === 'update' || a.status === 'missing'" :disabled="!!busy || !!st.tooOld || !st.wowValid" @click="installOne(a)">
              {{ busy === a.name ? 'Moment' : a.status === 'update' ? 'Aktualisieren' : 'Installieren' }}
            </button>
            <button v-if="a.removable" class="danger" :disabled="!!busy" @click="remove(a)">{{ confirmRemove === a.name ? 'Wirklich entfernen?' : 'Entfernen' }}</button>
            <button v-if="confirmRemove === a.name" @click="confirmRemove = ''">Abbrechen</button>
          </div>
        </div>
        <p v-if="a.desc">{{ a.desc }}</p>
        <p class="small muted" v-if="a.managerOnly">Gehört fest zum Peon Manager und wird mit ihm aktualisiert.</p>
        <button class="link small" v-if="a.notes" @click="open = open === a.name ? '' : a.name">{{ open === a.name ? 'Was ist neu ausblenden' : 'Was ist neu' }}</button>
        <div class="notes small" v-if="open === a.name">{{ a.notes }}</div>
      </article>
      <p class="small muted" v-if="!shown.length">Sobald es ein Release gibt, stehen die Addons hier.</p>
    </section>

    <section class="group">
      <h2>Manager-Module</h2>
      <p class="small muted">Zusätze für den Peon Manager. Sie stecken schon im Programm und werden mit „Installieren“ eingeschaltet.</p>

      <article v-for="m in data.modules" :key="m.key" class="card" :class="{ on: m.enabled }">
        <div class="head">
          <div>
            <h3>{{ m.title }}</h3>
            <span class="state small" :class="m.enabled ? 'ok' : 'muted'">{{ m.enabled ? 'Installiert' : 'Nicht installiert' }}</span>
          </div>
          <button :class="{ primary: !m.enabled }" :disabled="!!busy" @click="toggle(m)">
            {{ busy === m.key ? 'Moment' : m.enabled ? 'Entfernen' : 'Installieren' }}
          </button>
        </div>
        <p>{{ m.desc }}</p>
        <p class="small muted">
          Braucht die Addons
          <span v-for="(a, i) in m.addons" :key="a.name"><span :class="a.present ? '' : 'warn'">{{ a.name }}{{ a.present ? '' : ' (fehlt)' }}</span>{{ i < m.addons.length - 1 ? ', ' : '' }}</span>.
          <template v-if="!m.enabled && m.addons.some((a) => !a.present)"> Fehlende Addons installiert der Manager beim Installieren mit.</template>
        </p>
        <div class="data small" v-if="!m.enabled && m.hasData">
          <span class="muted">Die Daten des Moduls bleiben erhalten ({{ bytes(m.dataBytes) }}). Beim nächsten Installieren sind sie wieder da.</span>
          <button class="danger" :disabled="!!busy" @click="clearData(m)">{{ confirmDelete === m.key ? 'Wirklich löschen?' : 'Daten löschen' }}</button>
          <button v-if="confirmDelete === m.key" @click="confirmDelete = ''">Abbrechen</button>
        </div>
      </article>
    </section>

    <p class="small"><button class="link" @click="api.openLink(st.feedback)">Feedback und Fehler melden</button></p>
  </div>
  <div class="muted" v-else>Lade Module</div>
</template>

<style scoped>
.mods { display: grid; gap: 26px; max-width: 760px; }
.group { display: grid; gap: 12px; padding-bottom: 24px; border-bottom: 1px solid var(--line-soft); }
.card { border: 1px solid var(--line); border-radius: var(--radius-m); padding: 14px 18px; display: grid; gap: 8px; background: var(--panel); }
.card.on { border-color: var(--accent); }
.head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
.head h2, .head h3 { margin: 0 0 2px; }
.row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.check { display: flex; gap: 10px; align-items: baseline; }
.ok { color: var(--accent); }
.warn { color: var(--warn); }
.banner { border: 1px solid var(--warn); border-radius: var(--radius-m); padding: 10px 14px; display: grid; gap: 8px; justify-items: start; }
.ok-line { border-color: var(--accent); }
.setup { border: 1px solid var(--accent); border-radius: var(--radius-m); padding: 16px 18px; }
.notes { white-space: pre-wrap; overflow-wrap: anywhere; max-height: 280px; overflow: auto; color: var(--muted); border-top: 1px solid var(--line-soft); padding-top: 8px; }
.data { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; padding-top: 6px; border-top: 1px solid var(--line-soft); }
.data .muted { flex: 1; min-width: 240px; }
button.danger { color: var(--bad); border-color: var(--bad); }
button.link.small { justify-self: start; padding: 0; }
</style>
