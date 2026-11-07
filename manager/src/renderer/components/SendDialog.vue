<script setup>
// Dialog vor dem Senden der Rueckmeldungen: zeigt genau den Text, der an KarloDerBaer geht (Reports.vue)
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { pl } from '../util.js';

const props = defineProps({ preview: Object, busy: Boolean, error: String });
const emit = defineEmits(['send', 'close']);
const root = ref(null);

function close() { if (!props.busy) emit('close'); }
function onKey(e) { if (e.key === 'Escape') close(); }
onMounted(() => {
  window.addEventListener('keydown', onKey);
  if (root.value) root.value.focus();
});
onBeforeUnmount(() => window.removeEventListener('keydown', onKey));
</script>

<template>
  <div class="veil" @click.self="close">
    <div class="box" ref="root" tabindex="-1" role="dialog" aria-modal="true" aria-labelledby="send-title">
      <header>
        <h2 id="send-title">Rückmeldungen senden</h2>
        <button class="x" aria-label="Schließen" :disabled="busy" @click="close">×</button>
      </header>
      <p class="small muted">Das geht an KarloDerBaer: genau der Text unten, je Eintrag ein Bericht in einem nicht öffentlichen GitHub-Repo. Deine Konto- und Charakternamen sowie Pfade sind ersetzt, Namen anderer Spieler in deinem Text aber nicht. Der Bericht läuft über einen Cloudflare-Dienst, der deine IP-Adresse technisch sieht, aber nicht speichert. Ein Konto brauchst du nicht. Gesendete Einträge verschwinden danach aus der Liste.</p>
      <pre class="stack">{{ preview.text }}</pre>
      <p v-if="preview.left" class="small muted">{{ pl(preview.left, 'weiterer Eintrag', 'weitere Einträge') }} beim nächsten Senden.</p>
      <p v-if="error" class="small err" role="alert">{{ error }}</p>
      <footer>
        <button :disabled="busy" @click="close">Abbrechen</button>
        <button class="primary" :disabled="busy" @click="emit('send')">{{ busy ? 'Sendet' : `${pl(preview.count, 'Eintrag', 'Einträge')} senden` }}</button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.veil { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; padding: 24px; background: rgba(0, 0, 0, 0.5); }
.box { width: 100%; max-width: 680px; max-height: 100%; display: flex; flex-direction: column; gap: 12px; padding: 18px 20px; background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius-m); outline: none; }
header { display: flex; justify-content: space-between; align-items: center; }
header h2 { margin: 0; }
.x { background: none; border: none; font-size: 20px; line-height: 1; padding: 2px 6px; color: var(--muted); }
p { margin: 0; }
.stack { margin: 0; padding: 10px; min-height: 0; flex: 1 1 auto; overflow: auto; background: var(--raised); border-radius: var(--radius-s); font-size: 12px; white-space: pre-wrap; overflow-wrap: anywhere; }
.err { color: var(--danger, #e5484d); }
footer { display: flex; justify-content: flex-end; gap: 10px; padding-top: 4px; }
</style>
