<script setup>
// Abgleich nachvollziehen (ab 0.31.0, Angleichung A3, Konzept 3.4 und 3.6): Geloeschtes mit Wiederherstellen und das Protokoll
// eines Bereichs (area "shop" = Einkaufslisten, "watch" = Beobachtung) fuer das gewaehlte Konto.
import { ref, computed, watch, onMounted } from 'vue';
import { coins, when, ago, pl } from '../util.js';

const props = defineProps({ area: String, stamp: Number, now: Number });
const api = window.peon;

const log = ref([]);
const trash = ref([]);
const origin = ref('');
const error = ref('');
const busy = ref(0);

async function load() {
  const [l, t] = await Promise.all([api.syncLog(props.area, origin.value || null), api.syncTrash(props.area)]);
  log.value = l;
  trash.value = t;
}
onMounted(load);
watch(() => props.stamp, load);
watch(origin, load);

async function restore(e) {
  busy.value = e.id;
  error.value = '';
  try {
    const r = await api.syncRestore(e.id);
    if (!r.ok) error.value = r.error;
    await load();
  } finally { busy.value = 0; }
}

// Betrag als Text, etwa "1g 20s"
function money(c) {
  const x = coins(c);
  if (!x) return 'leer';
  return [x.g ? `${x.g}g` : '', x.s ? `${x.s}s` : '', x.c || (!x.g && !x.s) ? `${x.c}c` : ''].filter(Boolean).join(' ');
}

const FIELD = { name: 'Name', pct: 'Rabatt', wish: 'Menge', max: 'Höchstpreis', buy: 'Kaufen bis', up: 'Zielpreis' };

function value(field, v) {
  if (v == null) return 'leer';
  if (field === 'pct') return `${v} %`;
  if (field === 'max' || field === 'up') return money(v);
  if (field === 'buy') return v.lim != null ? money(v.lim) : `${v.pct} % unter üblich`;
  if (field === 'wish') return `${v} Stück`;
  return String(v);
}

const itemText = (e) => e.name || e.key;

// Ein Satz je Eintrag, ohne Zeit und Herkunft
function text(e) {
  if (e.kind === 'beide') {
    const where = e.area === 'watch' ? itemText(e) : e.key != null ? `${e.listName || 'Liste'}, ${itemText(e)}` : `Liste ${e.listName || ''}`;
    const winner = e.extra && e.extra.wins === 'spiel' ? `es gilt ${value(e.field, e.new)} aus dem Spiel` : `es gilt ${value(e.field, e.old)} aus dem Manager`;
    return `${where}: ${FIELD[e.field] || e.field} im Spiel ${value(e.field, e.new)}, im Manager ${value(e.field, e.old)}, ${winner}`;
  }
  if (e.area === 'watch') {
    if (e.field === '+') return `${itemText(e)} ${e.kind === 'wiederhergestellt' ? 'wiederhergestellt' : 'beobachtet'}`;
    if (e.field === '-') return `${itemText(e)} nicht mehr beobachtet`;
    return `${itemText(e)}: ${FIELD[e.field]} ${value(e.field, e.old)} → ${value(e.field, e.new)}`;
  }
  if (e.key == null) {
    const n = e.extra && e.extra.n ? ` (${pl(e.extra.n, 'Gegenstand', 'Gegenstände')})` : '';
    if (e.field === '+') return `Liste ${e.listName} ${e.kind === 'wiederhergestellt' ? 'wiederhergestellt' : 'angelegt'}${n}`;
    if (e.field === '-') return `Liste ${e.listName} gelöscht${n}`;
    return `Liste ${e.listName}: ${FIELD[e.field]} ${value(e.field, e.old)} → ${value(e.field, e.new)}`;
  }
  if (e.field === '+') return `${itemText(e)} ${e.kind === 'wiederhergestellt' ? 'wiederhergestellt in' : 'hinzugefügt zu'} ${e.listName}`;
  if (e.field === '-') return `${itemText(e)} aus ${e.listName} entfernt`;
  return `${e.listName}, ${itemText(e)}: ${FIELD[e.field]} ${value(e.field, e.old)} → ${value(e.field, e.new)}`;
}

const ORIGIN = { spiel: 'aus dem Spiel', manager: 'im Manager', beide: 'beide geändert' };

function trashText(e) {
  if (e.what === 'list') return `Liste ${e.listName}${e.n ? ` (${pl(e.n, 'Gegenstand', 'Gegenstände')})` : ''}`;
  if (e.what === 'item') return `${itemText(e)} aus ${e.listName}`;
  return itemText(e);
}

const trashTitle = computed(() => (trash.value.length ? pl(trash.value.length, 'Eintrag', 'Einträge') : 'Nichts gelöscht'));
const logTitle = computed(() => (log.value.length ? `${pl(log.value.length, 'Eintrag', 'Einträge')}, neueste oben` : 'Noch keine Einträge'));
</script>

<template>
  <div class="sync">
    <details class="fold">
      <summary><h2>Gelöscht</h2><span class="small muted">{{ trashTitle }}</span></summary>
      <div class="inner">
        <p class="small muted">Was im Spiel oder hier gelöscht wurde, lässt sich 30 Tage lang wiederherstellen. Es kommt dann auch wieder ins Spiel.</p>
        <p v-if="error" class="small warn" role="alert">{{ error }}</p>
        <table v-if="trash.length" class="tbl">
          <tbody>
            <tr v-for="e in trash" :key="e.id">
              <td class="faint small nowrap" :title="when(e.t)">{{ ago(e.t, now) }}</td>
              <td>{{ trashText(e) }}</td>
              <td class="muted small">{{ e.origin === 'spiel' ? 'im Spiel gelöscht' : 'im Manager gelöscht' }}</td>
              <td class="r"><button :disabled="!!busy" @click="restore(e)">{{ busy === e.id ? 'Stellt her' : 'Wiederherstellen' }}</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </details>

    <details class="fold">
      <summary><h2>Protokoll</h2><span class="small muted">{{ logTitle }}</span></summary>
      <div class="inner">
        <div class="head">
          <p class="small muted">Jede Änderung aus dem Spiel und aus dem Manager, 90 Tage lang. „Beide geändert“ heißt: derselbe Wert wurde im Spiel und hier geändert, die neuere Änderung gilt.</p>
          <label class="small">Herkunft
            <select v-model="origin">
              <option value="">Alle</option>
              <option value="spiel">Aus dem Spiel</option>
              <option value="manager">Im Manager</option>
              <option value="beide">Beide geändert</option>
            </select>
          </label>
        </div>
        <ul v-if="log.length" class="log">
          <li v-for="e in log" :key="e.id" :class="{ both: e.kind === 'beide' }">
            <span class="faint small">{{ when(e.t) }}</span>
            <span class="small kind">{{ ORIGIN[e.origin] || e.origin }}</span>
            <span class="small">{{ text(e) }}</span>
          </li>
        </ul>
      </div>
    </details>
  </div>
</template>

<style scoped>
.sync { display: grid; gap: 18px; }
.fold { border-top: 1px solid var(--line-soft); padding-top: 14px; }
.fold summary { display: flex; align-items: baseline; gap: 14px; cursor: pointer; list-style: none; flex-wrap: wrap; }
.fold summary::-webkit-details-marker { display: none; }
.fold summary h2 { margin: 0; }
.fold summary h2::before { content: '▸'; display: inline-block; width: 18px; color: var(--muted); }
.fold[open] summary h2::before { content: '▾'; }
.inner { display: grid; gap: 12px; padding-top: 14px; }
.head { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap; }
.head p { margin: 0; max-width: 72ch; }
.head select { margin-left: 8px; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl td { padding: 7px 10px 7px 0; border-bottom: 1px solid var(--line-soft); vertical-align: middle; }
.r { text-align: right; }
.nowrap { white-space: nowrap; }
.log { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; max-height: 420px; overflow: auto; }
.log li { display: grid; grid-template-columns: 110px 120px 1fr; gap: 10px; }
.log li.both .kind, .log li.both span:last-child { color: var(--warn); }
.kind { color: var(--muted); }
.warn { color: var(--warn); }
</style>
