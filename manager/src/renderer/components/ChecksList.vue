<!-- Pruefliste einer Chance (Peon_Manager_Chancen.md 6.1 Stufe 2): jede Bedingung mit Haken oder Kreuz, Wert und Grenze.
     Knappe Werte (innerhalb 10 % der Grenze) gelb, von dir geaenderte mit Hinweis und Knopf zum Zuruecknehmen -->
<script setup>
const props = defineProps({ checks: Array, signals: Array });
const emit = defineEmits(['undo']);
</script>

<template>
  <ul class="checks">
    <li v-for="c in props.checks" :key="c.id" :class="{ bad: !c.ok, near: c.ok && c.near }">
      <span class="mark" :aria-label="c.ok ? 'erfüllt' : 'nicht erfüllt'">{{ c.ok ? '✓' : '✗' }}</span>
      <span class="lab">{{ c.label }}<template v-if="c.fixed"> <span class="faint small">(fest)</span></template></span>
      <span class="txt">{{ c.text }}<template v-if="c.user"> · <span class="user">von dir geändert</span> <button class="link small" @click="emit('undo', c.id)">zurücknehmen</button></template></span>
    </li>
    <li v-for="s in props.signals || []" :key="'sig' + s.id" class="sig">
      <span class="mark">{{ s.dir > 0 ? '▲' : '▼' }}</span>
      <span class="lab">Signal {{ s.label }}</span>
      <span class="txt">{{ s.text }} · <template v-if="s.isNew">neu, noch {{ 20 - s.n }} Nachprüfungen bis zur Trefferquote</template><template v-else>Trefferquote {{ Math.round(s.rate * 100) }} % aus {{ s.n }}</template></span>
    </li>
  </ul>
</template>

<style scoped>
.checks { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; }
.checks li { display: grid; grid-template-columns: 20px minmax(180px, 260px) 1fr; gap: 8px; align-items: baseline; }
.mark { font-weight: 700; color: var(--up); text-align: center; }
.bad .mark { color: var(--bad); }
.near .mark, .near .txt { color: var(--warn); }
.sig .mark { color: var(--accent); }
.lab { color: var(--muted); }
.user { color: var(--accent); }
</style>
