<script setup>
// Schnellsuche (Strg+K): springt von überall zu einem Gegenstand oder einer Seite. Pfeile und Eingabe, Esc schließt.
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';
import Gold from './Gold.vue';
import { fold, itemName, qualityColor } from '../util.js';

const props = defineProps({ market: Object, pages: Array });
const emit = defineEmits(['close', 'open', 'go']);
const api = window.peon;

const q = ref('');
const items = ref([]);
const active = ref(0);
const input = ref(null);
const listEl = ref(null);

onMounted(async () => {
  await nextTick();
  if (input.value) input.value.focus();
  if (props.market) {
    const r = await api.items(props.market.key);
    items.value = r ? r.items : [];
  }
});

const MAX = 10;
const results = computed(() => {
  const s = fold(q.value.trim());
  const pages = props.pages.filter((p) => !s || fold(p.label).includes(s)).map((p) => ({ type: 'page', key: p.key, label: p.label }));
  if (!s) return pages;
  // Vorn beginnende Treffer zuerst, dann was gerade im Auktionshaus steht, dann die meisten Angebote
  const hits = [];
  for (const x of items.value) {
    const name = fold(itemName(x));
    const at = String(x.item) === s ? 0 : name.indexOf(s);
    if (at < 0) continue;
    hits.push({ x, rank: (at === 0 ? 0 : 2) + (x.inLast ? 0 : 1) });
  }
  hits.sort((a, b) => a.rank - b.rank || (b.x.auctions || 0) - (a.x.auctions || 0));
  return [...hits.slice(0, MAX).map((h) => ({ type: 'item', key: h.x.key, it: h.x })), ...pages];
});
watch(results, () => { active.value = 0; });

function pick(r) {
  if (!r) return;
  if (r.type === 'item') emit('open', r.key);
  else emit('go', r.key);
  emit('close');
}
function onKey(e) {
  if (e.key === 'Escape') { e.preventDefault(); emit('close'); }
  else if (e.key === 'Enter') { e.preventDefault(); pick(results.value[active.value]); }
  else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault();
    const n = results.value.length;
    if (n) active.value = (active.value + (e.key === 'ArrowDown' ? 1 : n - 1)) % n;
    nextTick(() => { const el = listEl.value && listEl.value.querySelector('.on'); if (el) el.scrollIntoView({ block: 'nearest' }); });
  }
}
onBeforeUnmount(() => {});
</script>

<template>
  <div class="veil" @click.self="emit('close')">
    <div class="box" role="dialog" aria-modal="true" aria-label="Schnellsuche">
      <input ref="input" type="text" v-model="q" placeholder="Gegenstand oder Seite suchen" aria-label="Suchen" spellcheck="false" @keydown="onKey" />
      <ul ref="listEl" role="listbox">
        <li v-for="(r, k) in results" :key="r.type + r.key" role="option" :aria-selected="k === active" :class="{ on: k === active }" @mouseenter="active = k" @click="pick(r)">
          <template v-if="r.type === 'item'">
            <span class="name" :style="{ color: qualityColor(r.it.quality) }">{{ itemName(r.it) }}</span>
            <span class="small muted"><Gold v-if="r.it.inLast" :copper="r.it.min" compact /><template v-else>nicht im letzten Stand</template></span>
          </template>
          <template v-else>
            <span class="name">{{ r.label }}</span><span class="small muted">Seite</span>
          </template>
        </li>
        <li v-if="!results.length" class="none small muted">Nichts gefunden.</li>
      </ul>
      <p class="small faint">Pfeile wählen, Eingabe öffnet, Esc schließt</p>
    </div>
  </div>
</template>

<style scoped>
.veil { position: fixed; inset: 0; z-index: 60; display: flex; justify-content: center; align-items: flex-start; padding: 12vh 24px 24px; background: rgba(0, 0, 0, 0.5); }
.box { width: 100%; max-width: 560px; max-height: 100%; display: flex; flex-direction: column; gap: 10px; padding: 14px; background: var(--panel); border: 1px solid var(--line); border-radius: var(--radius-m); }
ul { list-style: none; margin: 0; padding: 0; overflow: auto; min-height: 0; max-height: 50vh; }
li { display: flex; justify-content: space-between; gap: 16px; padding: 7px 10px; border-radius: var(--radius-s); cursor: pointer; }
li.on { background: var(--accent-soft); }
li.none { cursor: default; }
.name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
li > .small { flex: none; }
</style>
