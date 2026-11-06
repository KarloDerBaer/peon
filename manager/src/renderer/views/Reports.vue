<script setup>
// Ansicht "Rueckmeldungen": eigene Rueckmeldungen schreiben, Eintraege aus dem Spiel bearbeiten, Fehler mit Notizen versehen, alles senden
import { ref, computed, watch, onMounted } from 'vue';
import { ago, pl } from '../util.js';

const props = defineProps({ now: Number, stamp: Number });
const emit = defineEmits(['go', 'changed']);
const api = window.peon;

const state = ref(null);
const busy = ref('');
const error = ref('');
const note = ref('');
const confirm = ref('');        // Schluessel des Eintrags, der geloescht werden soll, oder 'alle'
const previewOpen = ref(false);
const notes = ref({});          // Entwuerfe der Notizen, damit ein Neuladen beim Tippen nichts ueberschreibt

const blank = () => ({ module: 'Peon_Manager', kind: 'bug', area: '', prio: 'mid', text: '' });
const form = ref(blank());
const editKey = ref('');

async function load() {
  const s = await api.reports();
  state.value = s;
  for (const r of s.errors) if (notes.value[r.key] === undefined) notes.value[r.key] = r.note;
  fixArea();
}
onMounted(load);
watch(() => props.stamp, load);

const moduleEntry = computed(() => (state.value ? state.value.modules.find((m) => m.key === form.value.module) : null));
// Auswahl beim Bearbeiten: auch ein Modul oder Bereich, den es hier gerade nicht gibt
const moduleOptions = computed(() => {
  const list = state.value ? state.value.modules : [];
  return list.some((m) => m.key === form.value.module) ? list : [...list, { key: form.value.module, title: form.value.module, areas: [] }];
});
const areaOptions = computed(() => {
  const list = moduleEntry.value ? moduleEntry.value.areas : ['Sonstiges'];
  return !form.value.area || list.includes(form.value.area) ? list : [form.value.area, ...list];
});
function fixArea() { if (!form.value.area || !areaOptions.value.includes(form.value.area)) form.value.area = areaOptions.value[0] || 'Sonstiges'; }
function moduleChanged() { form.value.area = ''; fixArea(); }

const label = (items, key) => (items.find((x) => x.key === key) || { label: key }).label;
const moduleTitle = (key) => (state.value.modules.find((m) => m.key === key) || { title: key.replace(/^Peon_/, '') }).title;
const total = computed(() => (state.value ? state.value.errors.length + state.value.feedback.length : 0));

const message = (e) => String(e && e.message || e).replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
async function run(what, fn) {
  busy.value = what;
  error.value = '';
  note.value = '';
  try { await fn(); emit('changed'); await load(); return true; } catch (e) { error.value = message(e); return false; } finally { busy.value = ''; }
}

const saveForm = () => run('save', async () => {
  const f = { ...form.value };
  if (editKey.value) await api.reportUpdate(editKey.value, f); else await api.reportAdd(f);
  note.value = editKey.value ? 'Rückmeldung geändert.' : 'Rückmeldung gespeichert. Gesendet wird erst mit „Alles senden“.';
  cancelEdit();
});
function startEdit(r) {
  editKey.value = r.key;
  form.value = { module: r.module, kind: r.kind, area: r.area, prio: r.prio, text: r.text };
  error.value = '';
  note.value = '';
}
function cancelEdit() {
  const { module, kind, prio } = form.value;
  form.value = { ...blank(), module, kind, prio };
  editKey.value = '';
  fixArea();
}
function remove(what, key) {
  if (confirm.value !== key) { confirm.value = key; return undefined; }
  confirm.value = '';
  if (editKey.value === key) cancelEdit();
  return run('delete', () => (what === 'error' ? api.errorDelete(key) : api.reportDelete(key)));
}
const removeAll = () => {
  if (confirm.value !== 'alle') { confirm.value = 'alle'; return undefined; }
  confirm.value = '';
  cancelEdit();
  return run('delete', () => api.reportsClear());
};
const saveNote = (r) => { if (notes.value[r.key] !== r.note) run('note', () => api.errorNote(r.key, notes.value[r.key])); };
const send = () => run('send', async () => {
  const r = await api.reportsSend();
  const parts = [`${pl(r.sent, 'Eintrag', 'Einträge')} gesendet, danke!`];
  if (r.failed) parts.push(`${pl(r.failed, 'Eintrag', 'Einträge')} konnten nicht gesendet werden und bleiben hier.`);
  if (r.left) parts.push(`${pl(r.left, 'weiterer Eintrag', 'weitere Einträge')} beim nächsten Senden.`);
  note.value = parts.join(' ');
  previewOpen.value = false;
});
</script>

<template>
  <div class="reports" v-if="state">
    <section class="block">
      <h1>Rückmeldungen</h1>
      <p class="muted lead">Fehler, Verbesserungen und Ideen zu Peon. Hier kannst du alles vor dem Senden ändern, ergänzen oder löschen. Gesendet wird nur, was du mit „Alles senden“ abschickst.</p>
      <p v-if="!state.bridge" class="small hint">Peon_Bridge fehlt. Einträge aus dem Spiel werden gelesen, dort aber nicht gelöscht. <button class="link" @click="emit('go', 'modules')">Zu den Modulen</button></p>
    </section>

    <section class="block">
      <h2>{{ editKey ? 'Rückmeldung bearbeiten' : 'Neue Rückmeldung' }}</h2>
      <div class="grid">
        <label>Modul
          <select v-model="form.module" @change="moduleChanged"><option v-for="m in moduleOptions" :key="m.key" :value="m.key">{{ m.title }}</option></select>
        </label>
        <label>Art
          <select v-model="form.kind"><option v-for="k in state.kinds" :key="k.key" :value="k.key">{{ k.label }}</option></select>
        </label>
        <label>Bereich
          <select v-model="form.area"><option v-for="a in areaOptions" :key="a" :value="a">{{ a }}</option></select>
        </label>
        <label>Priorität
          <select v-model="form.prio"><option v-for="p in state.prios" :key="p.key" :value="p.key">{{ p.label }}</option></select>
        </label>
      </div>
      <label class="wide">Beschreibung
        <textarea v-model="form.text" rows="4" maxlength="2000"></textarea>
      </label>
      <div class="actions">
        <button class="primary" :disabled="!!busy" @click="saveForm">Speichern</button>
        <button v-if="editKey" :disabled="!!busy" @click="cancelEdit">Abbrechen</button>
      </div>
    </section>

    <section class="block">
      <h2>Gespeicherte Rückmeldungen</h2>
      <p v-if="!state.feedback.length" class="muted">Keine Rückmeldungen. Im Spiel geht es auch mit dem Addon Peon_Feedback über <code>/feedback</code>.</p>
      <table v-else class="tbl">
        <thead><tr><th>Modul</th><th>Art</th><th>Bereich</th><th>Priorität</th><th>Beschreibung</th><th>Geändert</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in state.feedback" :key="r.key" :class="{ editing: editKey === r.key }">
            <td class="nowrap">{{ moduleTitle(r.module) }}<div v-if="r.origin === 'game'" class="small muted">aus dem Spiel</div></td>
            <td class="nowrap">{{ label(state.kinds, r.kind) }}</td>
            <td class="muted">{{ r.area }}</td>
            <td class="nowrap">{{ label(state.prios, r.prio) }}</td>
            <td class="msg">{{ r.text }}</td>
            <td class="muted nowrap">{{ ago(r.edited, now) }}</td>
            <td class="rowbtn">
              <button :disabled="!!busy" @click="startEdit(r)">Bearbeiten</button>
              <button class="danger" :disabled="!!busy" @click="remove('feedback', r.key)">{{ confirm === r.key ? 'Wirklich?' : 'Löschen' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block">
      <h2>Erfasste Fehler</h2>
      <p class="small muted">Neue Fehler erscheinen hier nach einem /reload, Ausloggen oder Beenden des Spiels. In der Notiz kannst du ergänzen, was du gerade gemacht hast.</p>
      <p v-if="!state.errors.length" class="muted">Keine erfassten Fehler.</p>
      <table v-else class="tbl">
        <thead><tr><th>Addon</th><th>Bereich</th><th>Fehler und Notiz</th><th class="r">Anzahl</th><th>Zuletzt</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in state.errors" :key="r.key">
            <td class="nowrap">{{ r.addon }}<div v-if="r.version" class="small muted">{{ r.version }}</div></td>
            <td class="muted">{{ r.place }}</td>
            <td>
              <div class="msg">{{ r.msg }}</div>
              <details v-if="r.stack"><summary class="small muted">Aufrufkette</summary><pre class="stack">{{ r.stack }}</pre></details>
              <textarea class="noteinput" v-model="notes[r.key]" rows="2" maxlength="2000" placeholder="Notiz, zum Beispiel was du gerade gemacht hast" aria-label="Notiz zu diesem Fehler" @blur="saveNote(r)"></textarea>
            </td>
            <td class="r">{{ r.n }}</td>
            <td class="muted nowrap">{{ ago(r.last, now) }}</td>
            <td class="rowbtn"><button class="danger" :disabled="!!busy" @click="remove('error', r.key)">{{ confirm === r.key ? 'Wirklich?' : 'Löschen' }}</button></td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block">
      <h2>Senden</h2>
      <p v-if="!total" class="muted">Es gibt nichts zu senden.</p>
      <template v-else>
        <div class="actions" v-if="!previewOpen">
          <button class="primary" :disabled="!!busy || !state.canSend" @click="previewOpen = true">Alles senden</button>
          <button class="danger" :disabled="!!busy" @click="removeAll">{{ confirm === 'alle' ? 'Wirklich alles löschen?' : 'Alles löschen' }}</button>
          <button v-if="confirm === 'alle'" @click="confirm = ''">Abbrechen</button>
        </div>
        <p v-if="!state.canSend" class="small muted">Das Senden ist in dieser Fassung nicht eingerichtet.</p>

        <div v-if="previewOpen" class="preview">
          <p class="small muted">Das geht an KarloDerBaer: genau der Text unten, je Eintrag ein Bericht in einem nicht öffentlichen GitHub-Repo. Deine Konto- und Charakternamen sowie Pfade sind ersetzt, Namen anderer Spieler in deinem Text aber nicht. Der Bericht läuft über einen Cloudflare-Dienst, der deine IP-Adresse technisch sieht, aber nicht speichert. Ein Konto brauchst du nicht. Gesendete Einträge verschwinden danach aus dieser Liste.</p>
          <pre class="stack">{{ state.preview.text }}</pre>
          <p v-if="state.preview.left" class="small muted">{{ pl(state.preview.left, 'weiterer Eintrag', 'weitere Einträge') }} beim nächsten Senden.</p>
          <div class="actions">
            <button class="primary" :disabled="!!busy" @click="send">{{ busy === 'send' ? 'Sendet' : `${pl(state.preview.count, 'Eintrag', 'Einträge')} senden` }}</button>
            <button :disabled="!!busy" @click="previewOpen = false">Abbrechen</button>
          </div>
        </div>
      </template>
    </section>

    <p v-if="error" class="err" role="alert">{{ error }}</p>
    <p v-if="note" class="ok" role="status">{{ note }}</p>
  </div>
  <div class="muted" v-else>Lade Daten</div>
</template>

<style scoped>
.reports { display: flex; flex-direction: column; gap: 24px; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin: 10px 0; }
label { display: flex; flex-direction: column; gap: 4px; font-size: 13px; color: var(--muted); }
label select { width: 100%; }
textarea { width: 100%; box-sizing: border-box; background: var(--raised); color: var(--text); border: 1px solid var(--line); border-radius: var(--radius-s); padding: 8px; font: inherit; resize: vertical; }
.noteinput { margin-top: 8px; font-size: 13px; }
.actions { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; margin-top: 10px; }
.tbl { width: 100%; margin-top: 8px; }
.tbl th { text-align: left; }
.tbl th.r, .r { text-align: right; }
.tbl th, .tbl td { padding-right: 16px; vertical-align: top; }
.nowrap { white-space: nowrap; }
.msg { overflow-wrap: anywhere; white-space: pre-wrap; }
.rowbtn { white-space: nowrap; text-align: right; padding-right: 0; }
.rowbtn button + button { margin-left: 6px; }
.editing td { background: var(--accent-soft); }
.stack { margin: 8px 0; padding: 10px; max-height: 300px; overflow: auto; background: var(--raised); border-radius: var(--radius-s); font-size: 12px; white-space: pre-wrap; overflow-wrap: anywhere; }
.preview { display: flex; flex-direction: column; gap: 8px; }
.err { color: var(--danger, #e5484d); }
.ok { color: var(--accent); }
.hint { margin-top: 8px; }
</style>
