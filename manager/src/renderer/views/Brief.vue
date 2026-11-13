<script setup>
// Steckbrief (ab Manager 0.35.0, Peon_Manager_Chancen.md 6.1 Stufe 3): Diagramm, Rechenweg, Haltbarkeit,
// Raster nach Tageszeit, Feste und die Pruefliste jeder Art. Erreichbar aus Chancen, Marktuebersicht und Gegenstand.
import { ref, watch, onMounted, computed } from 'vue';
import BriefChart from '../components/BriefChart.vue';
import ChecksList from '../components/ChecksList.vue';
import WhyNot from '../components/WhyNot.vue';
import Gold from '../components/Gold.vue';
import { qualityColor, itemName, when, num, shortMoney } from '../util.js';

const props = defineProps({ market: Object, itemKey: String, now: Number, stamp: Number, theme: String });
const emit = defineEmits(['open', 'loaded']);
const b = ref(null);
const days = ref(14);
async function load() {
  if (!props.market || !props.itemKey) return;
  b.value = await window.peon.brief(props.market.key, props.itemKey, days.value);
  if (b.value) emit('loaded', { name: b.value.name, quality: b.value.quality });
}
onMounted(load);
watch(() => [props.market && props.market.key, props.itemKey, props.stamp, days.value], load);
const SURE = { low: 'niedrig', mid: 'mittel', high: 'hoch' };
const WD = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const gridMax = computed(() => (b.value ? Math.max(0, ...b.value.week.grid.flat().filter((x) => x != null)) : 0));
const gridMin = computed(() => (b.value ? Math.min(Infinity, ...b.value.week.grid.flat().filter((x) => x != null)) : 0));
const shade = (v) => (v == null || gridMax.value <= gridMin.value ? 'transparent' : `color-mix(in srgb, var(--accent) ${Math.round(10 + 70 * (v - gridMin.value) / (gridMax.value - gridMin.value))}%, transparent)`);
const lifeTotal = computed(() => (b.value ? b.value.life.reduce((a, x) => a + x.qty, 0) : 0));
const lifeLabel = (g) => (g.to === 0 ? 'unter 1 Std.' : g.from >= 24 ? 'über 1 Tag' : `${g.from} bis ${g.to + 1} Std.`);
</script>

<template>
  <div class="brief" v-if="b">
    <div class="head">
      <h1 :style="{ color: qualityColor(b.quality) }">{{ itemName(b) }}</h1>
      <span class="small muted">Steckbrief<template v-if="b.t">, Stand {{ when(b.t) }}</template></span>
      <span class="grow"></span>
      <select v-model.number="days" aria-label="Zeitraum"><option :value="7">7 Tage</option><option :value="14">14 Tage</option><option :value="30">30 Tage</option></select>
      <button class="link" @click="emit('open', itemKey)">Gegenstand</button>
    </div>

    <BriefChart :brief="b" :theme="theme" />

    <div class="cols">
      <section class="box">
        <h3>Rechenweg</h3>
        <p v-if="b.best && b.best.ok" class="small muted">{{ b.best.kindLabel }}: {{ b.best.say }}</p>
        <ul v-if="b.steps.length" class="steps"><li v-for="s in b.steps" :key="s">{{ s }}</li></ul>
        <p v-else class="small muted">Gerade nichts zu rechnen.</p>
        <div class="kv small">
          <span>Belegter Verkaufspreis</span><span><template v-if="b.proof"><Gold :copper="b.proof.median" /> aus {{ num(b.proof.n) }} Verkäufen</template><template v-else>noch keine Verkäufe gesehen</template></span>
          <span>Absatz</span><span>{{ b.sales14 ? `${Math.round(b.sales14.perDay * 10) / 10} am Tag`.replace('.', ',') : 'unbekannt' }}</span>
          <span>Üblicher Bereich</span><span><template v-if="b.band"><Gold :copper="b.band.low" compact /> bis <Gold :copper="b.band.high" compact /></template><template v-else>–</template></span>
        </div>
      </section>

      <section class="box">
        <h3>Haltbarkeit</h3>
        <p class="small muted">Wie lange verkaufte Angebote im Markt standen, bevor sie jemand kaufte (letzte 14 Tage).</p>
        <p v-if="b.hold">Angebote unter 80 % des belegten Preises: meist <strong>{{ b.hold.hours < 1 ? 'unter 1 Std.' : `etwa ${Math.round(b.hold.hours)} Std.` }}</strong><template v-if="b.hold.hours < 1">, nur live erreichbar</template>.</p>
        <div v-if="lifeTotal" class="life">
          <div v-for="g in b.life" :key="g.from" class="lrow"><span>{{ lifeLabel(g) }}</span><span class="bar"><i :style="{ width: (g.qty / lifeTotal * 100) + '%' }"></i></span><span class="num">{{ Math.round(g.qty / lifeTotal * 100) }} %</span></div>
        </div>
        <p v-else class="small muted">Noch keine Verkäufe mit bekannter Standzeit.</p>
      </section>

      <section class="box">
        <h3>Prognose</h3>
        <template v-if="b.forecast">
          <p><strong :class="b.forecast.dir > 0 ? 'up' : 'down'">{{ b.forecast.dir > 0 ? 'Steigt' : 'Fällt' }}</strong> in {{ b.forecast.days }} Tagen um etwa {{ Math.round(b.forecast.expect * 100) }} %, Sicherheit {{ SURE[b.forecast.sure] }}.</p>
          <ChecksList :checks="[]" :signals="b.forecast.signals" />
        </template>
        <p v-else class="small muted">Keine Prognose.</p>
        <h3 class="mt">Feste</h3>
        <p v-if="!b.fests.length" class="small muted">Keine Feste bekannt. Sie kommen aus dem Kalender im Spiel.</p>
        <div v-for="f in b.fests" :key="f.n + f.s" class="small">{{ f.n }}: {{ new Date(f.s * 1000).toLocaleDateString('de-DE') }}<template v-if="f.e && f.e !== f.s"> bis {{ new Date(f.e * 1000).toLocaleDateString('de-DE') }}</template><span v-if="f.own" class="faint"> (eigenes)</span></div>
      </section>
    </div>

    <section class="box">
      <h3>Nach Wochentag und Tageszeit</h3>
      <p class="small muted">Mittel der Angebote über 4 Wochen je 3 Stunden.<template v-if="b.week.signal"> Am günstigsten {{ WD[b.week.signal.lo] }}, am teuersten {{ WD[b.week.signal.hi] }} ({{ Math.round(b.week.signal.gap * 100) }} % Abstand, in {{ b.week.signal.same }} von {{ b.week.signal.weeks }} Wochen gleich).</template><template v-else> Kein festes Muster.</template></p>
      <table class="grid">
        <thead><tr><th></th><th v-for="s in 8" :key="s">{{ (s - 1) * 3 }}</th></tr></thead>
        <tbody>
          <tr v-for="(row, i) in b.week.grid" :key="i">
            <th>{{ WD[i] }}</th>
            <td v-for="(v, j) in row" :key="j" :style="{ background: shade(v) }" :title="v == null ? 'keine Daten' : shortMoney(v)">{{ v == null ? '' : shortMoney(v) }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <section class="box">
      <h3>Prüfliste</h3>
      <WhyNot :market="market.key" :item-key="itemKey" :stamp="stamp" />
    </section>
  </div>
  <p v-else class="muted">Lade Steckbrief</p>
</template>

<style scoped>
.brief { display: grid; gap: 16px; max-width: 1180px; align-content: start; }
.head { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }
.head h1 { margin: 0; }
.grow { flex: 1; }
.cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 14px; }
.box { border: 1px solid var(--line-soft); border-radius: var(--radius-m); padding: 12px 16px; display: grid; gap: 8px; background: var(--raised); align-content: start; }
.box h3 { margin: 0; }
.mt { margin-top: 8px !important; }
.steps { margin: 0; padding-left: 18px; }
.kv { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; }
.kv span:nth-child(odd) { color: var(--muted); }
.life { display: grid; gap: 4px; }
.lrow { display: grid; grid-template-columns: 110px 1fr 50px; gap: 8px; align-items: center; font-size: 13px; }
.bar { height: 8px; background: var(--line-soft); border-radius: 4px; overflow: hidden; }
.bar i { display: block; height: 100%; background: var(--accent); }
.num { text-align: right; }
.up { color: var(--up); }
.down { color: var(--bad); }
.grid { border-collapse: collapse; font-size: 12px; }
.grid th { color: var(--muted); font-weight: 500; padding: 3px 8px; }
.grid td { padding: 4px 8px; min-width: 56px; text-align: center; border: 1px solid var(--line-soft); }
</style>
