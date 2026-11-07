<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { bytes, when } from '../util.js';
import BlizzardCheck from '../components/BlizzardCheck.vue';

const props = defineProps({ data: Object, settings: Object, stamp: Number, broker: Boolean, now: Number });
const emit = defineEmits(['save', 'go']);
const api = window.peon;
const wowDir = ref(props.settings.wowDir);
watch(() => props.settings.wowDir, (v) => { wowDir.value = v; });

async function pick() {
  const p = await api.pickFolder();
  if (p) { wowDir.value = p; emit('save', { wowDir: p }); }
}
function saveWow() { if (wowDir.value && wowDir.value !== props.settings.wowDir) emit('save', { wowDir: wowDir.value }); }

// Datensicherung
const backupBusy = ref('');
const backupText = ref('');
const backupError = ref('');
const restore = ref(null);
const cleanError = (e) => String((e && e.message) || e).replace(/^Error invoking remote method '[^']*': (Error: )?/, '');
async function makeBackup() {
  backupBusy.value = 'create'; backupText.value = ''; backupError.value = '';
  try {
    const r = await api.backupCreate();
    if (r) backupText.value = `Sicherung angelegt (${bytes(r.bytes)}): ${r.dir}`;
  } catch (e) { backupError.value = cleanError(e); } finally { backupBusy.value = ''; }
}
async function pickBackup() {
  backupText.value = ''; backupError.value = ''; restore.value = null;
  try { restore.value = await api.backupPick(); } catch (e) { backupError.value = cleanError(e); }
}

// Aufbewahrung: Stufen der Schieber (Tage, bei den Angeboten 0 = unbegrenzt). Erst "Übernehmen" speichert.
const KEEP = [7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365, 0];
const HOUR = [14, 30, 60, 90, 120, 180, 270, 365];
const keepOf = (d) => { const i = KEEP.indexOf(d); return i >= 0 ? i : KEEP.indexOf(14); };
const hourOf = (d) => { const i = HOUR.findIndex((x) => x >= d); return i >= 0 ? i : HOUR.length - 1; };
const keepStep = ref(keepOf(props.settings.keepDays));
const hourStep = ref(hourOf(props.settings.hourDays));
const keep = computed(() => KEEP[keepStep.value]);
const hour = computed(() => HOUR[hourStep.value]);
const est = ref(null);
let timer = null;
async function estimate() { est.value = props.broker ? await api.retention(keep.value, hour.value) : null; }
watch([keepStep, hourStep], () => { clearTimeout(timer); timer = setTimeout(estimate, 120); });
watch(() => props.stamp, estimate);
watch(() => props.broker, estimate);
watch([() => props.settings.keepDays, () => props.settings.hourDays], () => reset());
onMounted(estimate);

// Stundenwerte entstehen erst, wenn die Angebote zusammengefasst werden: Beide Schieber bleiben in dieser Reihenfolge
function onKeep() { if (keep.value > hour.value) hourStep.value = hourOf(keep.value); }
function onHour() {
  if (keep.value <= hour.value) return;
  let i = keepStep.value;
  while (KEEP[i] === 0 || KEEP[i] > hour.value) i--;
  keepStep.value = i;
}
function reset() { keepStep.value = keepOf(props.settings.keepDays); hourStep.value = hourOf(props.settings.hourDays); }
function usePreset(p) { keepStep.value = keepOf(p.keepDays); hourStep.value = hourOf(p.hourDays); }
const changed = computed(() => keepStep.value !== keepOf(props.settings.keepDays) || hourStep.value !== hourOf(props.settings.hourDays));
const isPreset = (p) => keep.value === p.keepDays && hour.value === p.hourDays;
function saveRetention() { emit('save', { keepDays: keep.value, hourDays: hour.value }); }
const daysText = (d) => (d === 0 ? 'unbegrenzt' : `${d} Tage`);
const share = (v) => (est.value && est.value.total ? `${(v / est.value.total) * 100}%` : '0%');
</script>

<template>
  <div class="set">
    <h1>Einstellungen</h1>

    <section class="group">
      <h2>World of Warcraft</h2>
      <label class="field">
        <span>WoW-Ordner</span>
        <div class="row">
          <input type="text" v-model="wowDir" @change="saveWow" spellcheck="false" />
          <button @click="pick">Ordner wählen</button>
        </div>
        <span class="small" :class="data.wowOk ? 'ok' : 'warn'">
          {{ data.wowOk ? 'Peon_Bridge gefunden. Der Manager liest WTF und schreibt Data.lua in den Addon-Ordner.' : 'Peon_Bridge nicht gefunden. Gemeint ist der Ordner mit Interface und WTF, z. B. C:\\Program Files (x86)\\World of Warcraft\\_forever_.' }}
        </span>
      </label>
    </section>

    <section class="group">
      <h2>Updates</h2>
      <label class="check"><input type="checkbox" :checked="settings.updateWindow" @change="emit('save', { updateWindow: $event.target.checked })" /> Beim Start zeigen, wenn es Neues gibt</label>
      <label class="check"><input type="checkbox" :checked="settings.updateNotify" @change="emit('save', { updateNotify: $event.target.checked })" /> Meldung von Windows, wenn es Neues gibt</label>
      <label class="field inline">
        <span>Nach Updates suchen</span>
        <select :value="settings.updateCheckMin" @change="emit('save', { updateCheckMin: Number($event.target.value) })">
          <option :value="10">alle 10 Minuten</option><option :value="30">alle 30 Minuten</option>
          <option :value="60">jede Stunde</option><option :value="360">alle 6 Stunden</option>
        </select>
      </label>
      <p class="small muted">Der Manager sucht beim Start und dann im gewählten Abstand nach neuen Versionen. Installiert wird nur, wenn du es auslöst. Kanal und Suche stehen im Reiter Updates.</p>
    </section>

    <div class="group">
      <BlizzardCheck :now="now" :stamp="stamp" :broker="broker" :houses="data && data.api ? data.api.selected : null" @go="emit('go', $event)" />
    </div>

    <section class="group">
      <h2>Programm</h2>
      <label class="check"><input type="checkbox" :checked="settings.autostart" @change="emit('save', { autostart: $event.target.checked })" /> Mit Windows starten (unsichtbar im Infobereich)</label>
      <label class="field inline">
        <span>Aussehen</span>
        <select :value="settings.theme" @change="emit('save', { theme: $event.target.value })">
          <option value="dark">Dunkel</option><option value="light">Hell</option>
        </select>
      </label>
      <p class="small muted">Das Fenster schließen lässt den Manager im Infobereich weiterlaufen. Beenden geht über das Symbol im Infobereich.</p>
    </section>

    <section class="group">
      <h2>Daten</h2>
      <div class="row between">
        <span>Datenordner <span class="muted">{{ data.dbDir }}</span></span>
        <button @click="api.openFolder('db')">Ordner öffnen</button>
      </div>
      <p>{{ broker ? 'Datenbank des Broker Client' : 'Datenbank des Managers' }} {{ bytes(data.dbSize) }}</p>
      <div class="row">
        <button :disabled="!!backupBusy" @click="makeBackup">{{ backupBusy === 'create' ? 'Sichert' : 'Sicherung anlegen' }}</button>
        <button :disabled="!!backupBusy" @click="pickBackup">Sicherung einspielen</button>
      </div>
      <p class="small muted">Eine Sicherung enthält Datenbanken und Einstellungen. Der Zugang zur Blizzard-API ist nicht dabei, auf einem anderen Rechner trägst du ihn neu ein.</p>
      <p class="small ok" v-if="backupText" role="status">{{ backupText }}</p>
      <p class="small warn" v-if="backupError" role="alert">{{ backupError }}</p>
      <div class="apply" v-if="restore">
        <p class="small warn" role="alert">Sicherung vom {{ when(restore.t) }} ({{ bytes(restore.bytes) }}) einspielen? Der Manager startet dafür neu. Der bisherige Stand bleibt im Datenordner unter „vor-Wiederherstellung“ liegen.</p>
        <div class="row">
          <button class="primary" @click="api.backupRestore(restore.dir)">Einspielen und neu starten</button>
          <button @click="restore = null">Abbrechen</button>
        </div>
      </div>
    </section>

    <section class="group" v-if="broker">
      <h2>Aufbewahrung <span class="small muted">(Peon Broker Client)</span></h2>
      <p class="small muted">Je länger der Manager genaue Daten aufhebt, desto mehr Platz braucht er. Ältere Daten fasst er zusammen, dein Preisverlauf bleibt dabei erhalten, nur gröber.</p>

      <div class="presets" v-if="est" role="group" aria-label="Vorlagen">
        <button v-for="p in est.presets" :key="p.key" :class="{ on: isPreset(p) }" :aria-pressed="isPreset(p)" @click="usePreset(p)">
          <strong>{{ p.label }}</strong>
          <span class="small muted">etwa {{ bytes(p.total) }}</span>
        </button>
      </div>

      <label class="field">
        <span>Alle Angebote: <strong>{{ daysText(keep) }}</strong></span>
        <input type="range" min="0" :max="KEEP.length - 1" step="1" v-model.number="keepStep" @input="onKeep" aria-label="Alle Angebote aufheben" />
        <span class="small muted">Jedes einzelne Angebot jedes Stands. Daraus zeigt der Manager auch das Muster „Wann ist es günstig?“, das bis zu 60 Tage nutzt.</span>
      </label>
      <label class="field">
        <span>Stundenwerte bis: <strong>{{ keep === 0 ? 'nicht nötig' : daysText(hour) }}</strong></span>
        <input type="range" min="0" :max="HOUR.length - 1" step="1" v-model.number="hourStep" :disabled="keep === 0" @input="onHour" aria-label="Stundenwerte aufheben bis" />
        <span class="small muted">Preise und Mengen je Gegenstand und Stunde. Mindestens 14 Tage, weil Broker daraus den üblichen Preisbereich bekommt.</span>
      </label>
      <p class="small muted">Danach bleibt ein Wert je Tag, ohne Ende. Zeit und Anzahl der Angebote jedes Stands bleiben immer.</p>

      <div class="est" v-if="est">
        <div><span class="muted">Jetzt</span><strong>{{ bytes(est.current) }}</strong></div>
        <div><span class="muted">Geschätzt nach einem Jahr</span><strong>{{ keep === 0 ? 'wächst weiter' : bytes(est.total) }}</strong></div>
        <template v-if="keep !== 0">
          <div class="bar wide" aria-hidden="true">
            <span class="b-fine" :style="{ width: share(est.fine) }"></span><span class="b-hour" :style="{ width: share(est.hour) }"></span><span class="b-day" :style="{ width: share(est.dayFirstYear) }"></span>
          </div>
          <div class="small muted wide legend">
            <span><i class="b-fine"></i>Alle Angebote {{ bytes(est.fine) }}</span>
            <span><i class="b-hour"></i>Stundenwerte {{ bytes(est.hour) }}</span>
            <span><i class="b-day"></i>Tageswerte {{ bytes(est.dayFirstYear) }}, danach {{ bytes(est.dayPerYear) }} je weiteres Jahr</span>
          </div>
          <div class="small muted wide">Gerechnet mit {{ est.scansPerDay.toLocaleString('de-DE') }} {{ est.scansPerDay === 1 ? 'Stand' : 'Ständen' }} am Tag (Scans und Blizzard-API) zu je etwa {{ bytes(est.perScan) }}{{ est.measured ? ', aus deinen Daten' : ', geschätzt, weil es noch keine Daten gibt' }}.</div>
        </template>
        <div class="small muted wide" v-else>Ohne Grenze wächst die Datenbank um etwa {{ bytes(est.perScan * est.scansPerDay * 30) }} im Monat.</div>
      </div>

      <div class="apply" v-if="changed">
        <p class="small warn" v-if="est && est.wouldCompact" role="alert">Daten, die älter sind als die neue Grenze, werden beim Übernehmen zusammengefasst. Die genauen Werte lassen sich danach nicht zurückholen.</p>
        <div class="row">
          <button class="primary" @click="saveRetention">Übernehmen</button>
          <button @click="reset">Verwerfen</button>
        </div>
      </div>
      <p class="small muted" v-if="data.pruning" role="status">Der Manager räumt gerade im Hintergrund auf.</p>
    </section>
  </div>
</template>

<style scoped>
.set { display: grid; gap: 30px; max-width: 760px; }
.group { display: grid; gap: 10px; padding-bottom: 24px; border-bottom: 1px solid var(--line-soft); }
.field { display: grid; gap: 6px; }
.field.inline { grid-template-columns: 110px auto; align-items: center; justify-content: start; gap: 12px; }
.row { display: flex; gap: 10px; align-items: center; }
.between { justify-content: space-between; }
.check { display: flex; gap: 10px; align-items: center; }
.ok { color: var(--accent); }
input[type="range"] { width: 100%; accent-color: var(--accent); }
.est { display: grid; grid-template-columns: auto auto 1fr; gap: 6px 36px; align-items: baseline; }
.est > div { display: grid; gap: 2px; }
.est strong { font-size: 18px; font-weight: 500; }
.est .wide { grid-column: 1 / -1; display: block; }
.presets { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
.presets button { display: grid; gap: 2px; padding: 8px 10px; text-align: left; }
.presets button strong { font-weight: 500; }
.presets button.on { border-color: var(--accent); background: var(--accent-soft); }
.est .bar { display: flex; height: 10px; border-radius: 5px; overflow: hidden; background: var(--raised); }
.bar span { display: block; }
.b-fine { background: var(--accent); }
.b-hour { background: var(--silver); }
.b-day { background: var(--faint); }
.est .legend { display: flex; flex-wrap: wrap; gap: 4px 16px; }
.legend i { display: inline-block; width: 9px; height: 9px; border-radius: 2px; margin-right: 6px; }
.apply { display: grid; gap: 8px; }
input[type="range"]:disabled { opacity: 0.4; }
.warn { color: var(--warn); }
</style>
