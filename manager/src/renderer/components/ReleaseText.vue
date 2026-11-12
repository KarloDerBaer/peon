<script setup>
// Was ist neu (ab 0.27.0): Anmerkung und Punkte Neu, Geändert, Behoben, Entfernt aus dem Release.
// Ohne diese Angabe (älteres Release) die kurzen Texte je Version wie bisher.
// Wer vor dem letzten Release stehen geblieben ist, sieht darunter die kurzen Texte der Versionen davor.
defineProps({ release: Object, news: Array });
</script>

<template>
  <div class="rt small">
    <template v-if="release">
      <p class="note" v-if="release.note">{{ release.note }}</p>
      <ul v-if="release.items.length">
        <li v-for="(it, i) in release.items" :key="i"><b :class="'k k-' + it.kind">{{ it.kind }}:</b> {{ it.text }}</li>
      </ul>
      <template v-if="release.older.length">
        <p class="muted">Davor:</p>
        <ul v-for="n in release.older" :key="n.version"><li v-for="s in n.short" :key="s">{{ s }}</li></ul>
      </template>
    </template>
    <template v-else>
      <ul v-for="n in news || []" :key="n.version"><li v-for="s in n.short" :key="s">{{ s }}</li></ul>
    </template>
  </div>
</template>

<style scoped>
.rt { display: grid; gap: 4px; }
.rt p { margin: 0; }
.rt ul { margin: 2px 0 0; padding-left: 18px; }
.note { font-weight: 500; }
.k { font-weight: 600; }
.k-Neu { color: var(--accent); }
.k-Behoben { color: var(--up); }
.k-Entfernt { color: var(--muted); }
</style>
