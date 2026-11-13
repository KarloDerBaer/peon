<script setup>
// Erfolgskontrolle (ab Manager 0.35.0, Peon_Manager_Chancen.md Abschnitt 8): Trefferquote je Art und je Signal ueber
// 30 Tage mit Verlauf, dazu die eigenen Kaeufe im Auktionshaus aus Ledger mit Einsatz, Erloes und Dauer.
// Die fruehere Trefferquote des Wiederverkaufs (F55) ist hierin aufgegangen.
import { ref, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import { num, qualityColor, itemName, when } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number });
const emit = defineEmits(['open', 'brief']);
const d = ref(null);
async function load() { if (props.market) d.value = await window.peon.successView(props.market.key); }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
const KIND = { s: 'Spekulation schnell', l: 'Spekulation langfristig', b: 'Aufkauf', v: 'Händler' };
const pctOf = (x) => (x == null ? '–' : `${Math.round(x * 100)} %`);
// kleine Linie aus den Tagen
function path(days) {
  if (!days || days.length < 2) return '';
  const d0 = days[0].day, d1 = days[days.length - 1].day;
  return days.map((x, i) => `${i ? 'L' : 'M'}${((x.day - d0) / Math.max(1, d1 - d0) * 160).toFixed(1)},${(30 - x.rate * 28).toFixed(1)}`).join(' ');
}
</script>

<template>
  <div class="sc" v-if="market">
    <div class="head"><h1>Erfolgskontrolle</h1><span class="small muted">letzte 30 Tage</span></div>
    <p class="small muted intro">Jeder Vorschlag wird nach seinem Zeitraum nachgeprüft: gelohnt, wenn der Preis danach den Zielpreis erreichte, „gerade so“, wenn immerhin Kaufpreis und Gebühr wieder drin waren. Jedes Signal der Prognosen zählt, wenn sich der Preis um mindestens die Hälfte des Erwarteten in die genannte Richtung bewegte.</p>
    <template v-if="d">
      <section class="box">
        <h3>Vorschläge je Art</h3>
        <table class="tbl">
          <thead><tr><th>Art</th><th class="num">Nachgeprüft</th><th class="num">Gelohnt</th><th class="num">Gerade so</th><th class="num">Nicht</th><th class="num">Offen</th><th class="num">Trefferquote</th><th>Verlauf</th></tr></thead>
          <tbody>
            <tr v-for="(x, k) in d.rates" :key="k">
              <td>{{ KIND[k] }}</td><td class="num">{{ num(x.n) }}</td><td class="num">{{ num(x.hit) }}</td><td class="num">{{ num(x.even) }}</td><td class="num">{{ num(x.miss) }}</td><td class="num muted">{{ num(x.open) }}</td>
              <td class="num strong">{{ pctOf(x.rate) }}</td>
              <td><svg v-if="x.days.length > 1" width="160" height="32" aria-hidden="true"><path :d="path(x.days)" fill="none" stroke="var(--accent)" stroke-width="1.6" /></svg></td>
            </tr>
          </tbody>
        </table>
      </section>
      <section class="box">
        <h3>Signale der Prognosen</h3>
        <table class="tbl">
          <thead><tr><th>Signal</th><th class="num">Nachgeprüft</th><th class="num">Treffer</th><th class="num">Trefferquote</th><th>Zustand</th></tr></thead>
          <tbody>
            <tr v-for="s in d.signals" :key="s.id">
              <td>{{ s.label }}</td><td class="num">{{ num(s.n) }}</td><td class="num">{{ num(s.hit) }}</td><td class="num strong">{{ pctOf(s.rate) }}</td>
              <td class="small muted">{{ s.n < 20 ? 'neu, zählt noch nicht für die Sicherheit' : s.rate < 0.4 ? 'unter 40 %, wird nicht angezeigt' : 'zählt' }}</td>
            </tr>
          </tbody>
        </table>
      </section>
      <section class="box">
        <h3>Eigene Käufe im Auktionshaus (aus Ledger)</h3>
        <table class="tbl" v-if="d.buys.length">
          <thead><tr><th>Gekauft</th><th>Gegenstand</th><th class="num">Stück</th><th class="num">Einsatz</th><th class="num">Erlös</th><th class="num">Dauer</th><th>Vorschlag</th></tr></thead>
          <tbody>
            <tr v-for="b in d.buys" :key="b.t + b.key" class="click" @click="emit('brief', b.key)">
              <td class="small muted">{{ when(b.t) }}</td>
              <td :style="{ color: qualityColor(b.quality) }">{{ itemName({ name: b.name, item: b.key }) }}</td>
              <td class="num">{{ num(b.qty) }}</td>
              <td class="num"><Gold :copper="b.cost" compact /></td>
              <td class="num"><Gold v-if="b.income" :copper="b.income" compact /><span v-else class="faint">noch nicht verkauft</span></td>
              <td class="num small">{{ b.hours == null ? '–' : b.hours < 24 ? Math.round(b.hours) + ' Std.' : Math.round(b.hours / 24) + ' Tage' }}</td>
              <td class="small">{{ b.kind ? KIND[b.kind] : '–' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="small muted">Keine Käufe in den letzten 30 Tagen gefunden.</p>
      </section>
    </template>
  </div>
  <p v-else class="muted">Noch kein Markt eingelesen.</p>
</template>

<style scoped>
.sc { display: grid; gap: 14px; max-width: 1180px; align-content: start; }
.head { display: flex; align-items: baseline; gap: 16px; }
.intro { max-width: 100ch; margin: 0; }
.box { border: 1px solid var(--line-soft); border-radius: var(--radius-m); padding: 12px 16px; display: grid; gap: 8px; background: var(--raised); }
.box h3 { margin: 0; }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); }
.num { text-align: right !important; }
.strong { font-weight: 600; }
.click { cursor: pointer; }
.click:hover td { background: var(--panel); }
</style>
