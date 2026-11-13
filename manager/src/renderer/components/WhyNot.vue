<!-- Warum (nicht)? (Peon_Manager_Chancen.md 6.2 und 7.2): Pruefliste jeder Art fuer einen Gegenstand, auch wenn er nicht
     vorgeschlagen wird, dazu die Uebersteuerung je Gegenstand -->
<script setup>
import { ref, watch, onMounted } from 'vue';
import ChecksList from './ChecksList.vue';
import MoneyInput from './MoneyInput.vue';
const props = defineProps({ market: String, itemKey: String, stamp: Number, compact: Boolean });
const emit = defineEmits(['brief']);
const d = ref(null);
const editing = ref(false);
const target = ref(null);
const limit = ref(null);
async function load() {
  if (!props.market || !props.itemKey) return;
  d.value = await window.peon.chanceItem(props.market, props.itemKey);
  const o = (d.value && d.value.override) || {};
  target.value = o.target ?? null;
  limit.value = o.limit ?? null;
}
onMounted(load);
watch(() => [props.market, props.itemKey, props.stamp], load);
async function setOv(patch) {
  const o = { ...((d.value && d.value.override) || {}), ...patch };
  await window.peon.setOverride(props.itemKey, o);
  await load();
}
function toggleOff(kind) {
  const off = { ...(((d.value && d.value.override) || {}).off || {}) };
  off[kind] = !off[kind];
  setOv({ off });
}
function undo(id) {
  if (id === 'never') setOv({ never: false });
  else if (id === 'off') setOv({ off: {} });
  else setOv({ target: null, limit: null });
}
</script>

<template>
  <div class="why" v-if="d">
    <div v-for="c in d.checks" :key="c.kind" class="kind">
      <div class="head">
        <strong>{{ c.kindLabel }}</strong>
        <span :class="c.ok ? 'ok' : 'no'">{{ c.ok ? 'wird vorgeschlagen' : 'kein Vorschlag' }}</span>
        <span class="small muted">{{ c.say }}</span>
      </div>
      <ChecksList :checks="c.checks" :signals="c.kind === 'l' && d.forecast ? d.forecast.signals : null" @undo="undo" />
    </div>
    <div class="over" v-if="!compact">
      <strong>Für diesen Gegenstand</strong>
      <label><input type="checkbox" :checked="!!(d.override && d.override.never)" @change="setOv({ never: $event.target.checked })" /> Nie vorschlagen</label>
      <label v-for="(lab, k) in { s: 'Spekulation schnell', l: 'Spekulation langfristig', b: 'Aufkauf', v: 'Händler' }" :key="k">
        <input type="checkbox" :checked="!!(d.override && d.override.off && d.override.off[k])" @change="toggleOff(k)" /> {{ lab }} aus
      </label>
      <button class="link" @click="editing = !editing">{{ editing ? 'Preise schließen' : 'Zielpreis oder Kaufen bis selbst festlegen' }}</button>
      <div v-if="editing" class="prices">
        <label>Zielpreis <MoneyInput :value="target" label="Zielpreis" @change="target = $event" /></label>
        <label>Kaufen bis <MoneyInput :value="limit" label="Kaufen bis" @change="limit = $event" /></label>
        <button @click="setOv({ target, limit })">Übernehmen</button>
        <button @click="setOv({ target: null, limit: null })">Zurücknehmen</button>
      </div>
      <button class="link" @click="emit('brief', itemKey)">Steckbrief öffnen</button>
    </div>
  </div>
  <p v-else class="small muted">Lade Prüfliste</p>
</template>

<style scoped>
.why { display: grid; gap: 14px; }
.kind { display: grid; gap: 6px; }
.head { display: flex; gap: 12px; align-items: baseline; flex-wrap: wrap; }
.ok { color: var(--up); font-weight: 600; }
.no { color: var(--muted); }
.over { display: flex; gap: 14px; flex-wrap: wrap; align-items: center; padding-top: 8px; border-top: 1px solid var(--line-soft); }
.over label { display: flex; gap: 6px; align-items: center; }
.prices { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; width: 100%; }
</style>
