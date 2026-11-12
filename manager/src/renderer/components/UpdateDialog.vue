<script setup>
// Update-Fenster: Manager, Addon-Updates und neue Addons mit kurzem Text, einzeln oder alles auf einmal.
// Geöffnet beim Programmstart, nach "Nach Updates suchen" und über "Jetzt aktualisieren" (App.vue).
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import ReleaseText from './ReleaseText.vue';

const props = defineProps({ info: Object, settings: Object });
const emit = defineEmits(['close', 'changed', 'save']);
const api = window.peon;

const busy = ref('');
const error = ref('');
const message = ref('');
const wowRunning = ref(false);
const root = ref(null);

const man = computed(() => props.info.manager);
const updates = computed(() => props.info.addons.filter((a) => a.kind === 'update'));
const added = computed(() => props.info.addons.filter((a) => a.kind === 'new'));
const managerReady = computed(() => !!(man.value && man.value.status === 'ready'));
const managerLoading = computed(() => !!(man.value && man.value.status !== 'ready' && man.value.status !== 'error'));
const anything = computed(() => props.info.count > 0);
const mainLabel = computed(() => (updates.value.length ? 'Alles aktualisieren' : 'Jetzt neu starten'));
const showMain = computed(() => updates.value.length > 0 || managerReady.value);

function cleanError(e) { return String((e && e.message) || e).replace(/^Error invoking remote method '[^']*': (Error: )?/, ''); }

// Ergebnis einer Installation in einem Satz
function report(r, what) {
  if (r.failed.length) error.value = r.failed.map((f) => `${f.name}: ${f.error}`).join(', ');
  if (r.done.length) message.value = `${what}: ${r.done.map((d) => `${d.name} ${d.version}`).join(', ')}. ${wowRunning.value ? 'WoW läuft: Nach /reload ist alles im Spiel.' : 'Beim nächsten Start von WoW ist alles dabei.'}`;
}

async function install(names, what, key) {
  busy.value = key;
  error.value = '';
  message.value = '';
  try {
    report(await api.installAddons(names), what);
  } catch (e) {
    error.value = cleanError(e);
  } finally {
    busy.value = '';
    emit('changed');
  }
}

const one = (a) => install([a.name], a.kind === 'new' ? 'Hinzugefügt' : 'Aktualisiert', a.name);

// Vor dem Neustart sagen, was passiert: Der Manager schliesst sich, der Installer zeigt seinen Fortschritt
// und startet den Manager danach von selbst wieder
const restarting = ref(false);
async function restart() {
  restarting.value = true;
  busy.value = 'restart';
  try {
    await api.updatesShown();
    await new Promise((r) => setTimeout(r, 3000));
    await api.installManagerUpdate();
  } catch (e) {
    error.value = cleanError(e);
    restarting.value = false;
    busy.value = '';
  }
}

// Erst die Addons, dann der Manager: Er startet dafür neu
async function all() {
  const names = updates.value.map((a) => a.name);
  if (names.length) await install(names, 'Aktualisiert', 'all');
  if (error.value) return;
  if (managerReady.value) await restart();
  else if (managerLoading.value) message.value = `${message.value} Der Peon Manager lädt noch, danach kannst du ihn hier neu starten.`.trim();
}

function close() {
  if (busy.value) return;
  emit('close');
}

function onKey(e) { if (e.key === 'Escape') close(); }
onMounted(async () => {
  window.addEventListener('keydown', onKey);
  if (root.value) root.value.focus();
  try { wowRunning.value = !!(await api.addons()).wowRunning; } catch { /* nur ein Hinweis */ }
});
onBeforeUnmount(() => window.removeEventListener('keydown', onKey));
</script>

<template>
  <div class="veil" @click.self="close">
    <div class="box" ref="root" tabindex="-1" role="dialog" aria-modal="true" aria-labelledby="update-title">
      <header>
        <h2 id="update-title">Neues für Peon</h2>
        <button class="x" aria-label="Schließen" :disabled="!!busy" @click="close">×</button>
      </header>

      <p class="banner small" v-if="wowRunning" role="status">WoW läuft. Aktualisieren geht trotzdem, danach reicht <code>/reload</code>.</p>

      <div class="steps" v-if="restarting" role="status">
        <p>Der Peon Manager {{ man ? man.version : '' }} wird jetzt eingespielt.</p>
        <ol>
          <li class="done">Neue Version geladen</li>
          <li class="now">Manager wird geschlossen</li>
          <li>Ein kleines Fenster zeigt, wie die neue Version eingespielt wird</li>
          <li>Der Manager startet von selbst neu</li>
        </ol>
        <p class="small muted">Das dauert etwa eine halbe Minute. Du musst nichts tun.</p>
      </div>

      <div class="list" v-else>
        <p class="muted" v-if="!anything">Alles ist aktuell.</p>

        <article v-if="man">
          <div class="head">
            <div><h3>Peon Manager</h3><span class="small muted">{{ man.installed }} auf {{ man.version }}</span></div>
            <button v-if="managerReady" :disabled="!!busy" @click="restart">Neu starten</button>
            <span v-else-if="man.status === 'error'" class="small warn">Laden fehlgeschlagen</span>
            <span v-else class="small muted" role="status">Wird geladen{{ man.percent ? ` (${man.percent} %)` : '' }}</span>
          </div>
          <p class="small warn" v-if="man.error">{{ man.error }}</p>
          <ReleaseText :release="man.release" :news="man.news" />
          <p class="small muted" v-if="managerReady">Zum Einspielen startet das Programm neu.</p>
        </article>

        <article v-for="a in updates" :key="a.name">
          <div class="head">
            <div><h3>{{ a.title }}</h3><span class="small muted">{{ a.installed }} auf {{ a.version }}</span></div>
            <button :disabled="!!busy" @click="one(a)">{{ busy === a.name ? 'Moment' : 'Aktualisieren' }}</button>
          </div>
          <ReleaseText :release="a.release" :news="a.news" />
        </article>

        <article v-for="a in added" :key="a.name">
          <div class="head">
            <div><h3>{{ a.title }} <span class="neu small">neu</span></h3><span class="small muted">Version {{ a.version }}</span></div>
            <button :disabled="!!busy" @click="one(a)">{{ busy === a.name ? 'Moment' : 'Hinzufügen' }}</button>
          </div>
          <p class="small">{{ a.desc }}</p>
          <ReleaseText :release="a.release" :news="a.news" />
        </article>
      </div>

      <p class="small warn" v-if="error" role="alert">{{ error }}</p>
      <p class="small ok" v-if="message" role="status">{{ message }}</p>

      <footer v-if="!restarting">
        <label class="small check">
          <input type="checkbox" :checked="!settings.updateWindow" @change="emit('save', { updateWindow: !$event.target.checked })" />
          Nicht mehr beim Start zeigen
        </label>
        <div class="row">
          <button :disabled="!!busy" @click="close">{{ anything ? 'Später' : 'Schließen' }}</button>
          <button class="primary" v-if="showMain" :disabled="!!busy" @click="all">{{ busy === 'all' ? 'Aktualisiert' : mainLabel }}</button>
        </div>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.veil { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 24px; background: rgba(0, 0, 0, 0.5); }
.box { width: 100%; max-width: 560px; max-height: 100%; display: flex; flex-direction: column; gap: 12px; padding: 18px 20px; background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius-m); outline: none; }
header { display: flex; justify-content: space-between; align-items: center; }
header h2 { margin: 0; }
.x { background: none; border: none; font-size: 20px; line-height: 1; padding: 2px 6px; color: var(--muted); }
.banner { margin: 0; padding: 8px 12px; border: 1px solid var(--warn); border-radius: var(--radius-s); }
.list { overflow: auto; min-height: 0; display: grid; gap: 12px; padding-right: 4px; }
article { display: grid; gap: 4px; padding-bottom: 12px; border-bottom: 1px solid var(--line-soft); }
article:last-child { border-bottom: none; padding-bottom: 0; }
.head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
.head h3 { margin: 0; }
.head button, .head > span { flex: none; }
ul { margin: 2px 0 0; padding-left: 18px; }
p { margin: 0; }
.neu { color: var(--accent); font-weight: 500; }
.ok { color: var(--accent); }
.warn { color: var(--warn); }
footer { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; padding-top: 4px; }
.check { display: flex; gap: 8px; align-items: center; }
.row { display: flex; gap: 10px; }
.steps { display: grid; gap: 10px; }
.steps ol { margin: 0; padding-left: 22px; display: grid; gap: 6px; }
.steps li { color: var(--muted); }
.steps li.done { color: var(--accent); }
.steps li.done::after { content: ' ✓'; }
.steps li.now { color: var(--text); font-weight: 500; }
</style>
