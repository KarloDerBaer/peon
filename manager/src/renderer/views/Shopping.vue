<script setup>
// Einkaufen (ab 0.33.0 neu, Angleichung A5, Konzept docs/konzepte/manager/Peon_Manager_Angleichung.md 4.2).
// Dieselben Listen wie im Spiel unter Einkaufen, je WoW-Konto. Eingaben gehen ueber Data.lua ins Spiel, Aenderungen im
// Spiel kommen von selbst zurueck. Vorrat aus Peon_Ledger wie im Spiel: Taschen und Bank aller Charaktere des Kontos.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import Star from '../components/Star.vue';
import SyncPanel from '../components/SyncPanel.vue';
import MoneyInput from '../components/MoneyInput.vue';
import { num, fold, qualityColor, itemName } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, settings: Object, now: Number });
const emit = defineEmits(['open', 'save', 'go']);
const api = window.peon;

const view = ref(null);
const accts = ref({ list: [], selected: null });
const selected = ref(null);
const confirmDelete = ref(false);
const addText = ref('');
const catalog = ref([]);

async function load() {
  const [v, a] = await Promise.all([api.shopView(props.market ? props.market.key : ''), api.accounts()]);
  view.value = v;
  accts.value = a;
  if (!view.value.lists.some((l) => l.id === selected.value)) selected.value = view.value.lists.length ? view.value.lists[0].id : null;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

const list = computed(() => (view.value ? view.value.lists.find((l) => l.id === selected.value) || null : null));
watch(selected, () => { confirmDelete.value = false; });

// Konto (nur bei mehreren Konten)
const acctLabel = (a) => a.name || a.folder || a.id;
async function selectAcct(id) { await api.accountSelect(id); await load(); }

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
async function setMax(r, copper) {   // ab 0.34.0 aus MoneyInput (Gold, Silber, Kupfer), leer = Wert der Liste
  await api.shopSet(selected.value, r.key, { max: copper || 0 });
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

const inGold = (c) => (c == null ? '' : String(Math.round(c) / 10000).replace('.', ','));
const waitText = computed(() => (view.value && view.value.running ? 'wartet auf /reload' : 'beim nächsten Anmelden'));
const needTip = (r) => (r.wish == null ? 'Keine Menge eingetragen' : r.stock == null ? 'Ohne Peon_Ledger ist der Vorrat unbekannt' : `Vorrat ${num(r.stock)} in Taschen und Bank aller Charaktere dieses Kontos`);
const limitTip = (r) => (r.max != null ? `Eigener Höchstpreis. Die Liste ergäbe ${r.rule != null ? inGold(r.rule) + ' Gold' : 'noch keinen Wert'}.` : `Wert der Liste: ${list.value ? list.value.pct : 0} % unter dem üblichen Preis. Ein eigener Wert geht vor.`);
</script>

<template>
  <div class="shop" v-if="view">
    <div class="head">
      <h1>Einkaufen</h1>
      <div class="tools">
        <label v-if="accts.list.length > 1" class="small acct">Konto
          <select :value="accts.selected" @change="selectAcct($event.target.value)">
            <option v-for="a in accts.list" :key="a.id" :value="a.id">{{ acctLabel(a) }}</option>
          </select>
        </label>
        <label class="check small"><input type="checkbox" :checked="settings.shopNotify" @change="emit('save', { shopNotify: $event.target.checked })" /> Meldung von Windows, wenn etwas unter dem Höchstpreis liegt</label>
      </div>
    </div>

    <div class="layout">
      <aside class="lists">
        <button v-for="l in view.lists" :key="l.id" class="l" :class="{ on: l.id === selected }" @click="selected = l.id">
          <span class="l-name">{{ l.name }}</span>
          <span class="small" :class="l.wait ? 'warn' : 'muted'" :title="l.wait ? waitText : ''">{{ l.wait ? '•' : '' }} {{ l.items.length }}</span>
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
          <p v-if="list.wait" class="small warn">Änderung an der Liste {{ waitText }}</p>
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
          <thead>
            <tr>
              <th></th><th>Gegenstand</th>
              <th class="num">Menge</th>
              <th class="num" title="Menge minus Vorrat (Taschen und Bank aller Charaktere dieses Kontos, aus Peon_Ledger)">Fehlt</th>
              <th class="num" title="Günstigstes Angebot im letzten Stand des gewählten Markts">Preis</th>
              <th class="num" title="Eigener Wert, sonst der Wert der Liste. Leeren nimmt wieder den Wert der Liste.">Höchstpreis</th>
              <th class="num" title="Stück im letzten Stand bis zum Höchstpreis">Treffer</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in list.items" :key="r.key" :class="{ hit: r.hits > 0 && r.need !== 0 }">
              <td class="star"><Star :item-key="r.key" :size="15" /></td>
              <td class="name">
                <span class="click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ itemName(r) }}</span>
                <span v-if="r.wait" class="wait small" title="Änderung ist noch nicht im Spiel">{{ waitText }}</span>
              </td>
              <td class="num"><input class="wish" type="text" inputmode="numeric" :value="r.wish ?? ''" placeholder="–" :aria-label="`Menge für ${itemName(r)}`" @change="setWish(r, $event.target.value)" /></td>
              <td class="num" :class="{ muted: r.need === 0 }" :title="needTip(r)">{{ r.need == null ? '–' : r.need === 0 ? 'genug' : num(r.need) }}</td>
              <td class="num"><Gold :copper="r.cheapest" compact /></td>
              <td class="num" :class="{ own: r.max != null }"><MoneyInput :value="r.max" :placeholder="r.rule" :title="limitTip(r)" :label="`Höchstpreis für ${itemName(r)}`" @change="setMax(r, $event)" /></td>
              <td class="num" :class="{ win: r.hits > 0 }">{{ r.hits > 0 ? num(r.hits) : '–' }}</td>
              <td class="num"><button class="small" @click="remove(r)">Entfernen</button></td>
            </tr>
          </tbody>
        </table>
        <p class="small muted">Kaufen geht nur im Spiel, im Broker unter Einkaufen. Änderungen hier kommen beim nächsten Laden ins Spiel, Änderungen im Spiel von selbst hierher. Die Preise gelten für den gewählten Markt.<template v-if="!view.hasLedger"> Mit Peon_Ledger siehst du hier auch, was schon in deinen Taschen und auf der Bank liegt.</template></p>
      </div>
      <div class="content muted" v-else>Lege links eine Liste an.</div>
    </div>

    <SyncPanel area="shop" :stamp="stamp" :now="now" />
  </div>
</template>

<style scoped>
.shop { display: grid; gap: 14px; }
.head { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.head h1 { margin: 0; }
.tools { display: flex; gap: 18px; align-items: center; flex-wrap: wrap; }
.acct select { margin-left: 8px; }
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
.warn { color: var(--warn); }
.pct { display: flex; align-items: center; gap: 6px; color: var(--text); }
.pct input { width: 52px !important; text-align: right; flex: none; }
.content { display: grid; gap: 12px; min-width: 0; }
.add { position: relative; max-width: 360px; }
.sugg { position: absolute; left: 0; right: 0; top: calc(100% + 4px); z-index: 20; display: grid; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-s); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); }
.sugg button { background: none; border: none; border-radius: 0; text-align: left; padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; }
.sugg button:hover { background: var(--line-soft); }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); white-space: nowrap; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); vertical-align: middle; }
.tbl th.num, .num { text-align: right; white-space: nowrap; }
.star { width: 28px; padding-right: 0 !important; }
.name { min-width: 160px; }
.click { cursor: pointer; }
.click:hover, .click:focus-visible { text-decoration: underline; }
.wait { display: inline-block; margin-left: 8px; padding: 1px 6px; border: 1px solid var(--warn); border-radius: var(--radius-s); color: var(--warn); }
.wish { width: 64px !important; text-align: right; }
.own :deep(input) { font-weight: 600; }
.hit td { background: var(--accent-soft); }
.win { color: var(--up); font-weight: 600; }
</style>
