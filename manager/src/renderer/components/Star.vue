<script setup>
// Stern fuer die Beobachtung (bis 0.23 Favoriten): nur Rahmen = nicht beobachtet, ausgefuellt = beobachtet
import { computed } from 'vue';
import { favorites, toggleFavorite } from '../store.js';

const props = defineProps({ itemKey: String, size: { type: Number, default: 18 } });
const on = computed(() => favorites.value.has(props.itemKey));
</script>

<template>
  <button class="star" :class="{ on }" type="button" :aria-pressed="on" :aria-label="on ? 'Nicht mehr beobachten' : 'Beobachten'" :title="on ? 'Nicht mehr beobachten' : 'Beobachten'" @click.stop="toggleFavorite(itemKey)" @keydown.enter.stop>
    <svg :width="size" :height="size" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 2.8l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.6l-5.9 3.2 1.2-6.5L2.5 9.7l6.6-.9z" :fill="on ? 'currentColor' : 'none'" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" />
    </svg>
  </button>
</template>

<style scoped>
.star { display: inline-flex; padding: 2px; background: none; border: none; color: var(--faint); line-height: 0; flex: none; }
.star:hover { color: var(--gold); }
.star.on { color: var(--gold); }
</style>
