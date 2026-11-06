<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { ago } from '../util.js';

const props = defineProps({ now: Number, stamp: Number });
const api = window.peon;

const DISCORD_LIMIT = 2000;
const state = ref(null);
const busy = ref('');
const error = ref('');
const note = ref('');
const step = ref('');   // '' | 'senden' (Vorschau) | 'kopiert' (leeren?) | 'leeren' (Rueckfrage)

async function load() { state.value = await api.errors(); }
onMounted(load);
watch(() => props.stamp, load);

const rows = computed(() => (state.value ? state.value.errors : []));
const tooLong = computed(() => !!state.value && state.value.text.length > DISCORD_LIMIT);

const message = (e) => String(e && e.message || e).replace(/^Error invoking remote method '[^']+': (Error: )?/, '');
async function run(what, fn) {
  busy.value = what;
  error.value = '';
  note.value = '';
  try { await fn(); } catch (e) { error.value = message(e); } finally { busy.value = ''; }
}

const copy = () => run('copy', async () => {
  await api.errorsCopy();
  note.value = 'Der Text ist in der Zwischenablage.';
  step.value = 'kopiert';
});
const clear = () => run('clear', async () => {
  await api.errorsClear();
  step.value = '';
  note.value = 'Der Fehlerspeicher ist geleert. Im Spiel wird er beim nächsten /reload oder Einloggen geleert.';
  await load();
});
const send = () => run('send', async () => {
  const r = await api.errorsSend();
  step.value = '';
  note.value = `Bericht gesendet, danke! Der Fehlerspeicher ist geleert.${r.omitted ? ` ${r.omitted} ältere Fehler passten nicht mehr in den Bericht.` : ''}`;
  await load();
});
</script>

<template>
  <div class="debug" v-if="state">
    <section class="block">
      <h1>Debug</h1>
      <p class="muted lead">Fehler der Peon-Addons, gesammelt aus dem Spiel. Neue Fehler erscheinen hier nach einem /reload, Ausloggen oder Beenden.</p>

      <p v-if="!rows.length" class="muted">Keine gespeicherten Fehler.</p>
      <table v-else class="tbl">
        <thead><tr><th>Addon</th><th>Bereich</th><th>Fehler</th><th class="r">Anzahl</th><th>Zuletzt</th></tr></thead>
        <tbody>
          <tr v-for="r in rows" :key="r.key">
            <td class="nowrap">{{ r.addon }}<span v-if="r.version" class="muted"> {{ r.version }}</span></td>
            <td class="muted">{{ r.place }}</td>
            <td>
              <div class="msg">{{ r.msg }}</div>
              <details v-if="r.stack"><summary class="small muted">Aufrufkette</summary><pre class="stack">{{ r.stack }}</pre></details>
            </td>
            <td class="r">{{ r.n }}</td>
            <td class="muted nowrap">{{ ago(r.last, now) }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="block" v-if="rows.length">
      <h2>Weitergeben</h2>
      <div class="actions" v-if="step === ''">
        <button class="primary" :disabled="!!busy || !state.canSend" @click="step = 'senden'">An KarloDerBaer senden</button>
        <button :disabled="!!busy" @click="copy">Als Text kopieren</button>
        <button class="danger" :disabled="!!busy" @click="step = 'leeren'">Fehlerspeicher leeren</button>
      </div>
      <p v-if="step === '' && !state.canSend" class="small muted">Das direkte Senden ist noch nicht eingerichtet. Kopiere den Text und schicke ihn per Nachricht oder über Discord.</p>
      <p v-if="step === '' && tooLong" class="small muted">Der Text ist länger als eine Discord-Nachricht ({{ DISCORD_LIMIT }} Zeichen). Füge ihn dort als Textdatei an.</p>

      <div v-if="step === 'kopiert'" class="ask">
        <span>Soll der Fehlerspeicher jetzt geleert werden?</span>
        <button class="danger" :disabled="!!busy" @click="clear">Leeren</button>
        <button :disabled="!!busy" @click="step = ''">Behalten</button>
      </div>

      <div v-if="step === 'leeren'" class="ask">
        <span>Alle gespeicherten Fehler wirklich löschen?</span>
        <button class="danger" :disabled="!!busy" @click="clear">Wirklich leeren</button>
        <button :disabled="!!busy" @click="step = ''">Abbrechen</button>
      </div>

      <div v-if="step === 'senden'" class="preview">
        <p class="small muted">Das wird gesendet: Addon, Version, Fehlertext und Aufrufkette. Konto- und Charakternamen sowie Pfade sind bereits ersetzt. Der Bericht läuft über einen Cloudflare-Dienst, der deine IP-Adresse technisch sieht, aber nicht speichert, und landet in einem nicht öffentlichen GitHub-Repo von KarloDerBaer. Ein Konto brauchst du nicht. Nach dem Senden wird der Fehlerspeicher geleert.</p>
        <pre class="stack">{{ state.text }}</pre>
        <div class="actions">
          <button class="primary" :disabled="!!busy" @click="send">{{ busy === 'send' ? 'Sendet' : 'Jetzt senden' }}</button>
          <button :disabled="!!busy" @click="step = ''">Abbrechen</button>
        </div>
      </div>

      <p v-if="error" class="err" role="alert">{{ error }}</p>
      <p v-if="note" class="ok" role="status">{{ note }}</p>
    </section>
    <p v-else-if="note" class="ok" role="status">{{ note }}</p>
  </div>
  <div class="muted" v-else>Lade Daten</div>
</template>

<style scoped>
.debug { display: flex; flex-direction: column; gap: 24px; }
.lead { margin-bottom: 14px; }
.actions, .ask { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.tbl th { text-align: left; }
.tbl th.r, .r { text-align: right; }
.tbl th, .tbl td { padding-right: 16px; vertical-align: top; }
.nowrap { white-space: nowrap; }
.msg { overflow-wrap: anywhere; }
.stack { margin: 8px 0; padding: 10px; max-height: 260px; overflow: auto; background: var(--raised); border-radius: var(--radius-s); font-size: 12px; white-space: pre-wrap; overflow-wrap: anywhere; }
.preview { display: flex; flex-direction: column; gap: 8px; }
.err { color: var(--danger, #e5484d); margin-top: 10px; }
.ok { color: var(--accent); margin-top: 10px; }
</style>
