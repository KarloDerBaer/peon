<script setup>
// Stabilitaet der Preise (ab Manager 0.45.0): Markt, Gruppen, Kategorien, Verlauf und Gegenstaende (stability.js)
import { ref, computed, watch, onMounted } from 'vue';
import StabilityChart from './StabilityChart.vue';
import { num, pct, fold, qualityColor, itemName, when } from '../util.js';

const props = defineProps({ market: Object, stamp: Number, theme: String });
const emit = defineEmits(['brief']);
const d = ref(null);
const kind = ref('mass');
const cat = ref(null);
const open = ref(new Set());
const search = ref('');
const sortKey = ref('a');
const sortAsc = ref(false);
const limit = ref(60);

async function load() { if (props.market) d.value = await window.peon.stabilityView(props.market.key); }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
watch([kind, cat, search, sortKey, sortAsc], () => { limit.value = 60; });

const LEVELS = ['sehr stabil', 'stabil', 'mittel', 'unruhig', 'unsicher'];
const level = (g) => (g == null ? '–' : LEVELS[g]);
const p1 = (x) => (x == null ? '–' : (x * 100).toLocaleString('de-DE', { maximumFractionDigits: 1, minimumFractionDigits: 1 }) + ' %');
const CRAFT = 7;
const KINDS = [
  { key: 'mass', label: 'Massenware' },
  { key: 'craft', label: 'Handwerkswaren' },
  { key: 'single', label: 'Einzelgegenstände' },
  { key: 'all', label: 'Alle' },
];
const GROUPS = [
  { key: 'all', label: 'Ganzer Markt' },
  { key: 'mass', label: 'Massenware' },
  { key: 'craft', label: 'Handwerkswaren' },
  { key: 'single', label: 'Einzelgegenstände' },
];

const cats = computed(() => {
  if (!d.value || !d.value.cats) return [];
  return d.value.cats.filter((c) => !c.parent || open.value.has(c.parent));
});
const hasSubs = computed(() => new Set(((d.value && d.value.cats) || []).filter((c) => c.parent).map((c) => c.parent)));
function toggle(c) {
  const s = new Set(open.value);
  if (s.has(c.key)) s.delete(c.key); else s.add(c.key);
  open.value = s;
}
function pickCat(c) { cat.value = cat.value && cat.value.key === c.key ? null : c; }

const list = computed(() => {
  if (!d.value || !d.value.items) return [];
  const q = fold(search.value.trim());
  const k = kind.value;
  let xs = d.value.items.filter((x) => (k === 'all' || (k === 'mass' ? x.m : k === 'single' ? !x.m : x.c === CRAFT)));
  if (cat.value) {
    const [c, s] = cat.value.key.split('/');
    xs = xs.filter((x) => (c === 'c?' ? x.c == null : `c${x.c}` === c && (!s || `s${x.s}` === s)));
  }
  if (q) xs = xs.filter((x) => fold(itemName(x)).includes(q));
  const key = sortKey.value, dir = sortAsc.value ? 1 : -1;
  const val = (x) => (key === 'name' ? null : key === 'dir' ? (x.dir == null ? null : Math.abs(x.dir)) : x[key]);
  return [...xs].sort((a, b) => {
    if (key === 'name') return dir * itemName(a).localeCompare(itemName(b), 'de');
    const va = val(a), vb = val(b);
    if (va == null && vb == null) return 0;
    if (va == null) return 1;
    if (vb == null) return -1;
    return dir * (va - vb);
  });
});
function sortBy(k) {
  if (sortKey.value === k) sortAsc.value = !sortAsc.value;
  else { sortKey.value = k; sortAsc.value = k === 'i' || k === 'name'; }
}
const arrow = (k) => (sortKey.value === k ? (sortAsc.value ? ' ▲' : ' ▼') : '');

const hist = computed(() => (d.value && d.value.hist) || []);
</script>

<template>
  <div class="st">
    <p v-if="!d || !d.t" class="muted">Noch keine Rechnung. Sie läuft nach jedem neuen Stand im Hintergrund und braucht Stände der Blizzard-API (Stunden) oder Daten an mindestens 5 Tagen.</p>
    <template v-else>
      <p class="small muted intro">
        Stunden: wie stark sich der Preis von Stand zu Stand der Blizzard-API bewegt (7 Tage). Tage: wie stark die Tageswerte schwanken (14 Tage).
        Es zählt der schlechtere Teil. Preis bei Massenware: die günstigsten 25 %, sonst das günstigste Angebot.
        Gegenstände mit weniger als {{ d.few }} Angeboten im Schnitt zählen nicht und stehen nur auf ihrer eigenen Seite. Stand {{ when(d.t) }}, {{ num(d.apiStands) }} Stände der API.
      </p>

      <div class="cards">
        <div v-for="g in GROUPS" :key="g.key" class="card" :class="{ none: !d.groups[g.key] }">
          <div class="small muted">{{ g.label }}</div>
          <template v-if="d.groups[g.key]">
            <div class="big" :class="'lv' + d.groups[g.key].g">{{ level(d.groups[g.key].g) }}</div>
            <div class="small">Index {{ d.groups[g.key].i }} · {{ num(d.groups[g.key].n) }} Gegenstände</div>
            <div class="small muted">Stunden {{ p1(d.groups[g.key].h) }} · Tage {{ p1(d.groups[g.key].d) }}</div>
            <div class="bar" :title="LEVELS.map((l, i) => `${l}: ${d.groups[g.key].per[i]}`).join(', ')">
              <span v-for="(n, i) in d.groups[g.key].per" :key="i" :class="'bg' + i" :style="{ flexGrow: n }"></span>
            </div>
          </template>
          <div v-else class="small muted">Keine Daten<template v-if="g.key === 'craft'">. Die Kategorien kommen mit den nächsten Ständen der Blizzard-API.</template></div>
        </div>
      </div>

      <div class="hist">
        <h3>Verlauf des Index</h3>
        <StabilityChart v-if="hist.length > 1" :hist="hist" :theme="theme" />
        <p v-else class="small muted">Ab der zweiten Rechnung steht hier der Verlauf. Gerechnet wird nach jedem neuen Stand, gespeichert werden 30 Tage.</p>
      </div>

      <h3>Kategorien</h3>
      <table class="tbl cats">
        <thead><tr><th>Kategorie</th><th class="num">Gegenstände</th><th class="num">Stufe</th><th class="num">Index</th><th class="num">Stunden</th><th class="num">Tage</th><th class="num">Massenware</th></tr></thead>
        <tbody>
          <tr v-for="c in cats" :key="c.key" class="click" :class="{ sub: c.parent, on: cat && cat.key === c.key }" @click="pickCat(c)">
            <td>
              <button v-if="!c.parent && hasSubs.has(c.key)" class="fold" :aria-label="open.has(c.key) ? 'Zuklappen' : 'Aufklappen'" @click.stop="toggle(c)">{{ open.has(c.key) ? '▾' : '▸' }}</button>
              <span v-else-if="!c.parent" class="fold"></span>
              {{ c.name }}
            </td>
            <td class="num">{{ num(c.n) }}</td>
            <td class="num" :class="'lv' + c.g">{{ level(c.g) }}</td>
            <td class="num">{{ c.i }}</td>
            <td class="num">{{ p1(c.h) }}</td>
            <td class="num">{{ p1(c.d) }}</td>
            <td class="num" :class="c.mass ? 'lv' + c.mass.g : ''">{{ c.mass ? `${level(c.mass.g)} (${c.mass.i})` : '–' }}</td>
          </tr>
        </tbody>
      </table>

      <h3>Gegenstände<template v-if="cat"> in {{ cat.name }} <button class="link" @click="cat = null">alle Kategorien</button></template></h3>
      <div class="filters">
        <div class="seg" role="group" aria-label="Art">
          <button v-for="k in KINDS" :key="k.key" :class="{ on: kind === k.key }" @click="kind = k.key">{{ k.label }}</button>
        </div>
        <input type="text" v-model="search" placeholder="Name suchen" aria-label="Suchen" spellcheck="false" />
      </div>
      <table class="tbl" v-if="list.length">
        <thead><tr>
          <th class="click" @click="sortBy('name')">Gegenstand{{ arrow('name') }}</th>
          <th class="num click" @click="sortBy('i')">Stufe{{ arrow('i') }}</th>
          <th class="num click" @click="sortBy('i')">Index</th>
          <th class="num click" @click="sortBy('h')" title="Mittlere Bewegung je Stunde">Stunden{{ arrow('h') }}</th>
          <th class="num click" @click="sortBy('d')" title="Schwankung der Tageswerte">Tage{{ arrow('d') }}</th>
          <th class="num click" @click="sortBy('dir')" title="Erster zu letztem Tageswert">Richtung{{ arrow('dir') }}</th>
          <th class="num click" @click="sortBy('a')" title="Angebote im Schnitt">Angebote{{ arrow('a') }}</th>
        </tr></thead>
        <tbody>
          <tr v-for="x in list.slice(0, limit)" :key="x.key" class="click" @click="emit('brief', x.key)">
            <td class="name" :style="{ color: qualityColor(x.quality) }">{{ itemName(x) }}</td>
            <td class="num" :class="'lv' + x.g">{{ level(x.g) }}</td>
            <td class="num">{{ x.i }}</td>
            <td class="num" :class="x.ih != null ? 'lv' + Math.min(4, Math.floor((100 - x.ih) / 20)) : 'muted'">{{ p1(x.h) }}</td>
            <td class="num" :class="x.id != null ? 'lv' + Math.min(4, Math.floor((100 - x.id) / 20)) : 'muted'">{{ p1(x.d) }}</td>
            <td class="num" :class="x.dir == null ? 'muted' : x.dir < 0 ? 'down' : 'up'">{{ x.dir == null ? '–' : `${pct(x.dir)} in ${x.span} T.` }}</td>
            <td class="num muted">{{ x.a == null ? '–' : num(Math.round(x.a)) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-else class="muted">Keine Gegenstände in dieser Auswahl.</p>
      <p v-if="list.length > limit" class="small muted">{{ num(limit) }} von {{ num(list.length) }} <button class="link" @click="limit += 60">60 weitere zeigen</button></p>
    </template>
  </div>
</template>

<style scoped>
.st { display: grid; gap: 14px; }
.intro { max-width: 100ch; margin: 0; }
h3 { margin: 6px 0 0; font-size: 15px; font-weight: 600; }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 10px; }
.card { border: 1px solid var(--line-soft); border-radius: var(--radius-m); padding: 10px 14px; display: grid; gap: 4px; }
.card.none { opacity: 0.7; }
.big { font-size: 20px; font-weight: 600; }
.bar { display: flex; height: 6px; border-radius: 3px; overflow: hidden; margin-top: 4px; background: var(--line-soft); }
.bar span { min-width: 0; }
.bg0 { background: var(--up); }
.bg1 { background: color-mix(in srgb, var(--up) 60%, var(--warn)); }
.bg2 { background: var(--warn); }
.bg3 { background: color-mix(in srgb, var(--warn) 50%, var(--bad)); }
.bg4 { background: var(--bad); }
.hist { display: grid; gap: 6px; }
.filters { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.filters input { width: 260px; }
.seg { display: flex; gap: 4px; }
.seg button { padding: 4px 10px; }
.seg button.on { background: var(--accent-soft); border-color: var(--accent); }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); white-space: nowrap; }
.tbl td { padding: 7px 8px; border-bottom: 1px solid var(--line-soft); white-space: nowrap; }
.tbl th:first-child, .tbl td:first-child { padding-left: 0; }
.num { text-align: right !important; }
.click { cursor: pointer; }
.click:hover td { background: var(--raised); }
tr.on td { background: var(--accent-soft); }
tr.sub td:first-child { padding-left: 30px; }
.fold { display: inline-block; width: 20px; background: none; border: none; padding: 0; color: var(--muted); }
.up { color: var(--up); }
.down { color: var(--bad); }
</style>
