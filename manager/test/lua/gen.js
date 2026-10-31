// Zufallsfaelle fuer compare.lua erzeugen und mit sales.compare vergleichen
const { compare } = require('../../src/core/sales');
const { execFileSync } = require('node:child_process');
let seed = 11; const rnd = (n) => { seed = (seed * 16807) % 2147483647; return seed % n; };
const cases = [];
for (let k = 0; k < 3000; k++) {
  const tA = 1000000, tB = tA + [60, 600, 3600, 7200, 20000, 50000, 86400][rnd(7)];
  const withIds = rnd(3) === 0, commodity = rnd(2) === 0, cap = rnd(4) === 0 ? 100 + rnd(50) : 0;
  const A = [];
  for (let i = 0, n = 1 + rnd(8); i < n; i++) {
    const band = 1 + rnd(4), B = { 1: [0, 1800], 2: [1800, 7200], 3: [7200, 43200], 4: [43200, 172800] }[band];
    const secs = withIds && rnd(2) ? 60 + rnd(90000) : null;
    A.push({ id: withIds ? 100 + i : 0, q: [1, 1, 5, 10, 20][rnd(5)], p: 90 + rnd(70), lo: secs ? tA + secs : tA + B[0], hi: secs ? tA + secs : tA + B[1] });
  }
  A.sort((a, b) => a.p - b.p || a.id - b.id);
  const Bl = [];
  for (const a of A) {
    const r = rnd(5);
    if (r <= 1) Bl.push({ ...a });                                   // steht noch
    else if (r === 2 && a.q > 1) Bl.push({ ...a, q: a.q - 1 - rnd(a.q - 1) });   // Teilkauf
    // sonst weg
  }
  for (let i = 0, n = rnd(3); i < n; i++) Bl.push({ id: withIds ? 500 + i : 0, q: [1, 5, 10][rnd(3)], p: 80 + rnd(70), lo: tB + 40000, hi: tB + 170000 });
  Bl.sort((a, b) => a.p - b.p || a.id - b.id);
  cases.push({ tA, tB, withIds, commodity, cap, A, B: Bl });
}
const enc = (l) => l.map((o) => `${o.id},${o.q},${o.p},${o.lo},${o.hi}`).join(' ');
const input = cases.map((c) => `${c.tA} ${c.tB} ${c.commodity ? 1 : 0} ${c.withIds ? 1 : 0} ${c.cap} 0.1|${enc(c.A)}|${enc(c.B)}`).join('\n') + '\n';
const out = execFileSync(process.argv[2], [__dirname + '/compare.lua', process.argv[3]], { input }).toString().trim().split(/\r?\n/);   // Lua unter Windows schreibt \r\n
let bad = 0;
cases.forEach((c, i) => {
  const r = compare(c.A.map((x) => ({ ...x })), c.B.map((x) => ({ ...x })), c.tA, c.tB, { commodity: c.commodity, withIds: c.withIds, cap: c.cap, cancelPct: 0.1 });
  const js = `${r.sold.toFixed(4)} ${r.expired.toFixed(4)} ${r.cancelled.toFixed(4)}`;
  if (js !== out[i]) { if (bad < 5) console.log('ABWEICHUNG', i, js, out[i], JSON.stringify(c)); bad++; }
});
const nz = out.filter((l) => l.split(" ").some((x) => Number(x) > 0)).length;
console.log(`${cases.length} Faelle (${nz} mit Verkauf, Ablauf oder Abbruch), ${bad} Abweichungen`);
process.exit(bad ? 1 : 0);
