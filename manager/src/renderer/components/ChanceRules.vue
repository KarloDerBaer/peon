<!-- Regler je Art mit Probe (Peon_Manager_Chancen.md 7.3), Schalter je Signal der Prognosen, eigene Ereignisse (5.4)
     und alle Uebersteuerungen je Gegenstand (7.2). Uebernommen wird erst mit „Übernehmen“. -->
<script setup>
import { ref, reactive, onMounted, watch, computed } from 'vue';
import Gold from './Gold.vue';
import MoneyInput from './MoneyInput.vue';
import { qualityColor, num } from '../util.js';

const props = defineProps({ market: String, stamp: Number, onlyOverrides: Boolean });
const emit = defineEmits(['open']);
const api = window.peon;

// Wie spec.SLIDERS im Rechenkern
const SLIDERS = {
  s: [
    { key: 'gap', label: 'So viel günstiger als verkauft', unit: '%', min: 0.05, max: 0.8, step: 0.05 },
    { key: 'nProof', label: 'Mindestens so viele Verkäufe gesehen', unit: 'Stück', min: 1, max: 30, step: 1 },
    { key: 'maxDays', label: 'Höchstens so lange bis zum Verkauf', unit: 'Tage', min: 0.5, max: 14, step: 0.5 },
    { key: 'minGain', label: 'Mindestgewinn', unit: 'gold' },
  ],
  l: [
    { key: 'rise', label: 'Erwarteter Anstieg nach Gebühr mindestens', unit: '%', min: 0.05, max: 1, step: 0.05 },
    { key: 'maxDays', label: 'Zeitraum der Prognose höchstens', unit: 'Tage', min: 1, max: 30, step: 1 },
  ],
  v: [{ key: 'minGain', label: 'Mindestgewinn', unit: 'gold' }],
};
const KIND = { s: 'Spekulation schnell', l: 'Spekulation langfristig', v: 'Händler' };
const SIGNALS = { scarce: 'Knappheit', glut: 'Schwemme', level: 'Stufenbereich', fest: 'Fest', week: 'Wochenrhythmus' };
const rules = ref(null);
const draft = reactive({ s: {}, l: {}, v: {} });
const probes = reactive({});
const over = ref([]);
const events = ref([]);
const newEvent = reactive({ n: '', s: '', e: '' });

async function load() {
  rules.value = await api.chanceRules();
  for (const k of Object.keys(SLIDERS)) draft[k] = { ...(rules.value ? rules.value[k] : {}) };
  over.value = await api.overrides();
  events.value = (await api.fests()).filter((f) => f.own);
}
onMounted(load);
watch(() => props.stamp, load);

const changed = (k) => rules.value && SLIDERS[k].some((s) => draft[k][s.key] !== rules.value[k][s.key]);
let timer = null;
function probe(k) {
  clearTimeout(timer);
  timer = setTimeout(async () => { probes[k] = changed(k) && props.market ? await api.chanceProbe(props.market, k, { ...draft[k] }) : null; }, 250);
}
async function apply(k) { await api.setChanceRules({ [k]: { ...draft[k] } }); probes[k] = null; await load(); }
async function reset(k) { await api.resetChanceRules(k); probes[k] = null; await load(); }
async function setSignal(id, v) { await api.setChanceRules({ f: { signals: { [id]: v } } }); await load(); }
async function setMinSure(v) { await api.setChanceRules({ f: { minSure: v } }); await load(); }
const show = (s, v) => (s.unit === '%' ? `${Math.round(v * 100)} %` : s.unit === 'Tage' ? `${String(v).replace('.', ',')} Tage` : `${v} Stück`);
const rateText = (x) => (x.rate == null ? 'noch nicht nachgeprüft' : `${Math.round(x.rate * 100)} % gelohnt`);
const ratingText = (o) => Object.entries(o || {}).map(([k, n]) => `${n} als „${k}“`).join(', ');

async function removeOverride(key) { await api.setOverride(key, {}); await load(); }
function dateIn(s) { const t = Date.parse(s); return Number.isFinite(t) ? Math.floor(t / 1000) : null; }
async function addEvent() {
  const s = dateIn(newEvent.s), e = dateIn(newEvent.e) || s;
  if (!newEvent.n.trim() || !s) return;
  await api.setEvents([...events.value.map(({ n, s: a, e: b }) => ({ n, s: a, e: b })), { n: newEvent.n.trim(), s, e }]);
  newEvent.n = ''; newEvent.s = ''; newEvent.e = '';
  await load();
}
async function removeEvent(i) { await api.setEvents(events.value.filter((_, j) => j !== i).map(({ n, s, e }) => ({ n, s, e }))); await load(); }
const day = (t) => new Date(t * 1000).toLocaleDateString('de-DE');
const sig = computed(() => (rules.value ? rules.value.f.signals : {}));
</script>

<template>
  <div class="rules" v-if="rules">
    <template v-if="!onlyOverrides">
      <section v-for="(list, k) in SLIDERS" :key="k" class="box">
        <div class="bh"><h3>{{ KIND[k] }}</h3><button class="link small" @click="reset(k)">Standard</button></div>
        <div v-for="s in list" :key="s.key" class="sl">
          <span class="lab">{{ s.label }}</span>
          <template v-if="s.unit === 'gold'">
            <MoneyInput :value="draft[k][s.key]" :label="s.label" @change="draft[k][s.key] = $event || 0; probe(k)" />
          </template>
          <template v-else>
            <input type="range" :min="s.min" :max="s.max" :step="s.step" v-model.number="draft[k][s.key]" @input="probe(k)" :aria-label="s.label" />
            <span class="val">{{ show(s, draft[k][s.key]) }}</span>
          </template>
        </div>
        <p class="probe small" v-if="probes[k]">
          Probe über {{ probes[k].days }} Tage: Mit diesen Werten wären es {{ num(probes[k].after.n) }} statt {{ num(probes[k].before.n) }} Vorschläge gewesen,
          davon {{ rateText(probes[k].after) }} statt {{ rateText(probes[k].before) }}.
          <template v-if="ratingText(probes[k].ratingsAdded)"> Neu dazu kämen welche, die du {{ ratingText(probes[k].ratingsAdded) }} markiert hattest.</template>
          <template v-if="ratingText(probes[k].ratingsRemoved)"> Weg fielen welche, die du {{ ratingText(probes[k].ratingsRemoved) }} markiert hattest.</template>
        </p>
        <div class="row" v-if="changed(k)">
          <button class="primary" @click="apply(k)">Übernehmen</button>
          <button @click="draft[k] = { ...rules[k] }; probes[k] = null">Verwerfen</button>
        </div>
      </section>

      <section class="box">
        <div class="bh"><h3>Prognosen</h3></div>
        <p class="small muted">Ein Signal mit weniger als 20 nachgeprüften Fällen heißt „neu“ und zählt nicht für die Sicherheit. Unter 40 % Trefferquote schaltet es sich aus, bis du es hier wieder einschaltest.</p>
        <div v-for="(lab, id) in SIGNALS" :key="id" class="sl">
          <span class="lab">{{ lab }}</span>
          <select :value="String(sig[id])" @change="setSignal(id, $event.target.value === 'true' ? true : $event.target.value === 'false' ? false : 'force')" :aria-label="lab">
            <option value="true">an</option><option value="false">aus</option><option value="force">an, auch bei schlechter Trefferquote</option>
          </select>
        </div>
        <div class="sl"><span class="lab">Mindest-Sicherheit in der Marktübersicht</span>
          <select :value="rules.f.minSure" @change="setMinSure($event.target.value)" aria-label="Mindest-Sicherheit">
            <option value="low">niedrig</option><option value="mid">mittel</option><option value="high">hoch</option>
          </select>
        </div>
      </section>

      <section class="box">
        <div class="bh"><h3>Eigene Ereignisse</h3></div>
        <p class="small muted">Feste kommen aus dem Spiel (Broker liest den Kalender). Hier lassen sich weitere Ereignisse eintragen, etwa eine neue Inhaltsphase.</p>
        <div v-for="(e, i) in events" :key="i" class="ev">{{ e.n }}: {{ day(e.s) }}<template v-if="e.e && e.e !== e.s"> bis {{ day(e.e) }}</template> <button class="link small" @click="removeEvent(i)">entfernen</button></div>
        <div class="row">
          <input type="text" v-model="newEvent.n" placeholder="Name" aria-label="Name des Ereignisses" />
          <input type="date" v-model="newEvent.s" aria-label="Beginn" />
          <input type="date" v-model="newEvent.e" aria-label="Ende" />
          <button @click="addEvent">Eintragen</button>
        </div>
      </section>
    </template>

    <section class="box">
      <div class="bh"><h3>Übersteuerungen je Gegenstand</h3></div>
      <p v-if="!over.length" class="small muted">Keine. Ändern lässt sich das beim Aufklappen einer Chance oder auf der Seite eines Gegenstands.</p>
      <table class="tbl" v-else>
        <tbody>
          <tr v-for="o in over" :key="o.key">
            <td><button class="link" :style="{ color: qualityColor(o.quality) }" @click="emit('open', o.key)">{{ o.name || o.key }}</button></td>
            <td class="small">
              <template v-if="o.never">nie vorschlagen </template>
              <template v-for="(on, k) in o.off || {}" :key="k"><template v-if="on">{{ KIND[k] || (k === 'b' ? 'Aufkauf' : k) }} aus </template></template>
              <template v-if="o.target">Zielpreis <Gold :copper="o.target" compact /> </template>
              <template v-if="o.limit">Kaufen bis <Gold :copper="o.limit" compact /></template>
            </td>
            <td class="num"><button class="link small" @click="removeOverride(o.key)">zurücknehmen</button></td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>

<style scoped>
.rules { display: grid; gap: 14px; max-width: 900px; }
.box { border: 1px solid var(--line-soft); border-radius: var(--radius-m); padding: 12px 16px; display: grid; gap: 8px; background: var(--raised); }
.bh { display: flex; justify-content: space-between; align-items: baseline; }
.bh h3 { margin: 0; }
.sl { display: grid; grid-template-columns: minmax(220px, 320px) 1fr 90px; gap: 12px; align-items: center; }
.lab { color: var(--muted); }
.val { text-align: right; }
.probe { margin: 0; padding: 8px 10px; border-left: 3px solid var(--accent); background: var(--accent-soft); }
.row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.ev { font-size: 14px; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl td { padding: 5px 6px; border-bottom: 1px solid var(--line-soft); }
.num { text-align: right; }
</style>
