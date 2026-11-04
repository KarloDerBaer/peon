<script setup>
import { ref, computed, onMounted } from 'vue';
import { ago } from '../util.js';

const props = defineProps({ now: Number });
const emit = defineEmits(['state']);
const api = window.peon;

const REGIONS = [{ id: 'eu', label: 'Europa' }, { id: 'us', label: 'Amerika' }, { id: 'tw', label: 'Taiwan' }];
const st = ref(null);
const clientId = ref('');
const clientSecret = ref('');
const region = ref('eu');
const busy = ref('');
const error = ref('');
const confirmClear = ref(false);

function apply(s) {
  st.value = s;
  region.value = s.region;
  emit('state', s);
}
onMounted(async () => apply(await api.blizzardState()));

// Fehler aus dem Hauptteil kommen mit Vorspann von Electron an
const message = (e) => String(e && e.message || e).replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
async function run(what, fn) {
  busy.value = what;
  error.value = '';
  try { apply(await fn()); } catch (e) { error.value = message(e); } finally { busy.value = ''; }
}
function save() {
  return run('save', async () => {
    const s = await api.blizzardSave({ clientId: clientId.value, clientSecret: clientSecret.value, region: region.value });
    clientId.value = ''; clientSecret.value = '';
    return s;
  });
}
function check() { return run('check', () => api.blizzardCheck()); }
function clear() {
  if (!confirmClear.value) { confirmClear.value = true; return undefined; }
  confirmClear.value = false;
  return run('clear', () => api.blizzardClear());
}
const report = computed(() => st.value && st.value.report);
const good = computed(() => report.value && report.value.result === 'auctions');
const regionLabel = computed(() => (REGIONS.find((r) => r.id === (st.value && st.value.region)) || REGIONS[0]).label);
</script>

<template>
  <section class="block" v-if="st">
    <div class="head">
      <h2>Blizzard-API prüfen</h2>
      <button class="primary" v-if="st.saved" :disabled="!!busy" @click="check">{{ busy === 'check' ? 'Prüft' : 'Jetzt prüfen' }}</button>
    </div>
    <p class="muted lead">Prüft, ob Blizzard Auktionsdaten für Forever liefert. Das ist noch nicht bestätigt. Eingelesen wird dabei nichts.</p>

    <div v-if="st.saved" class="saved">
      <span>Zugang gespeichert (Client-ID endet auf {{ st.idEnd }}, {{ regionLabel }})</span>
      <button class="danger" :disabled="!!busy" @click="clear">{{ confirmClear ? 'Wirklich entfernen?' : 'Zugang entfernen' }}</button>
      <button v-if="confirmClear" @click="confirmClear = false">Abbrechen</button>
    </div>
    <template v-else>
      <p class="small warn" v-if="st.unreadable">Der gespeicherte Zugang lässt sich auf diesem Rechner nicht lesen. Bitte neu eintragen.</p>
      <ol class="how">
        <li>Melde dich mit deinem Battle.net-Konto bei <button class="link" @click="api.openLink('https://develop.battle.net/access/clients')">develop.battle.net</button> an.</li>
        <li>Lege dort einen neuen Client an. Der Name ist frei wählbar, zum Beispiel „Peon Manager“.</li>
        <li>Trage hier die Client-ID und das Client-Secret ein.</li>
      </ol>
      <div class="form">
        <label>Client-ID<input v-model="clientId" type="text" autocomplete="off" spellcheck="false"></label>
        <label>Client-Secret<input v-model="clientSecret" type="password" autocomplete="off" spellcheck="false"></label>
        <label>Region
          <select v-model="region"><option v-for="r in REGIONS" :key="r.id" :value="r.id">{{ r.label }}</option></select>
        </label>
        <button class="primary" :disabled="!!busy || !clientId || !clientSecret" @click="save">Speichern</button>
      </div>
      <p class="small muted">Jeder braucht einen eigenen Zugang. Er liegt verschlüsselt nur auf diesem Rechner und wird nur an Blizzard geschickt. Gib das Client-Secret nicht weiter.</p>
    </template>

    <p class="small warn" v-if="error" role="alert">{{ error }}</p>

    <div v-if="report" class="report" :class="{ good }">
      <p><strong>{{ report.text }}</strong></p>
      <p class="small muted">Geprüft {{ ago(report.t, props.now) }}, Bereich {{ report.namespace }}</p>
      <table class="steps">
        <tbody>
          <tr v-for="(s, k) in report.steps" :key="k">
            <td>{{ s.name }}</td>
            <td class="muted">{{ s.status == null ? 'keine Antwort' : s.status }}</td>
            <td class="muted">{{ s.note || '' }}</td>
          </tr>
        </tbody>
      </table>
      <p class="small muted" v-if="report.sample">{{ report.sample.count }} Angebote, Felder: {{ report.sample.fields.join(', ') }}</p>
    </div>
  </section>
</template>

<style scoped>
.block { display: grid; gap: 12px; }
.head { display: flex; justify-content: space-between; align-items: center; }
.lead { max-width: 72ch; }
.saved { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.saved span { margin-right: auto; }
.how { margin: 0; padding-left: 22px; display: grid; gap: 4px; }
.form { display: grid; grid-template-columns: minmax(180px, 1fr) minmax(180px, 1fr) 130px auto; gap: 14px; align-items: end; }
.form label { display: grid; gap: 6px; }
.form input, .form select { width: 100%; box-sizing: border-box; height: 40px; }
.form button { height: 40px; }
.report { display: grid; gap: 8px; padding: 14px 16px; border: 1px solid var(--line); border-radius: var(--radius-s); }
.report.good { border-color: var(--accent); }
.report p { margin: 0; }
.steps { width: 100%; border-collapse: collapse; }
.steps td { padding: 5px 10px 5px 0; border-bottom: 1px solid var(--line-soft); }
.steps tr:last-child td { border-bottom: none; }
.warn { color: var(--warn); }
</style>
