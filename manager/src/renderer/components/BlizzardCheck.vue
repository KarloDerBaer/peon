<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { ago } from '../util.js';

// houses: Zahl der unter Quellen gewählten Häuser (null, wenn der Broker Client fehlt), broker: Broker Client aktiv
const props = defineProps({ now: Number, stamp: Number, houses: Number, broker: Boolean });
const emit = defineEmits(['go']);
const api = window.peon;

const REGIONS = [{ id: 'eu', label: 'Europa' }, { id: 'us', label: 'Amerika' }, { id: 'tw', label: 'Taiwan' }];
// Anleitung nach Blizzards Getting Started (geprueft 05.11.2026)
const PORTAL = 'https://community.developer.battle.net/access/clients';
const STEPS = [{ title: 'Authenticator' }, { title: 'Entwicklerportal' }, { title: 'Neuer Client' }, { title: 'Formular ausfüllen' }, { title: 'Eintragen' }];
const step = ref(0);
const st = ref(null);
const clientId = ref('');
const clientSecret = ref('');
const region = ref('eu');
const busy = ref('');
const error = ref('');
const confirmClear = ref(false);
const justSaved = ref(false);

function apply(s) {
  st.value = s;
  if (s.saved) region.value = s.region;
}
onMounted(async () => apply(await api.blizzardState()));
watch(() => props.stamp, async () => apply(await api.blizzardState()));

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
    justSaved.value = true;
    return s;
  });
}
function check() { return run('check', () => api.blizzardCheck()); }
function clear() {
  if (!confirmClear.value) { confirmClear.value = true; return undefined; }
  confirmClear.value = false;
  justSaved.value = false;
  return run('clear', () => api.blizzardClear());
}
const report = computed(() => st.value && st.value.report);
const good = computed(() => report.value && report.value.result === 'auctions');
// Neue Zugänge brauchen bei Blizzard ein paar Minuten: Hinweis nach dem Speichern, bis eine Prüfung klappt
const waitHint = computed(() => !!(st.value && st.value.saved) && !good.value && (justSaved.value || !report.value));
const noHouse = computed(() => !!(st.value && st.value.saved) && !props.houses);
const regionLabel = computed(() => (REGIONS.find((r) => r.id === (st.value && st.value.region)) || REGIONS[0]).label);
</script>

<template>
  <section class="block" v-if="st">
    <div class="head">
      <h2>Blizzard-API</h2>
      <button class="primary" v-if="st.saved" :disabled="!!busy" @click="check">{{ busy === 'check' ? 'Prüft' : 'Zugang prüfen' }}</button>
    </div>
    <p class="muted lead">Mit einem eigenen Zugang kann der Manager Daten direkt bei Blizzard abfragen, zum Beispiel die Auktionshäuser von Forever. Welche Häuser er abruft, wählst du mit dem Peon Broker Client unter Datenlage.</p>
    <p class="small"><button class="link" @click="api.openLink(PORTAL)">{{ st.saved ? 'Zugang bei Blizzard verwalten' : 'Zugang bei Blizzard beantragen' }}</button> <span class="muted">(Entwicklerportal von Blizzard, auf Englisch)</span></p>

    <div v-if="st.saved" class="saved">
      <span>Zugang gespeichert (Client-ID endet auf {{ st.idEnd }}, {{ regionLabel }})</span>
      <button class="danger" :disabled="!!busy" @click="clear">{{ confirmClear ? 'Wirklich entfernen?' : 'Zugang entfernen' }}</button>
      <button v-if="confirmClear" @click="confirmClear = false">Abbrechen</button>
    </div>
    <p v-if="waitHint" class="note">Ein neuer Zugang funktioniert bei Blizzard oft erst nach ein paar Minuten. Schlägt „Zugang prüfen“ gleich nach dem Speichern fehl, versuche es etwas später noch einmal.</p>
    <p v-if="noHouse" class="note">
      Wähle unter Datenlage mindestens ein Auktionshaus aus, sonst ruft der Manager bei Blizzard nichts ab.
      <button v-if="props.broker" class="link" @click="emit('go', 'sources')">Zur Datenlage</button>
      <template v-else>Dafür brauchst du den Peon Broker Client. <button class="link" @click="emit('go', 'modules')">Unter Updates installieren</button></template>
    </p>
    <template v-else>
      <p class="small warn" v-if="st.unreadable">Der gespeicherte Zugang lässt sich auf diesem Rechner nicht lesen. Bitte neu eintragen.</p>
      <div class="tutorial" aria-live="polite">
        <div class="t-head">
          <strong>Anleitung: Schritt {{ step + 1 }} von {{ STEPS.length }}: {{ STEPS[step].title }}</strong>
          <span class="dots" aria-hidden="true"><i v-for="(s, k) in STEPS" :key="k" :class="{ on: k <= step }"></i></span>
        </div>
        <p v-if="step === 0">Blizzard verlangt für die API einen Battle.net Authenticator auf deinem Konto. Hast du noch keinen, richte ihn zuerst in den Sicherheitseinstellungen deines Battle.net-Kontos ein. Ein Battle.net-Konto hast du durch WoW bereits.</p>
        <template v-else-if="step === 1">
          <p>Öffne das Entwicklerportal von Blizzard und melde dich mit deinem Battle.net-Konto an. Die Seite ist auf Englisch. Bestätige die Nutzungsbedingungen, falls Blizzard danach fragt.</p>
          <p><button class="link" @click="api.openLink(PORTAL)">Entwicklerportal öffnen</button></p>
        </template>
        <p v-else-if="step === 2">Klicke oben auf <strong>API Access</strong> und dann auf <strong>Create New Client</strong>.</p>
        <ul v-else-if="step === 3">
          <li><strong>Client Name:</strong> Frei wählbar, muss aber bei Blizzard einmalig sein, zum Beispiel „Peon Manager“ mit deinem Namen dahinter.</li>
          <li><strong>Redirect URIs:</strong> Braucht der Manager nicht. Lässt Blizzard das Feld nicht leer, trage <code>http://localhost</code> ein.</li>
          <li><strong>Service URL:</strong> Setze den Haken, dass du keine Service URL hast.</li>
          <li><strong>Intended Use:</strong> Kurz beschreiben, zum Beispiel „Auktionsdaten für meine eigene Auswertung im Peon Manager“.</li>
          <li>Dann auf <strong>Create</strong> klicken.</li>
        </ul>
        <p v-else>Unter <strong>Manage Client</strong> stehen die <strong>Client ID</strong> und das <strong>Client Secret</strong>. Fehlt das Secret, erzeugst du es dort mit <strong>Generate New Secret</strong>. Trage beides unten ein. Danach wählst du unter Datenlage die Auktionshäuser aus.</p>
        <div class="t-nav">
          <button :disabled="step === 0" @click="step--">Zurück</button>
          <button v-if="step < STEPS.length - 1" @click="step++">Weiter</button>
        </div>
      </div>
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
      <p class="small muted" v-if="report.sample">Haus {{ report.sample.house }}: {{ report.sample.count }} Angebote, Felder: {{ report.sample.fields.join(', ') }}</p>
    </div>

    <p class="small muted" v-if="st.watch">
      Beobachter (Testfassung): {{ st.watch.checks }} Prüfungen, {{ st.watch.stands }} Stände<template v-if="st.watch.lastModified">, letzter Stand {{ st.watch.lastModified }}</template><template v-if="st.watch.gaps.length">, Abstände in Minuten: {{ st.watch.gaps.join(', ') }}</template>
      <span class="warn" v-if="st.watch.lastError"> Zuletzt fehlgeschlagen: {{ st.watch.lastError.where || 'Abfrage' }}, Code {{ st.watch.lastError.status == null ? 'keine Antwort' : st.watch.lastError.status }}</span>
    </p>
  </section>
</template>

<style scoped>
.block { display: grid; gap: 12px; }
.head { display: flex; justify-content: space-between; align-items: center; }
.lead { max-width: 72ch; }
.saved { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; }
.saved span { margin-right: auto; }
.tutorial { display: grid; gap: 10px; padding: 14px 16px; border: 1px solid var(--line); border-radius: var(--radius-s); background: var(--panel); }
.tutorial p, .tutorial ul { margin: 0; max-width: 72ch; }
.tutorial ul { padding-left: 20px; display: grid; gap: 6px; }
.t-head { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
.dots { display: inline-flex; gap: 6px; }
.dots i { width: 8px; height: 8px; border-radius: 50%; background: var(--line); }
.dots i.on { background: var(--accent); }
.t-nav { display: flex; gap: 10px; }
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
.note { margin: 0; max-width: 72ch; padding: 10px 14px; border-left: 3px solid var(--accent); background: var(--panel); border-radius: var(--radius-s); }
</style>
