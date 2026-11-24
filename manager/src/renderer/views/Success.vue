<script setup>
// Erfolgskontrolle (ab Manager 0.35.0, Peon_Manager_Chancen.md Abschnitt 8): Trefferquote je Art und je Signal ueber
// 30 Tage mit Verlauf, dazu die eigenen Kaeufe im Auktionshaus aus Ledger mit Einsatz, Erloes und Dauer.
// Die fruehere Trefferquote des Wiederverkaufs (F55) ist hierin aufgegangen.
import { ref, computed, watch, onMounted } from 'vue';
import Gold from '../components/Gold.vue';
import { num, qualityColor, itemName, when } from '../util.js';

const props = defineProps({ market: Object, now: Number, stamp: Number });
const emit = defineEmits(['open', 'brief']);
const d = ref(null);
async function load() { if (props.market) d.value = await window.peon.successView(props.market.key); }
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);
const KIND = { s: 'Spekulation schnell', l: 'Spekulation langfristig', b: 'Aufkauf', m: 'Muster', v: 'Händler' };
// ab 0.36.0: Kauf zum Behalten, zaehlt nicht als Spekulation
const ownBuys = computed(() => (d.value ? d.value.buys.filter((b) => b.own) : []));
const tradeBuys = computed(() => (d.value ? d.value.buys.filter((b) => !b.own) : []));
const showOwn = ref(false);
async function setOwn(b, on) {
  await window.peon.setOwnUse(b.key, b.t, on);
  b.own = on;
}
const CMP_OUT = { held: 'gehalten', partly: 'teilweise', failed: 'nicht gehalten', nodata: 'keine Daten' };   // ab 0.52.0
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
    <p class="small muted intro">Jeder Vorschlag wird nach seinem Zeitraum nachgeprüft: gelohnt, wenn danach mindestens die vorgeschlagene Menge zum Zielpreis verkauft wurde, „gerade so“, wenn die Verkäufe immerhin Kaufpreis und Gebühr brachten. Als Verkauf zählt nur ein Angebot, das als günstigstes verschwand, ohne dass ein gleich billiges oder billigeres neu kam und ohne dass es einfach ablief. Angebotspreise allein zählen nicht. Jedes Signal der Prognosen zählt, wenn sich der Preis um mindestens die Hälfte des Erwarteten in die genannte Richtung bewegte.</p>
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
        <table class="tbl" v-if="tradeBuys.length">
          <thead><tr><th>Gekauft</th><th>Gegenstand</th><th class="num">Stück</th><th class="num">Einsatz</th><th class="num">Erlös</th><th class="num">Dauer</th><th>Vorschlag</th><th></th></tr></thead>
          <tbody>
            <tr v-for="b in tradeBuys" :key="b.t + b.key" class="click" tabindex="0" @click="emit('brief', b.key)" @keydown.enter="emit('brief', b.key)">
              <td class="small muted">{{ when(b.t) }}</td>
              <td :style="{ color: qualityColor(b.quality) }">{{ itemName({ name: b.name, item: b.key }) }}</td>
              <td class="num">{{ num(b.qty) }}</td>
              <td class="num"><Gold :copper="b.cost" compact /></td>
              <td class="num"><Gold v-if="b.income" :copper="b.income" compact /><span v-else class="faint">noch nicht verkauft</span></td>
              <td class="num small">{{ b.hours == null ? '–' : b.hours < 24 ? Math.round(b.hours) + ' Std.' : Math.round(b.hours / 24) + ' Tage' }}</td>
              <td class="small">{{ b.kind ? KIND[b.kind] : '–' }}</td>
              <td class="num"><button class="small" title="Für dich selbst gekauft, zählt nicht als Spekulation" @click.stop="setOwn(b, true)">Behalte ich</button></td>
            </tr>
          </tbody>
        </table>
        <p v-if="d.buys.length && !tradeBuys.length" class="small muted">Alle Käufe sind als „Behalte ich“ markiert.</p>
        <p v-if="ownBuys.length" class="small muted">
          {{ ownBuys.length === 1 ? '1 Kauf behältst' : `${num(ownBuys.length)} Käufe behältst` }} du selbst, {{ ownBuys.length === 1 ? 'er zählt' : 'sie zählen' }} hier nicht mit.
          <button class="link" @click="showOwn = !showOwn">{{ showOwn ? 'Ausblenden' : 'Zeigen' }}</button>
        </p>
        <table class="tbl own" v-if="showOwn && ownBuys.length">
          <tbody>
            <tr v-for="b in ownBuys" :key="'o' + b.t + b.key">
              <td class="small muted">{{ when(b.t) }}</td>
              <td :style="{ color: qualityColor(b.quality) }">{{ itemName({ name: b.name, item: b.key }) }}</td>
              <td class="num">{{ num(b.qty) }}</td>
              <td class="num"><Gold :copper="b.cost" compact /></td>
              <td class="num"><button class="small" @click="setOwn(b, false)">Doch mitzählen</button></td>
            </tr>
          </tbody>
        </table>
        <p v-if="!d.buys.length" class="small muted">Keine Käufe in den letzten 30 Tagen gefunden.</p>
      </section>
      <!-- ab 0.52.0: Marktvergleich mit dem neutralen Haus -->
      <section class="box" v-if="d.compare">
        <h3>Marktvergleich: Auswahl für Broker</h3>
        <p class="small muted">Jeder Vorschlag aus dem Marktvergleich wird {{ d.compare.checkDays }} Tage danach nachgeprüft: gehalten, wenn ein Verkauf im Zielhaus nach Anteil und Kaufpreis mindestens die Hälfte des erwarteten Gewinns brachte, „teilweise“, wenn immerhin Gewinn blieb, „nicht gehalten“ auch dann, wenn dort nichts verkauft wurde.</p>
        <p v-if="!d.compare.total" class="muted">Noch keine Vorschläge gemerkt. Das beginnt mit der nächsten Rechnung des Marktvergleichs.</p>
        <template v-else>
          <p>{{ num(d.compare.total) }} Vorschläge in 30 Tagen, {{ num(d.compare.checked) }} nachgeprüft:
            <span class="good">{{ num(d.compare.held) }} gehalten</span>, {{ num(d.compare.partly) }} teilweise, <span class="warn">{{ num(d.compare.failed) }} nicht gehalten</span><template v-if="d.compare.checked"> ({{ pctOf(d.compare.held / d.compare.checked) }} Trefferquote)</template>.</p>
          <table class="tbl">
            <thead><tr><th>Gegenstand</th><th>Richtung</th><th>Vorgeschlagen</th><th class="num">Erwartet</th><th class="num">Danach</th><th>Ergebnis</th></tr></thead>
            <tbody>
              <tr v-for="r in d.compare.rows" :key="r.key + r.dir + r.day">
                <td class="click" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)">{{ r.name || r.key }}</td>
                <td class="small">{{ r.dir === 'n' ? `${d.compare.home} → ${d.compare.neutral}` : `${d.compare.neutral} → ${d.compare.home}` }}</td>
                <td class="small">{{ when(r.t) }}</td>
                <td class="num"><Gold :copper="r.net" compact /></td>
                <td class="num"><Gold v-if="r.real != null" :copper="r.real" compact /><span v-else class="muted">–</span></td>
                <td :class="{ good: r.outcome === 'held', warn: r.outcome === 'failed' }">{{ CMP_OUT[r.outcome] || 'wartet' }}</td>
              </tr>
            </tbody>
          </table>
        </template>
        <h3>Pakete</h3>
        <p class="small muted">Je Tag und Richtung das erste Paket. Gekauft zählt im Haus der Quelle bis 7 Tage danach, verkauft im Haus des Ziels (aus Peon Ledger, ab Version 0.17).</p>
        <p v-if="!d.compare.packages || !d.compare.packages.length" class="muted">Noch keine Pakete gemerkt.</p>
        <table v-else class="tbl">
          <thead><tr><th>Paket</th><th>Richtung</th><th class="num">Einsatz geplant</th><th class="num">Gekauft</th><th class="num">Verkauft</th><th class="num">Ausgegeben</th><th class="num">Erlös</th><th class="num">Ergebnis</th></tr></thead>
          <tbody>
            <tr v-for="k in d.compare.packages" :key="k.dir + k.t">
              <td class="small">{{ when(k.t) }}<span class="muted"> · {{ k.names.join(', ') }}<template v-if="k.n > k.names.length"> …</template></span></td>
              <td class="small">{{ k.dir === 'n' ? `${d.compare.home} → ${d.compare.neutral}` : `${d.compare.neutral} → ${d.compare.home}` }}</td>
              <td class="num"><Gold :copper="k.stake" compact /></td>
              <td class="num">{{ k.bought }}/{{ k.n }}</td>
              <td class="num" :class="{ good: k.share != null && k.share >= k.safe, warn: k.share != null && k.share < k.safe && k.sold > 0 }">{{ k.sold }}/{{ k.bought || 0 }}</td>
              <td class="num"><Gold :copper="k.cost" compact /></td>
              <td class="num"><Gold :copper="k.income" compact /></td>
              <td class="num" :class="{ good: k.profit > 0, warn: k.profit < 0 }"><Gold :copper="k.profit" compact /></td>
            </tr>
          </tbody>
        </table>
        <h3>Echte Tausche aus Peon Ledger</h3>
        <p class="small muted">Im einen Haus gekauft, im anderen verkauft. Ledger merkt sich das Haus ab Version 0.17, ältere Käufe fehlen hier. Den genauen Gewinn mit Gebühren zeigt das Buch in Ledger unter „davon Markttausch“.</p>
        <p v-if="!d.compare.trades.length" class="muted">Noch keine Tausche in den letzten 30 Tagen.</p>
        <table v-else class="tbl">
          <thead><tr><th>Gegenstand</th><th>Richtung</th><th>Verkauft</th><th class="num">Stück</th><th class="num">Einkauf</th><th class="num">Erlös</th><th class="num">Gewinn</th></tr></thead>
          <tbody>
            <tr v-for="r in d.compare.trades" :key="r.key + r.t">
              <td class="click" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)">{{ r.name || r.key }}</td>
              <td class="small">{{ r.dir === 'n' ? `${d.compare.home} → ${d.compare.neutral}` : `${d.compare.neutral} → ${d.compare.home}` }}</td>
              <td class="small">{{ when(r.t) }}</td>
              <td class="num">{{ num(r.qty) }}</td>
              <td class="num"><Gold :copper="r.cost" compact /></td>
              <td class="num"><Gold :copper="r.income" compact /></td>
              <td class="num" :class="{ good: r.profit > 0, warn: r.profit < 0 }"><Gold :copper="r.profit" compact /></td>
            </tr>
          </tbody>
        </table>
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
.own td { opacity: 0.75; }
.click:hover td { background: var(--panel); }
.good { color: var(--good, #60e060); }
.warn { color: var(--warn, #ff7070); }
</style>
