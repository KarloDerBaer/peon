<script setup>
// Ansicht "Module" (Peon_GitHub_Design.md 5.3). Bis jetzt die Gruppe Manager-Module, die Addons folgen mit Schritt H.
import { ref } from 'vue';
import { bytes } from '../util.js';

const props = defineProps({ data: Object });
const emit = defineEmits(['changed']);
const api = window.peon;
const busy = ref('');
const confirmDelete = ref('');
const error = ref('');

async function toggle(m) {
  busy.value = m.key; error.value = '';
  try { await api.setModule(m.key, !m.enabled); emit('changed'); } catch (e) { error.value = String(e.message || e); } finally { busy.value = ''; }
}

async function clearData(m) {
  if (confirmDelete.value !== m.key) { confirmDelete.value = m.key; return; }
  busy.value = m.key; error.value = '';
  try { await api.clearModuleData(m.key); confirmDelete.value = ''; emit('changed'); } catch (e) { error.value = String(e.message || e); } finally { busy.value = ''; }
}
</script>

<template>
  <div class="mods">
    <h1>Module</h1>

    <section class="group">
      <h2>Manager-Module</h2>
      <p class="small muted">Zusätze für den Peon Manager. Sie stecken schon im Programm und werden mit „Installieren“ eingeschaltet.</p>
      <p class="small warn" v-if="error" role="alert">{{ error }}</p>

      <article v-for="m in data.modules" :key="m.key" class="card" :class="{ on: m.enabled }">
        <div class="head">
          <div>
            <h3>{{ m.title }}</h3>
            <span class="state small" :class="m.enabled ? 'ok' : 'muted'">{{ m.enabled ? 'Installiert' : 'Nicht installiert' }}</span>
          </div>
          <button :class="{ primary: !m.enabled }" :disabled="busy === m.key" @click="toggle(m)">
            {{ busy === m.key ? 'Moment' : m.enabled ? 'Entfernen' : 'Installieren' }}
          </button>
        </div>
        <p>{{ m.desc }}</p>
        <p class="small muted">
          Braucht die Addons
          <span v-for="(a, i) in m.addons" :key="a.name"><span :class="a.present ? '' : 'warn'">{{ a.name }}{{ a.present ? '' : ' (fehlt)' }}</span>{{ i < m.addons.length - 1 ? ', ' : '' }}</span>.
          <template v-if="m.addons.some((a) => !a.present)"> Fehlende Addons installiert der Manager mit einer späteren Version, bis dahin von Hand in den AddOns-Ordner legen.</template>
        </p>
        <div class="data small" v-if="!m.enabled && m.hasData">
          <span class="muted">Die Daten des Moduls bleiben erhalten ({{ bytes(m.dataBytes) }}). Beim nächsten Installieren sind sie wieder da.</span>
          <button class="danger" :disabled="busy === m.key" @click="clearData(m)">{{ confirmDelete === m.key ? 'Wirklich löschen?' : 'Daten löschen' }}</button>
          <button v-if="confirmDelete === m.key" @click="confirmDelete = ''">Abbrechen</button>
        </div>
      </article>
    </section>

    <section class="group">
      <h2>Addons</h2>
      <p class="small muted">Installieren und Aktualisieren der Peon-Addons folgt mit der nächsten Version des Managers.</p>
    </section>
  </div>
</template>

<style scoped>
.mods { display: grid; gap: 30px; max-width: 760px; }
.group { display: grid; gap: 12px; padding-bottom: 24px; border-bottom: 1px solid var(--line-soft); }
.card { border: 1px solid var(--line); border-radius: var(--radius-m); padding: 16px 18px; display: grid; gap: 8px; background: var(--panel); }
.card.on { border-color: var(--accent); }
.head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; }
.head h3 { margin: 0 0 2px; }
.ok { color: var(--accent); }
.warn { color: var(--warn); }
.data { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; padding-top: 6px; border-top: 1px solid var(--line-soft); }
.data .muted { flex: 1; min-width: 240px; }
button.danger { color: var(--bad); border-color: var(--bad); }
</style>
