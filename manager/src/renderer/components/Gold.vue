<!-- Geldbetrag wie im Spiel: 12g 34s 56c, Münzbuchstaben in Münzfarbe, führende Nullen weg -->
<script setup>
import { computed } from 'vue';
import { coins } from '../util.js';
// compact: ab 100 Gold nur Gold, ab 1 Gold ohne Kupfer (fuer Listen)
const props = defineProps({ copper: Number, compact: Boolean });
const c = computed(() => {
  const v = coins(props.copper);
  if (!v || !props.compact) return v;
  if (v.g >= 100) return { ...v, s: null, c: null };
  if (v.g >= 1) return { ...v, c: null };
  return v;
});
</script>

<template>
  <span class="gold" v-if="c">
    <template v-if="c.g"><span>{{ c.g.toLocaleString('de-DE') }}</span><i class="g">g</i></template>
    <template v-if="(c.g || c.s) && c.s != null"><span>{{ c.s }}</span><i class="s">s</i></template>
    <template v-if="c.c != null"><span>{{ c.c }}</span><i class="c">c</i></template>
  </span>
  <span v-else class="faint">–</span>
</template>

<style scoped>
.gold { white-space: nowrap; }
.gold span + i { margin-right: 0.35em; }
.gold i:last-child { margin-right: 0; }
i { font-style: normal; font-weight: 600; font-size: 0.85em; margin-left: 1px; }
.g { color: var(--gold); }
.s { color: var(--silver); }
.c { color: var(--copper); }
</style>
