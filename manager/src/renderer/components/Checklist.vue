<script setup>
// Einrichtungsliste: zeigt neuen Nutzern, was noch fehlt, bis alles läuft. Verschwindet, wenn alles erledigt oder ausgeblendet ist.
import { ref, computed, watch, onMounted } from 'vue';

const props = defineProps({ data: Object, settings: Object, stamp: Number });
const emit = defineEmits(['go', 'save']);
const api = window.peon;

const addons = ref(null);
const access = ref(null);
async function load() {
  if (props.settings.checklistHidden) return;
  const [a, b] = await Promise.all([api.addons(), api.blizzardState()]);
  addons.value = a;
  access.value = b;
}
onMounted(load);
watch(() => props.stamp, load);

const broker = computed(() => (props.data.modules || []).find((m) => m.key === 'broker-client'));
const steps = computed(() => {
  if (!addons.value || !access.value) return [];
  const on = !!(broker.value && broker.value.enabled);
  return [
    { key: 'wow', done: addons.value.wowValid, title: 'WoW-Ordner gefunden', hint: 'Der Manager muss wissen, wo WoW Forever liegt.', go: 'settings', label: 'Einstellungen' },
    { key: 'broker', done: on, title: 'Peon Broker Client installiert', hint: 'Er sammelt die Auktionsdaten und gibt Broker bessere Preise zurück.', go: 'modules', label: 'Updates' },
    { key: 'access', done: !!access.value.saved, title: 'Zugang zur Blizzard-API eingetragen', hint: 'Damit kommen stündlich alle Angebote, ganz ohne Scan im Spiel. Die Anleitung steht unter Einstellungen.', go: 'settings', label: 'Einstellungen' },
    { key: 'house', done: !!(props.data.api && props.data.api.selected), title: 'Auktionshaus gewählt', hint: 'Wähle unter Datenlage das Haus, auf dem du spielst.', go: on ? 'sources' : null, label: 'Datenlage' },
    { key: 'data', done: (props.data.markets || []).some((m) => m.lastScan), title: 'Erste Daten da', hint: 'Das kommt von selbst über die Blizzard-API oder mit einem Komplettscan und „An Manager“ im Spiel.', go: null },
  ];
});
const openSteps = computed(() => steps.value.filter((s) => !s.done).length);
const show = computed(() => !props.settings.checklistHidden && steps.value.length > 0 && openSteps.value > 0);
</script>

<template>
  <section class="list" v-if="show" aria-label="Einrichtung">
    <div class="head">
      <h2>Einrichtung</h2>
      <span class="small muted">noch {{ openSteps }} von {{ steps.length }}</span>
      <button class="link small hide" @click="emit('save', { checklistHidden: true })">Ausblenden</button>
    </div>
    <ul>
      <li v-for="s in steps" :key="s.key" :class="{ done: s.done }">
        <span class="mark" aria-hidden="true">{{ s.done ? '✓' : '' }}</span>
        <div>
          <span>{{ s.title }}<span class="sr">{{ s.done ? ' (erledigt)' : ' (offen)' }}</span></span>
          <p class="small muted" v-if="!s.done">{{ s.hint }}</p>
        </div>
        <button class="small" v-if="!s.done && s.go" @click="emit('go', s.go)">{{ s.label }}</button>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.list { display: grid; gap: 10px; padding: 14px 16px; margin-bottom: 26px; max-width: 1180px; background: var(--panel); border: 1px solid var(--accent); border-radius: var(--radius-m); }
.head { display: flex; align-items: baseline; gap: 12px; }
.hide { margin-left: auto; }
ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
li { display: grid; grid-template-columns: 20px minmax(0, 1fr) auto; gap: 10px; align-items: start; }
li.done > div { color: var(--muted); }
.mark { width: 18px; height: 18px; border: 1px solid var(--line); border-radius: 50%; font-size: 12px; line-height: 16px; text-align: center; color: var(--accent); margin-top: 2px; }
li.done .mark { border-color: var(--accent); }
.sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
