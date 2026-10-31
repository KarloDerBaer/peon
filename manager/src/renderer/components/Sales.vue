<!-- Absatz je Tag mit Zeichen für die Sicherheit (wie Broker: ≈ rot, gelb, grün) -->
<script setup>
import { perDay, levelTitle } from '../util.js';
defineProps({ s: Object, unit: { type: String, default: '' } });
</script>

<template>
  <span v-if="s && s.perDay != null" class="sales" :title="levelTitle(s.level)"><i :class="'l' + s.level">≈</i>{{ perDay(s.perDay) }}{{ unit }}</span>
  <span v-else class="faint">–</span>
</template>

<style scoped>
.sales { white-space: nowrap; }
i { font-style: normal; font-weight: 700; margin-right: 4px; }
.l1 { color: var(--bad); }
.l2 { color: var(--warn); }
.l3 { color: var(--accent); }
</style>
