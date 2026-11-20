<script setup>
// Beobachten (ab 0.32.0, Angleichung A4, Konzept docs/konzepte/manager/Peon_Manager_Angleichung.md 4.1 und 4.3).
// Dieselbe Beobachtung wie im Spiel unter Beobachten: je Gegenstand Kaufen bis (Betrag oder % unter dem ueblichen Preis)
// und Zielpreis, Rat wie im Spiel. Die Glocken je Grenze gelten nur hier im Manager (Meldung von Windows).
// Ab 0.51.0 (KarloDerBaer 20.11.2026) Unterreiter wie in Broker: Aufkauf, Schnellkauf (Kaufen bis und Limit pro Kauf) und
// Markttausch (beide Haeuser aus dem Marktvergleich). Ein Gegenstand steht in jeder Liste, deren Haken an ist.
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import Gold from '../components/Gold.vue';
import SyncPanel from '../components/SyncPanel.vue';
import MoneyInput from '../components/MoneyInput.vue';
import { ago, when, fold, qualityColor, itemName } from '../util.js';
import { loadFavorites } from '../store.js';

const props = defineProps({ market: Object, stamp: Number, settings: Object, now: Number, focus: Object });
const emit = defineEmits(['open', 'save', 'go']);
const api = window.peon;

const view = ref(null);
const accts = ref({ list: [], selected: null });
const addText = ref('');
const catalog = ref([]);
const flash = ref(null);
const TABS = [{ key: 'buyout', label: 'Aufkauf' }, { key: 'quick', label: 'Schnellkauf' }, { key: 'trade', label: 'Markttausch' }];
const tab = ref((props.settings && props.settings.watchTab) || 'buyout');
watch(tab, (t) => emit('save', { watchTab: t }));
const tabRows = computed(() => (view.value ? view.value.rows.filter((r) => r.lists && r.lists[tab.value]) : []));
const tabCount = (k) => (view.value ? view.value.rows.filter((r) => r.lists && r.lists[k]).length : 0);
async function setQuick(r, qlim, qgold) { await api.watchSetQuick(r.key, qlim ?? null, qgold ?? 0); await load(); }
async function offList(r) { await api.watchSetList(r.key, tab.value, false); await loadFavorites(); await load(); }
const dirText = (d) => (!view.value || !view.value.pair ? '' : d === 'n' ? `${view.value.pair.home} → ${view.value.pair.neutral}` : `${view.value.pair.neutral} → ${view.value.pair.home}`);

async function load() {
  const [v, a] = await Promise.all([api.watchView(props.market ? props.market.key : ''), api.accounts()]);
  view.value = v;
  accts.value = a;
}
onMounted(load);
watch(() => [props.market && props.market.key, props.stamp], load);

// Klick auf eine Meldung: Zeile zeigen und kurz hervorheben
watch(() => props.focus, async (f) => {
  if (!f || !f.key) return;
  await load();
  flash.value = f.key;
  await nextTick();
  const el = document.querySelector(`[data-watch-key="${CSS.escape(f.key)}"]`);
  if (el) el.scrollIntoView({ block: 'center' });
  setTimeout(() => { if (flash.value === f.key) flash.value = null; }, 2500);
}, { immediate: true });

// Konto (nur bei mehreren Konten)
const acctLabel = (a) => a.name || a.folder || a.id;
async function selectAcct(id) { await api.accountSelect(id); await load(); }

// Eingaben: Betraege in Kupfer aus MoneyInput (ab 0.34.0 Gold, Silber, Kupfer wie im Spiel), Prozent als ganze Zahl
const inGold = (c) => (c == null ? '' : String(Math.round(c) / 10000).replace('.', ','));

async function setBuyAbs(r, copper) { await api.watchSetBuy(r.key, copper ? 'abs' : null, copper); await load(); }
async function setBuyPct(r, text) {
  const p = Math.round(parseFloat(String(text).replace(',', '.')));
  await api.watchSetBuy(r.key, Number.isFinite(p) ? 'pct' : null, Number.isFinite(p) ? Math.max(0, Math.min(90, p)) : null);
  await load();
}
async function setKind(r, kind) {
  // Umschalten zwischen Gold und %: den bisherigen Wert umrechnen, wenn das geht
  if (kind === 'pct') {
    const p = r.buyLimit != null && r.ref ? Math.max(0, Math.min(90, Math.round((1 - r.buyLimit / r.ref) * 100))) : 10;
    await api.watchSetBuy(r.key, 'pct', p);
  } else {
    await api.watchSetBuy(r.key, r.buyLimit != null ? 'abs' : null, r.buyLimit);
  }
  await load();
}
async function setUp(r, copper) { await api.watchSetUp(r.key, copper); await load(); }
async function bell(r, which) { await api.watchSetBell(r.key, which, !r.bells[which]); await load(); }

// Hinzufuegen ueber den Namen: Vorschlaege aus der Gegenstandsliste des Markts
async function loadCatalog() {
  if (catalog.value.length || !props.market) return;
  const r = await api.items(props.market.key);
  catalog.value = r.items.map((x) => ({ key: x.key, name: itemName(x), quality: x.quality, folded: fold(itemName(x)) }));
}
watch(() => props.market && props.market.key, () => { catalog.value = []; });
const suggestions = computed(() => {
  const q = fold(addText.value.trim());
  if (q.length < 2 || !view.value) return [];
  return catalog.value.filter((x) => x.folded.includes(q) && !view.value.rows.some((r) => r.key === x.key)).slice(0, 8);
});
async function add(s) {
  await api.watchSetList(s.key, tab.value, true);   // ab 0.51.0 in die Liste des offenen Unterreiters
  addText.value = '';
  await loadFavorites();
  await load();
}

const ADVICE = { buy: 'KAUFEN', sell: 'VERKAUFEN' };
const waitText = computed(() => (view.value && view.value.running ? 'wartet auf /reload' : 'beim nächsten Anmelden'));
const bandTip = (b) => (b ? `Üblich ${Math.round(b.low / 100) / 100} bis ${Math.round(b.high / 100) / 100} Gold${b.unsure ? ', schwankt stark' : ''}` : 'Noch kein üblicher Bereich');
</script>

<template>
  <div class="watch" v-if="view">
    <div class="head">
      <h1>Beobachten</h1>
      <div class="tools">
        <label v-if="accts.list.length > 1" class="small acct">Konto
          <select :value="accts.selected" @change="selectAcct($event.target.value)">
            <option v-for="a in accts.list" :key="a.id" :value="a.id">{{ acctLabel(a) }}</option>
          </select>
        </label>
        <label class="check small"><input type="checkbox" :checked="settings.watchNotify" @change="emit('save', { watchNotify: $event.target.checked })" /> Meldungen von Windows (Glocken je Grenze)</label>
      </div>
    </div>

    <div class="tabs" role="tablist">
      <button v-for="t in TABS" :key="t.key" role="tab" :aria-selected="tab === t.key" :class="{ on: tab === t.key }" @click="tab = t.key">
        {{ t.label }}<span class="cnt" v-if="tabCount(t.key)">{{ tabCount(t.key) }}</span>
      </button>
    </div>

    <div class="add">
      <input type="text" v-model="addText" placeholder="Gegenstand beobachten" aria-label="Gegenstand beobachten" spellcheck="false" @focus="loadCatalog" />
      <div class="sugg" v-if="suggestions.length">
        <button v-for="s in suggestions" :key="s.key" :style="{ color: qualityColor(s.quality) }" @click="add(s)">{{ s.name }}</button>
      </div>
    </div>

    <template v-if="tab === 'quick'">
      <p v-if="!tabRows.length" class="muted">Noch nichts für den Schnellkauf beobachtet. Suche oben nach einem Gegenstand oder speichere im Spiel im Schnellkauf des Fokus.</p>
      <table v-else class="tbl">
        <thead><tr>
          <th>Gegenstand</th>
          <th class="num" title="Günstigstes Angebot im letzten Stand des gewählten Markts">Günstigster</th>
          <th class="num" title="Kaufen bis im Schnellkauf">Kaufen bis</th>
          <th class="num" title="Höchstens so viel Gold je Kauf, leer = ohne Grenze">Limit pro Kauf</th>
          <th></th>
        </tr></thead>
        <tbody>
          <tr v-for="r in tabRows" :key="r.key" :data-watch-key="r.key" :class="{ buy: r.quickHit, flash: flash === r.key }">
            <td class="name">
              <span class="click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name || r.key }}</span>
              <span v-if="r.wait" class="wait small" :title="'Änderung ist noch nicht im Spiel'">{{ waitText }}</span>
            </td>
            <td class="num"><Gold :copper="r.price" compact /></td>
            <td class="num"><MoneyInput :value="r.qlim" :label="`Kaufen bis im Schnellkauf für ${r.name || r.key}`" @change="setQuick(r, $event, r.qgold)" /></td>
            <td class="num"><MoneyInput :value="r.qgold || null" :label="`Limit pro Kauf für ${r.name || r.key}`" @change="setQuick(r, r.qlim, $event)" /></td>
            <td class="num"><button class="small" @click="offList(r)">Entfernen</button></td>
          </tr>
        </tbody>
      </table>
      <p class="small muted">Marktbewegung, Treffer und Einbrüche misst Broker im Spiel und zeigt sie dort unter Beobachten, Schnellkauf.</p>
    </template>

    <template v-else-if="tab === 'trade'">
      <p v-if="!tabRows.length" class="muted">Noch nichts für den Markttausch beobachtet. Suche oben nach einem Gegenstand oder wähle im Spiel im Menü eines Gegenstands „Beobachten: Markttausch“.</p>
      <template v-else>
        <p v-if="!view.pair" class="small muted">Noch kein Marktvergleich für diesen Markt. Die Werte kommen, sobald der Manager beide Häuser verglichen hat.</p>
        <table class="tbl">
          <thead><tr>
            <th>Gegenstand</th>
            <th>Bessere Richtung</th>
            <th class="num">{{ view.pair ? view.pair.home : 'Fraktion' }}</th>
            <th class="num">{{ view.pair ? view.pair.neutral : 'Neutral' }}</th>
            <th class="num" title="Gewinn in Prozent des Kaufpreises nach dem Anteil des Zielhauses">Spanne</th>
            <th class="num" title="Verkaufte Stück je Tag im Zielhaus">Absatz Ziel</th>
            <th></th>
          </tr></thead>
          <tbody>
            <tr v-for="r in tabRows" :key="r.key" :data-watch-key="r.key" :class="{ flash: flash === r.key }">
              <td class="name">
                <span class="click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name || r.key }}</span>
                <span v-if="r.wait" class="wait small" :title="'Änderung ist noch nicht im Spiel'">{{ waitText }}</span>
              </td>
              <td class="small">{{ r.cmp ? dirText(r.cmp.dir) : '' }}</td>
              <td class="num"><Gold v-if="r.cmp && r.cmp.hm != null" :copper="r.cmp.hm" compact /><span v-else class="faint">–</span></td>
              <td class="num"><Gold v-if="r.cmp && r.cmp.nm != null" :copper="r.cmp.nm" compact /><span v-else class="faint">–</span></td>
              <td class="num" :class="{ good: r.cmp && r.cmp.pct > 0 }">{{ r.cmp ? (r.cmp.pct > 0 ? '+' : '') + r.cmp.pct + ' %' : '–' }}</td>
              <td class="num">{{ r.cmp ? (r.cmp.dir === 'n' ? r.cmp.sn : r.cmp.sh) ?? '–' : '–' }}</td>
              <td class="num"><button class="small" @click="offList(r)">Entfernen</button></td>
            </tr>
          </tbody>
        </table>
        <p class="small muted">Üblicher günstigster Preis in beiden Häusern und Spanne aus dem Marktvergleich<template v-if="view.pair && !view.pair.cutSure"> (Anteil Neutral {{ Math.round(view.pair.cutN * 100) }} % angenommen)</template>. Den Zustand am Auktionshaus prüft Broker im Spiel.</p>
      </template>
    </template>

    <template v-else>
    <p v-if="!tabRows.length" class="muted">Noch nichts unter Beobachten. Suche oben nach einem Gegenstand, klicke unter <button class="link" @click="emit('go', 'market:items')">Marktübersicht, Markt</button> auf den Stern oder speichere im Spiel im Fokus.</p>
    <table v-else class="tbl">
      <thead>
        <tr>
          <th>Gegenstand</th>
          <th class="num" title="Günstigstes Angebot im letzten Stand des gewählten Markts">Preis</th>
          <th class="num" title="Grenze nach unten: Kaufen, wenn der Preis darauf oder darunter liegt">Kaufen bis</th>
          <th class="num" title="Grenze nach oben: Verkaufen, wenn der Preis darauf oder darüber liegt">Zielpreis</th>
          <th class="num">Üblich</th>
          <th>Rat</th>
          <th class="c" title="Meldung von Windows für Kaufen bis und Zielpreis">Meldung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="r in tabRows" :key="r.key" :data-watch-key="r.key" :class="{ buy: r.advice === 'buy', sell: r.advice === 'sell', flash: flash === r.key }">
          <td class="name">
            <span class="click" tabindex="0" :style="{ color: qualityColor(r.quality) }" @click="emit('open', r.key)" @keydown.enter="emit('open', r.key)">{{ r.name || r.key }}</span>
            <span v-if="r.wait" class="wait small" :title="'Änderung ist noch nicht im Spiel'">{{ waitText }}</span>
          </td>
          <td class="num" :title="view.lastScan ? `Stand ${when(view.lastScan)}, ${ago(view.lastScan, now)}` : 'Noch kein Stand'"><Gold :copper="r.price" compact /></td>
          <td class="num">
            <span class="buy-in">
              <span v-if="r.buy && r.buy.pct != null" class="pct-in">
                <input type="text" inputmode="numeric" :value="r.buy.pct" :title="r.buyLimit != null ? `Das sind gerade ${inGold(r.buyLimit)} Gold` : 'Noch kein üblicher Preis'"
                  :aria-label="`Kaufen bis für ${r.name || r.key} in Prozent`" @change="setBuyPct(r, $event.target.value)" />%
              </span>
              <MoneyInput v-else :value="r.buy ? r.buy.lim : null" :label="`Kaufen bis für ${r.name || r.key}`" @change="setBuyAbs(r, $event)" />
              <select :value="r.buy && r.buy.pct != null ? 'pct' : 'abs'" :aria-label="`Einheit für Kaufen bis bei ${r.name || r.key}`" @change="setKind(r, $event.target.value)">
                <option value="abs">Gold</option>
                <option value="pct">% unter üblich</option>
              </select>
            </span>
          </td>
          <td class="num"><MoneyInput :value="r.up" :label="`Zielpreis für ${r.name || r.key}`" @change="setUp(r, $event)" /></td>
          <td class="num muted" :title="bandTip(r.band)">
            <template v-if="r.band"><Gold :copper="r.band.low" compact /> – <Gold :copper="r.band.high" compact /></template>
            <span v-else class="faint">–</span>
          </td>
          <td class="advice">{{ ADVICE[r.advice] || '' }}</td>
          <td class="c bells">
            <button class="bell" :class="{ on: r.bells.buy }" :disabled="r.buy == null" :aria-pressed="r.bells.buy" :title="r.buy == null ? 'Erst Kaufen bis eintragen' : r.bells.buy ? 'Meldung bei Kaufen bis ist an' : 'Meldung bei Kaufen bis einschalten'" @click="bell(r, 'buy')">🔔<small>▼</small></button>
            <button class="bell" :class="{ on: r.bells.up }" :disabled="r.up == null" :aria-pressed="r.bells.up" :title="r.up == null ? 'Erst einen Zielpreis eintragen' : r.bells.up ? 'Meldung beim Zielpreis ist an' : 'Meldung beim Zielpreis einschalten'" @click="bell(r, 'up')">🔔<small>▲</small></button>
          </td>
          <td class="num"><button class="small" @click="offList(r)">Entfernen</button></td>
        </tr>
      </tbody>
    </table>
    </template>
    <p class="small muted">Preise und Rat gelten für den gewählten Markt. Änderungen hier kommen beim nächsten Laden ins Spiel, Änderungen im Spiel von selbst hierher. Die Glocken gelten nur im Manager, die Warnung im Spiel stellst du dort unter Beobachten ein.</p>

    <SyncPanel area="watch" :stamp="stamp" :now="now" />
  </div>
</template>

<style scoped>
.watch { display: grid; gap: 14px; }
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--line); }
.tabs button { background: none; border: none; border-bottom: 2px solid transparent; border-radius: 0; padding: 8px 14px; color: var(--muted); font-weight: 500; margin-bottom: -1px; }
.tabs button:hover { color: var(--text); }
.tabs button.on { color: var(--text); border-bottom-color: var(--accent); }
.cnt { margin-left: 6px; font-size: 0.85em; color: var(--muted); }
.good { color: var(--good, #60e060); }
.head { display: flex; align-items: baseline; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.head h1 { margin: 0; }
.tools { display: flex; gap: 18px; align-items: center; flex-wrap: wrap; }
.acct select { margin-left: 8px; }
.check { display: flex; gap: 8px; align-items: center; }
.add { position: relative; max-width: 360px; }
.sugg { position: absolute; left: 0; right: 0; top: calc(100% + 4px); z-index: 20; display: grid; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-s); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); }
.sugg button { background: none; border: none; border-radius: 0; text-align: left; padding: 6px 10px; overflow: hidden; text-overflow: ellipsis; }
.sugg button:hover { background: var(--line-soft); }
.tbl { width: 100%; border-collapse: collapse; }
.tbl th { text-align: left; font-weight: 500; color: var(--muted); padding: 6px 8px; border-bottom: 1px solid var(--line); white-space: nowrap; }
.tbl td { padding: 6px 8px; border-bottom: 1px solid var(--line-soft); vertical-align: middle; }
.tbl th.num, .num { text-align: right; white-space: nowrap; }
.c { text-align: center; }
.name { min-width: 160px; }
.click { cursor: pointer; }
.click:hover, .click:focus-visible { text-decoration: underline; }
.wait { display: inline-block; margin-left: 8px; padding: 1px 6px; border: 1px solid var(--warn); border-radius: var(--radius-s); color: var(--warn); }
.buy-in { display: inline-flex; gap: 6px; align-items: center; }
.pct-in { display: inline-flex; align-items: center; gap: 4px; }
.pct-in input { width: 5ch !important; text-align: right; }
.bell { cursor: pointer; }
.bell:disabled { cursor: not-allowed; }
.advice { font-weight: 600; white-space: nowrap; }
tr.buy .advice { color: var(--up); }
tr.sell .advice { color: var(--accent); }
tr.buy td, tr.sell td { background: var(--accent-soft); }
tr.flash td { outline: 2px solid var(--accent); outline-offset: -2px; }
.bells { white-space: nowrap; }
.bell { background: none; border: 1px solid var(--line); border-radius: var(--radius-s); padding: 2px 7px; color: var(--faint); margin: 0 2px; }
.bell.on { color: var(--gold); border-color: var(--gold); }
.bell:not(.on) { filter: grayscale(1); }
.bell small { font-size: 0.7em; margin-left: 2px; }
.bell:disabled { opacity: 0.35; }
</style>
