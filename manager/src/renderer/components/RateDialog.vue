<!-- Rueckmeldung zu einem Vorschlag (Peon_Manager_Chancen.md 7.1): Daumen, ein Grund zum Anklicken, Freitext bis 250 Zeichen -->
<script setup>
import { ref } from 'vue';
const props = defineProps({ chance: Object, market: String, reasons: Array });
const emit = defineEmits(['close', 'saved']);
const up = ref(null);
const reason = ref(null);
const note = ref('');
const busy = ref(false);
const REASONS = props.reasons && props.reasons.length ? props.reasons : ['Scherzpreis', 'verkauft sich nicht', 'Zielpreis zu hoch', 'zu riskant', 'schon bekannt', 'lief gut', 'gekauft'];
async function save() {
  busy.value = true;
  try {
    const c = props.chance;
    await window.peon.rateChance({ market: props.market, key: c.key, name: c.name, kind: c.kind, up: up.value, reason: reason.value, note: note.value, say: c.say,
      data: { gain: c.gain, buy: c.buy, target: c.target, days: c.days, risk: c.risk, checks: (c.checks || []).map((k) => ({ id: k.id, value: k.value, limit: k.limit, ok: k.ok })) } });
    emit('saved');
    emit('close');
  } finally { busy.value = false; }
}
</script>

<template>
  <div class="back" @click.self="emit('close')">
    <div class="dlg" role="dialog" aria-modal="true" aria-label="Rückmeldung">
      <h2>Rückmeldung zu {{ chance.name || chance.key }}</h2>
      <p class="small muted">{{ chance.kindLabel }}: {{ chance.say }}</p>
      <div class="thumbs">
        <button :class="{ on: up === true }" @click="up = up === true ? null : true" aria-label="Daumen hoch">👍 passt</button>
        <button :class="{ on: up === false }" @click="up = up === false ? null : false" aria-label="Daumen runter">👎 passt nicht</button>
      </div>
      <div class="reasons">
        <button v-for="r in REASONS" :key="r" class="chip" :class="{ on: reason === r }" @click="reason = reason === r ? null : r">{{ r }}</button>
      </div>
      <textarea v-model="note" maxlength="250" rows="3" placeholder="Bemerkung (freiwillig, bis 250 Zeichen)" aria-label="Bemerkung"></textarea>
      <div class="row">
        <span class="small faint">{{ note.length }} / 250</span>
        <span class="grow"></span>
        <button @click="emit('close')">Abbrechen</button>
        <button class="primary" :disabled="busy || (up == null && !reason && !note.trim())" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.back { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.45); display: grid; place-items: center; z-index: 50; }
.dlg { background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius-m); padding: 20px 22px; width: min(560px, 92vw); display: grid; gap: 12px; }
.dlg h2 { margin: 0; }
.thumbs, .reasons, .row { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.chip { padding: 4px 10px; font-size: 13px; }
.on { border-color: var(--accent); background: var(--accent-soft); }
textarea { width: 100%; resize: vertical; }
.grow { flex: 1; }
</style>
