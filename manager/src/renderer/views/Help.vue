<!-- Hilfe (ab 0.48.0): Inhalt aus docs/Hilfe.md im Repo, je Addon ein Abschnitt, mit Suche und Sprungleiste -->
<script setup>
import { ref, computed } from 'vue';
import md from '../../../../docs/Hilfe.md?raw';
import { sections, plain } from '../markdown.js';

const all = sections(md);
const head = all[0];
const parts = all.slice(1);
const query = ref('');
const shown = computed(() => {
  const q = query.value.trim().toLowerCase();
  return q ? parts.filter((s) => plain(s).includes(q)) : parts;
});
function jump(id) {
  const el = document.getElementById(`hilfe-${id}`);
  if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); el.focus({ preventScroll: true }); }
}
</script>

<template>
  <section class="help">
    <template v-for="(b, i) in head.blocks" :key="'k' + i">
      <h1 v-if="b.t === 'h1'"><template v-for="(p, j) in b.parts" :key="j"><strong v-if="p.t === 'b'">{{ p.v }}</strong><code v-else-if="p.t === 'code'">{{ p.v }}</code><template v-else>{{ p.v }}</template></template></h1>
      <p v-else-if="b.t === 'p'" class="muted"><template v-for="(p, j) in b.parts" :key="j"><strong v-if="p.t === 'b'">{{ p.v }}</strong><code v-else-if="p.t === 'code'">{{ p.v }}</code><template v-else>{{ p.v }}</template></template></p>
    </template>

    <div class="bar">
      <input v-model="query" type="search" placeholder="Hilfe durchsuchen, z. B. Taste, Profil, Sicherung" aria-label="Hilfe durchsuchen" />
      <nav class="jump" aria-label="Addons">
        <button v-for="s in parts" :key="s.id" class="chip" @click="jump(s.id)">{{ s.title.replace(/^Peon_/, '') }}</button>
      </nav>
    </div>

    <p class="muted" v-if="!shown.length" role="status">Nichts gefunden.</p>
    <article v-for="s in shown" :id="'hilfe-' + s.id" :key="s.id" class="card" tabindex="-1">
      <h2>{{ s.title }}</h2>
      <template v-for="(b, i) in s.blocks" :key="i">
        <h3 v-if="b.t === 'h3'">{{ b.text }}</h3>
        <p v-else-if="b.t === 'p'"><template v-for="(p, j) in b.parts" :key="j"><strong v-if="p.t === 'b'">{{ p.v }}</strong><code v-else-if="p.t === 'code'">{{ p.v }}</code><template v-else>{{ p.v }}</template></template></p>
        <ul v-else-if="b.t === 'ul'">
          <li v-for="(item, k) in b.items" :key="k"><template v-for="(p, j) in item" :key="j"><strong v-if="p.t === 'b'">{{ p.v }}</strong><code v-else-if="p.t === 'code'">{{ p.v }}</code><template v-else>{{ p.v }}</template></template></li>
        </ul>
      </template>
    </article>
  </section>
</template>

<style scoped>
.help { display: grid; gap: 16px; max-width: 820px; }
.bar { display: grid; gap: 10px; position: sticky; top: 0; z-index: 1; padding: 8px 0; background: var(--ground); }
.bar input { max-width: 420px; }
.jump { display: flex; flex-wrap: wrap; gap: 6px; }
.card { scroll-margin-top: 110px; border: 1px solid var(--line); border-radius: var(--radius-m); padding: 14px 18px; background: var(--panel); }
.chip { padding: 4px 10px; font-size: 13px; }
.card h2 { margin-bottom: 6px; }
.card ul { margin: 6px 0 0; padding-left: 20px; display: grid; gap: 4px; }
code { font-family: Consolas, monospace; font-size: 0.92em; padding: 0 3px; border-radius: 3px; background: var(--line-soft); }
</style>
