<script setup>
// Einkaufsliste: dieselben Listen wie im Broker. Eingaben gehen ueber Data.lua ins Spiel, Aenderungen im Spiel kommen von selbst zurueck.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Star from '../components/Star.vue';
import { num, fold, qualityColor, itemName } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, settings: Object });
const emit = defineEmits(['open', 'save', 'go']);
const api = window.peon;

const view = ref(null);
const selected = ref(null);
const confirmDelete = ref(false);
const addText = ref('');
const catalog = ref([]);

async function load() {
  view.value = await api.shopView(props.market ? props.market.key : '');
  if (!view.value.lists.some((l) => l.id === selected.value)) selected.value = view.value.lists.length ? view.value.lists[0].id : null;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

const list = computed(() => (view.value ? view.value.lists.find((l) => l.id === selected.value) || null : null));
watch(selected, () => { confirmDelete.value = false; });

async function addList() {
  selected.value = await api.shopNewList('');
  await load();
}
async function removeList() {
  if (!confirmDelete.value) { confirmDelete.value = true; return; }
  await api.shopDeleteList(selected.value);
  confirmDelete.value = false;
  await load();
}
async function setName(v) { if (v.trim()) { await api.shopUpdateList(selected.value, { name: v }); await load(); } }
async function setPct(v) { await api.shopUpdateList(selected.value, { pct: parseFloat(String(v).replace(',', '.')) || 0 }); await load(); }
async function setWish(r, v) { await api.shopSet(selected.value, r.key, { wish: parseInt(v, 10) || 0 }); await load(); }
async function setMax(r, v) {
  const gold = parseFloat(String(v).replace(',', '.'));
  await api.shopSet(selected.value, r.key, { max: gold > 0 ? gold * 10000 : 0 });
  await load();
}
async function remove(r) { await api.shopRemove(selected.value, r.key); await load(); }

// Hinzufuegen ueber den Namen: Vorschlaege aus der Gegenstandsliste des Markts
async function loadCatalog() {
  if (catalog.value.length || !props.market) return;
  const r = await api.items(props.market.key);
  catalog.value = r.items.map((x) => ({ key: x.key, name: itemName(x), quality: x.quality, folded: fold(itemName(x)) }));
}
watch(() => props.market && props.market.key, () => { catalog.value = []; });
const suggestions = computed(() => {
  const q = fold(addText.value.trim());
  if (q.length < 2 || !list.value) return [];
  return catalog.value.filter((x) => x.folded.includes(q) && !list.value.items.some((r) => r.key === x.key)).slice(0, 8);
});
async function add(s) {
  await api.shopAdd(selected.value, s.key);
  addText.value = '';
  await load();
}
const inGold = (c) => (c == null ? '' : c / 10000);
</script>

<template>
  <div class="shop" v-if="view">
    <div class="head">
      <h1>Einkaufsliste</h1>
      <label class="check small"><input type="checkbox" :checked="settings.shopNotify" @change="emit('save', { shopNotify: $event.target.checked })" /> Meldung von Windows, wenn etwas unter dem Höchstpreis liegt</label>
    </div>

    <div class="layout">
      <aside class="lists">
        <button v-for="l in view.lists" :key="l.id" class="l" :class="{ on: l.id === selected }" @click="selected = l.id">
          <span class="l-name">{{ l.name }}</span><span class="small muted">{{ l.items.length }}</span>
        </button>
        <p v-if="!view.lists.length" class="muted small">Noch keine Liste.</p>
        <div class="l-actions">
          <button @click="addList">Neu</button>
          <button v-if="list" :class="{ warnbtn: confirmDelete }" @click="removeList">{{ confirmDelete ? 'Wirklich löschen?' : 'Löschen' }}</button>
        </div>
        <template v-if="list">
          <label class="small muted">Name<input type="text" :value="list.name" spellcheck="false" @change="setName($event.target.value)" /></label>
          <label class="small muted">Höchstpreis der Liste
            <span class="pct"><input type="text" inputmode="numeric" :value="list.pct" aria-label="Rabatt in Prozent" @change="setPct($event.target.value)" /> % unter dem üblichen Preis</span>
          </label>
        </template>
      </aside>

      <div class="content" v-if="list">
        <div class="add">
          <input type="text" v-model="addText" placeholder="Gegenstand hinzufügen" aria-label="Gegenstand hinzufügen" spellcheck="false" @focus="loadCatalog" />
          <div class="sugg" v-if="suggestions.length">
            <button v-for="s in suggestions" :key="s.key" :style="{ color: qualityColor(s.quality) }" @click="add(s)">{{ s.name }}</button>
          </div>
        </div>
        <p v-if="!list.items.length" class="muted">Die Liste ist leer. Suche oben nach einem Gegenstand oder klicke im Gegenstandsfenster auf „Zur Einkaufsliste“.</p>
        <table v-else class="tbl">
          <thead><tr><th></th><th>Gegenstand</th><th class="num">Menge</th><th class="num" v-if="view.hasLedger" title="Taschen und Bank aller Charaktere, aus Peon_Ledger">Vorrat</th><th class="num">Günstigstes</th><th class="num" title="Eigene Vorgabe, sonst der Wert der Liste">Höchstpreis</th><th class="num">Eigener Höchstpreis (Gold)</th><th class="num" title="Stück im letzten Stand bis zum Höchstpreis">Treffer</th><th></th></tr></thead>
          <tbody>
            <tr v-for="r in list.items" :key="r.key" :class="{ hit: r.hits > 0 }">
              <td class="star"><Star :item-key="r.key" :size="15" /></td>
              <td class="name click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ itemName(r) }}</td>
              <td class="num"><input class="wish" type="text" inputmode="numeric" :value="r.wish ?? ''" placeholder="–" :aria-label="`Menge für ${itemName(r)}`" @change="setWish(r, $event.target.value)" /></td>
              <td class="num" v-if="view.hasLedger" :class="{ muted: r.wish != null && r.stock >= r.wish }">{{ num(r.stock) }}</td>
              <td class="num"><Gold :copper="r.cheapest" compact /></td>
              <td class="num muted"><Gold :copper="r.limit" compact /></td>
              <td class="num"><input class="max" type="text" inputmode="decimal" :value="inGold(r.max)" placeholder="wie Liste" :aria-label="`Eigener Höchstpreis für ${itemName(r)} in Gold`" @change="setMax(r, $event.target.value)" /></td>
              <td class="num" :class="{ win: r.hits > 0 }">{{ r.hits > 0 ? num(r.hits) : '–' }}</td>
              <td class="num"><button class="small" @click="remove(r)">Entfernen</button></td>
            </tr>
          </tbody>
        </table>
        <p class="small muted">Kaufen geht nur im Spiel, im Broker unter Einkaufsliste. Änderungen hier kommen beim nächsten Laden ins Spiel, Änderungen im Spiel von selbst hierher. Die Preise gelten für den gewählten Markt.</p>
      </div>
      <div class="content muted" v-else>Lege links eine Liste an.</div>
    </div>
  </div>
</template>

<style scoped>
.shop { display: grid; gap: 14px; }
.head { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.check { display: flex; gap: 8px; align-items: center; }
.layout { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 24px; align-items: start; }
.lists { display: grid; gap: 6px; padding: 10px; background: var(--panel); border: 1px solid var(--line-soft); border-radius: var(--radius-m); }
.lists label { display: grid; gap: 3px; }
.l { display: flex; justify-content: space-between; gap: 8px; background: none; border: none; border-left: 3px solid transparent; border-radius: 0; padding: 6px 8px; text-align: left; }
.l:hover { background: var(--line-soft); }
.l.on { border-left-color: var(--accent); background: var(--accent-soft); }
.l-name { overflow: hidden; text-overflow: ellipsis; }
.l-actions { display: flex; gap: 6px; margin: 4px 0; flex-wrap: wrap; }
.warnbtn { border-color: var(--warn); color: var(--warn); }
.pct { display: flex; align-items: center; gap: 6px; color: var(--text); }
.pct input { width: 52px !important; text-align: right; flex: none; }
.content { display: grid; gap: 12px; min-width: 0; }
.add { position: relative; max-width: 360px; }
.sugg { position: absolute; left: 0; right: 0; top: calc(100% + 4px); z-index: 20; display: grid; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-s); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); }
.sugg button { background: none; border: none; border-radius: 0; text-align: left; padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; }
.sugg button:hover { background: var(--line-soft); }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); white-space: nowrap; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); }
.tbl th.num, .num { text-align: right; white-space: nowrap; }
.star { width: 28px; padding-right: 0 !important; }
.click { cursor: pointer; }
.click:hover, .click:focus-visible { text-decoration: underline; }
.wish { width: 64px !important; text-align: right; }
.max { width: 96px !important; text-align: right; }
.hit td { background: var(--accent-soft); }
.win { color: var(--up); font-weight: 600; }
</style>
