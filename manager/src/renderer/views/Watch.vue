<script setup>
// Merkliste: gemerkte Gegenstände mit aktuellem Preis und Preisalarm
import { ref, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import { num, qualityColor, itemName } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, settings: Object });
const emit = defineEmits(['open', 'save', 'go']);
const api = window.peon;

const list = ref(null);
async function load() { list.value = props.market ? await api.watchList(props.market.key) : []; }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

const inGold = (below) => (below == null ? '' : below / 10000);
async function setLimit(r, value) {
  const gold = parseFloat(String(value).replace(',', '.'));
  await api.watchSet(props.market.key, r.key, gold > 0 ? gold * 10000 : null);
  load();
}
async function remove(r) { await api.watchRemove(props.market.key, r.key); load(); }
</script>

<template>
  <div class="watch" v-if="list">
    <div class="head">
      <h1>Merkliste</h1>
      <label class="check small"><input type="checkbox" :checked="settings.watchNotify" @change="emit('save', { watchNotify: $event.target.checked })" /> Bei Preisalarm eine Meldung von Windows zeigen</label>
    </div>
    <p class="muted" v-if="!list.length">Noch nichts gemerkt. Öffne unter <button class="link" @click="emit('go', 'items')">Gegenstände</button> einen Gegenstand und klicke auf „Merken“.</p>
    <template v-else>
      <p class="small muted">Trägst du eine Grenze ein, meldet sich der Manager einmal, sobald das günstigste Angebot sie erreicht, und wieder, nachdem der Preis darüber lag.</p>
      <table class="tbl">
        <thead><tr><th>Gegenstand</th><th class="num">Min jetzt</th><th class="num">Median</th><th class="num">Üblich</th><th class="num">Menge</th><th class="num">Alarm unter (Gold)</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in list" :key="r.key" :class="{ hit: r.hit }">
            <td class="name click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ itemName(r) }}<span class="small badge" v-if="r.hit">unter der Grenze</span></td>
            <td class="num"><Gold :copper="r.min" compact /></td>
            <td class="num muted"><Gold :copper="r.median" compact /></td>
            <td class="num muted"><Gold :copper="r.lang" compact /></td>
            <td class="num">{{ r.qty ? num(r.qty) : 'keine' }}</td>
            <td class="num"><input class="limit" type="text" inputmode="decimal" :value="inGold(r.below)" :aria-label="`Grenze für ${itemName(r)} in Gold`" placeholder="kein Alarm" spellcheck="false" @change="setLimit(r, $event.target.value)" /></td>
            <td class="num"><button class="small" @click="remove(r)">Entfernen</button></td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>

<style scoped>
.watch { display: grid; gap: 14px; max-width: 1180px; }
.head { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.check { display: flex; gap: 8px; align-items: center; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 10px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 7px 10px; border-bottom: 1px solid var(--line-soft); }
.tbl th.num, .num { text-align: right; white-space: nowrap; }
.click { cursor: pointer; }
.click:hover, .click:focus-visible { background: var(--raised); }
.limit { width: 110px; text-align: right; }
.hit td { background: var(--accent-soft); }
.badge { margin-left: 10px; color: var(--accent); }
</style>
