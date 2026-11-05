<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import { bytes } from '../util.js';
import BlizzardCheck from '../components/BlizzardCheck.vue';

const props = defineProps({ data: Object, settings: Object, stamp: Number, broker: Boolean, now: Number });
const emit = defineEmits(['save']);
const api = window.peon;
const wowDir = ref(props.settings.wowDir);
watch(() => props.settings.wowDir, (v) => { wowDir.value = v; });

async function pick() {
  const p = await api.pickFolder();
  if (p) { wowDir.value = p; emit('save', { wowDir: p }); }
}
function saveWow() { if (wowDir.value && wowDir.value !== props.settings.wowDir) emit('save', { wowDir: wowDir.value }); }
async function setChannel(c) { await api.setAddonChannel(c); emit('save', {}); }

// Aufbewahrung: Stufen des Schiebers (Tage, 0 = unbegrenzt)
const STEPS = [7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365, 0];
const stepOf = (d) => { const i = STEPS.indexOf(d); return i >= 0 ? i : STEPS.indexOf(30); };
const step = ref(stepOf(props.settings.keepDays));
const est = ref(null);
const days = computed(() => STEPS[step.value]);
let timer = null;
async function estimate() { est.value = props.broker ? await api.retention(days.value) : null; }
watch(step, () => { clearTimeout(timer); timer = setTimeout(estimate, 120); });
watch(() => props.stamp, estimate);
watch(() => props.broker, estimate);
watch(() => props.settings.keepDays, (v) => { step.value = stepOf(v); });
onMounted(estimate);
function saveKeep() { if (days.value !== props.settings.keepDays) emit('save', { keepDays: days.value }); }
const daysText = computed(() => (days.value === 0 ? 'unbegrenzt' : days.value === 1 ? '1 Tag' : `${days.value} Tage`));
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
      <h2>Addons</h2>
      <label class="field inline">
        <span>Kanal</span>
        <select :value="settings.addons.channel" @change="setChannel($event.target.value)">
          <option value="stable">Stabil</option><option value="test">Test (Vorabversionen)</option>
        </select>
      </label>
      <p class="small muted">Der Manager sucht beim Start und alle 6 Stunden nach neuen Versionen. Installiert wird nur, wenn du es unter Module auslöst.</p>
    </section>

    <div class="group">
      <BlizzardCheck :now="now" :stamp="stamp" />
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
    </section>

    <section class="group" v-if="broker">
      <h2>Aufbewahrung <span class="small muted">(Peon Broker Client)</span></h2>
      <label class="field">
        <span>Momentaufnahmen vollständig aufheben: <strong>{{ daysText }}</strong></span>
        <input type="range" min="0" :max="STEPS.length - 1" step="1" v-model.number="step" @change="saveKeep" aria-label="Tage vollständig aufheben" />
      </label>
      <p class="small muted">Danach bleiben Stundenwerte {{ settings.hourDays }} Tage, ältere Daten als Tageswerte unbegrenzt. Kopfdaten jedes Scans (Zeit, Anzahl Angebote) bleiben immer.</p>
      <div class="est" v-if="est">
        <div><span class="muted">Jetzt</span><strong>{{ bytes(est.current) }}</strong></div>
        <div><span class="muted">Geschätzt nach einem Jahr</span><strong>{{ days === 0 ? 'wächst weiter' : bytes(est.total) }}</strong></div>
        <div class="small muted wide" v-if="days !== 0">
          davon vollständige Momentaufnahmen {{ bytes(est.fine) }}, Stundenwerte {{ bytes(est.hour) }}, Tageswerte {{ bytes(est.dayPerYear) }} im Jahr.
          Gerechnet mit {{ est.scansPerDay.toLocaleString('de-DE') }} {{ est.scansPerDay === 1 ? 'Scan' : 'Scans' }} am Tag zu je etwa {{ bytes(est.perScan) }}{{ est.measured ? ' (aus deinen Daten)' : ' (Annahme, noch keine Scans)' }}.
        </div>
        <div class="small muted wide" v-else>Ohne Grenze wächst die Datenbank um etwa {{ bytes(est.perScan * est.scansPerDay * 30) }} im Monat.</div>
      </div>
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
.warn { color: var(--warn); }
</style>
