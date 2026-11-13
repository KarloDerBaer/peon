<script setup>
// Betrag eingeben wie im Spiel (ab 0.34.0): drei Felder Gold, Silber, Kupfer mit Muenzen in den Farben des Spiels.
// value = Kupfer oder null (leer). placeholder = Kupfer, der grau in den Feldern steht, solange nichts eingetragen ist
// (etwa der Wert der Liste). Meldet change(Kupfer oder null), sobald ein Feld verlassen wurde und sich etwas geaendert hat.
import { ref, watch, computed } from 'vue';
import { coins } from '../util.js';

const props = defineProps({ value: Number, placeholder: Number, label: String, title: String });
const emit = defineEmits(['change']);

const parts = (c) => { const x = coins(c); return x ? { g: x.g ? String(x.g) : '', s: x.g || x.s ? String(x.s) : '', c: String(x.c) } : { g: '', s: '', c: '' }; };
const f = ref(parts(props.value));
watch(() => props.value, (v) => { f.value = parts(v); });
const ph = computed(() => (props.placeholder != null ? parts(props.placeholder) : { g: '', s: '', c: '' }));

const digits = (t) => String(t).replace(/[^0-9]/g, '');
function total() {
  const g = digits(f.value.g), s = digits(f.value.s), c = digits(f.value.c);
  if (g === '' && s === '' && c === '') return null;
  const v = Number(g || 0) * 10000 + Number(s || 0) * 100 + Number(c || 0);
  return v > 0 ? v : null;
}
function done() {
  const v = total();
  if (v !== (props.value ?? null)) emit('change', v);
  else f.value = parts(props.value);   // nur aufraeumen, etwa 120 Silber -> 1g 20s
}
function onKey(e) { if (e.key === 'Enter') e.target.blur(); }
</script>

<template>
  <span class="money" :title="title" role="group" :aria-label="label">
    <label><input v-model="f.g" class="g" inputmode="numeric" :placeholder="ph.g" :aria-label="`${label || 'Betrag'}: Gold`" @change="done" @keydown="onKey" /><i class="coin gold" aria-hidden="true"></i></label>
    <label><input v-model="f.s" class="s" inputmode="numeric" maxlength="2" :placeholder="ph.s" :aria-label="`${label || 'Betrag'}: Silber`" @change="done" @keydown="onKey" /><i class="coin silver" aria-hidden="true"></i></label>
    <label><input v-model="f.c" class="c" inputmode="numeric" maxlength="2" :placeholder="ph.c" :aria-label="`${label || 'Betrag'}: Kupfer`" @change="done" @keydown="onKey" /><i class="coin copper" aria-hidden="true"></i></label>
  </span>
</template>

<style scoped>
.money { display: inline-flex; gap: 4px; align-items: center; white-space: nowrap; }
.money label { display: inline-flex; align-items: center; gap: 2px; }
.money input { text-align: right; padding-left: 4px !important; padding-right: 4px !important; }
.money input.g { width: 5ch !important; }
.money input.s, .money input.c { width: 3.4ch !important; }
.money input::placeholder { color: var(--faint); }
/* Muenzen wie im Spiel: runde Scheibe in Gold, Silber, Kupfer mit Glanz */
.coin { display: inline-block; width: 11px; height: 11px; border-radius: 50%; flex: none; box-shadow: inset 0 -1px 0 rgba(0, 0, 0, 0.35), 0 0 0 1px rgba(0, 0, 0, 0.25); }
.gold { background: radial-gradient(circle at 35% 30%, #fff3b0 0 18%, var(--gold) 45%, #8a6408 100%); }
.silver { background: radial-gradient(circle at 35% 30%, #ffffff 0 18%, var(--silver) 45%, #6d757d 100%); }
.copper { background: radial-gradient(circle at 35% 30%, #ffd0a0 0 18%, var(--copper) 45%, #6e3c12 100%); }
</style>
