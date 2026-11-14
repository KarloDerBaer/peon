-- Peon_Profession - Routes.lua
-- Routen zum Leveln der Berufe in WoW Forever. Nur Nummern, Namen liefert das Spiel (C_Item, C_Spell, C_Map).
--
-- Grundlage: "Profession Leveling Guide" 2.7.2 von icêheal (MIT-Lizenz, Text unten), einmal umgewandelt mit
-- tools/plg_convert.lua am 14.11.2026. Seitdem von Hand gepflegt (eigene Messungen, /prof messungen).
--
-- Je Beruf (Schluessel = Skill-Linie des Spiels) eine Liste von Schritten:
--   from, to   Stufe von bis
--   n          empfohlene Anzahl Herstellungen fuer den ganzen Schritt (geschaetzt)
--   item       Ergebnis-Gegenstand (itemID), spell = Rezept (Zauber-ID, bei Verzauberungen ohne Gegenstand)
--   mats       Material je Herstellung { itemID, Menge, ... } (nil = nur aus dem Berufsfenster)
--   gather     Sammelberufe und Angeln: was man sammelt (itemIDs), A / H = Gebiete (uiMapID) fuer Allianz / Horde
--
-- MIT License, Copyright (c) 2026 icêheal
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
-- documentation files (the "Software"), to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of
-- the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
-- THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
-- CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

local ADDON_NAME, ns = ...
local R = {}
ns.Routes = R

R[171] = {   -- Alchimie (Forever)
    { from = 1, to = 10, n = 10, spell = 1245246, mats = { 2447, 1, 3371, 1 } },
    { from = 10, to = 55, n = 45, item = 5997, mats = { 765, 1, 2447, 1, 3371, 1 } },
    { from = 55, to = 60, n = 5, item = 3382, spell = 3170, mats = { 2447, 1, 2449, 2, 3371, 1 } },
    { from = 60, to = 100, n = 40, item = 2458, mats = { 2449, 2, 2447, 1, 3371, 1 } },
    { from = 100, to = 135, n = 42, item = 3383, mats = { 785, 1, 2450, 2, 3371, 1 } },
    { from = 135, to = 140, n = 5, spell = 3177, mats = { 3355, 1, 3820, 1, 3372, 1 } },
    { from = 140, to = 155, n = 15, item = 3385, mats = { 785, 1, 3820, 1, 3371, 1 } },
    { from = 155, to = 185 },
    { from = 185, to = 210, n = 25, item = 8949, mats = { 3820, 1, 3821, 1, 3372, 1 } },
    { from = 210, to = 215, n = 10, item = 8951, spell = 17554, mats = { 3355, 1, 3821, 1, 3372, 1 } },
    { from = 215, to = 230 },
    { from = 230, to = 231, n = 1, item = 9149, spell = 11459, mats = { 3575, 4, 9262, 1, 8831, 4, 4625, 4 } },
    { from = 231, to = 250, n = 19, item = 9154, mats = { 8836, 1, 8925, 1 } },
    { from = 250, to = 265, n = 15, item = 9187, mats = { 8838, 1, 3821, 1, 8925, 1 } },
    { from = 265, to = 285, n = 20, item = 13443, mats = { 8838, 2, 8839, 2, 8925, 1 } },
    { from = 285, to = 300 },
}
R[164] = {   -- Schmiedekunst (Forever)
    { from = 1, to = 30, n = 40, item = 2862, mats = { 2835, 1 } },
    { from = 30, to = 55, n = 40, item = 3470, mats = { 2835, 2 } },
    { from = 55, to = 85, n = 32, item = 2857, mats = { 2840, 10 } },
    { from = 85, to = 90, n = 6, item = 2854, mats = { 2840, 10, 3470, 3 } },
    { from = 90, to = 125, n = 40, item = 2865, mats = { 2841, 6 } },
    { from = 125, to = 150, n = 27, spell = 9985 },
    { from = 150, to = 155, n = 5, item = 11128, mats = { 3577, 1, 3478, 2 } },
    { from = 155, to = 165, n = 10, item = 3842, mats = { 3575, 8, 3486, 1, 2605, 1 } },
    { from = 165, to = 190, n = 25, item = 3835, mats = { 3575, 6, 2605, 1 } },
    { from = 190, to = 200, n = 10, item = 6040, mats = { 3859, 5, 3486, 2 } },
    { from = 200, to = 210, n = 30, item = 7966, mats = { 7912, 4 } },
    { from = 210, to = 225, n = 15, item = 7919, mats = { 3860, 6, 4338, 4 } },
    { from = 225, to = 235, n = 10, item = 7922, mats = { 3859, 14, 7966, 1 } },
    { from = 235, to = 250, n = 15, item = 7931, mats = { 3860, 10, 4338, 6 } },
    { from = 250, to = 260, n = 20, item = 12404, mats = { 12365, 1 } },
    { from = 260, to = 270, n = 10, item = 12406, mats = { 12359, 12, 11186, 4 } },
    { from = 270, to = 275, n = 5, item = 12408, mats = { 12359, 12, 11184, 4 } },
    { from = 275, to = 290, n = 15, item = 12425, mats = { 12359, 20, 7910, 1 } },
    { from = 290, to = 300, n = 10, item = 12409, mats = { 12359, 20, 8170, 8, 11185, 4 } },
}
R[333] = {   -- Verzauberkunst (Forever)
    { from = 1, to = 24, n = 26, spell = 7418, mats = { 247786, 1 } },
    { from = 24, to = 90, n = 68, spell = 7428, mats = { 10938, 1 } },
    { from = 90, to = 110, n = 22, spell = 7771, mats = { 10940, 2 } },
    { from = 110, to = 120, n = 14, spell = 7748, mats = { 10940, 1, 10938, 1 } },
    { from = 120, to = 130, n = 12, spell = 7788, mats = { 10940, 1, 10938, 1, 10978, 1 } },
    { from = 130, to = 150, n = 28, spell = 7745, mats = { 10940, 1, 10978, 1 } },
    { from = 150, to = 155, n = 6, spell = 7861, mats = { 6371, 1, 10998, 1 } },
    { from = 155, to = 170, n = 19, spell = 13501, mats = { 11083, 1 } },
    { from = 170, to = 185, n = 19, spell = 13607, mats = { 11082, 1 } },
    { from = 185, to = 200, n = 19, spell = 13642, mats = { 11134, 1 } },
    { from = 200, to = 205, n = 6, spell = 13661, mats = { 11137, 1 } },
    { from = 205, to = 225, n = 28, spell = 13663, mats = { 11134, 1 } },
    { from = 225, to = 230, n = 6, spell = 13746, mats = { 11137, 1 } },
    { from = 230, to = 250, n = 28, spell = 13822, mats = { 11174, 1 } },
    { from = 250, to = 255, n = 6, spell = 13917, mats = { 11175, 1 } },
    { from = 255, to = 285, n = 54, spell = 13935, mats = { 11175, 1 } },
    { from = 285, to = 297, n = 36, spell = 13943, mats = { 11178, 1, 11175, 1 } },
    { from = 297, to = 300, n = 4, spell = 20024, mats = { 16203, 2, 16202, 1 } },
}
R[202] = {   -- Ingenieurskunst (Classic)
    { from = 1, to = 30, n = 60, item = 4357, mats = { 2835, 1 } },
    { from = 30, to = 50, n = 30, item = 4359, mats = { 2840, 1 } },
    { from = 50, to = 51, n = 1, item = 6219, mats = { 2840, 6 } },
    { from = 51, to = 75, n = 30, item = 4360, mats = { 2840, 1, 4359, 1, 4357, 2, 2589, 1 } },
    { from = 75, to = 90, n = 60, item = 4364, mats = { 2836, 1 } },
    { from = 90, to = 100, n = 20, item = 4365, mats = { 4364, 3, 2589, 1 } },
    { from = 100, to = 105, n = 5, item = 4404, mats = { 2842, 1 } },
    { from = 105, to = 125, n = 25, item = 4371, mats = { 2841, 2, 2880, 1 } },
    { from = 125, to = 135, n = 10, item = 4406, mats = { 4371, 1, 1206, 1 } },
    { from = 135, to = 140, n = 30, item = 4377, mats = { 2838, 1 } },
    { from = 140, to = 150, n = 15, item = 4375, mats = { 2841, 2, 2592, 1 } },
    { from = 150, to = 160, n = 15, item = 4382, mats = { 2841, 2, 2319, 1, 2592, 1 } },
    { from = 160, to = 175, n = 15, item = 4384, mats = { 4382, 1, 4375, 1, 4377, 2, 2592, 2 } },
    { from = 175, to = 176, n = 1, item = 10498, mats = { 3859, 4 } },
    { from = 176, to = 195, n = 60, item = 10505, mats = { 7912, 2 } },
    { from = 195, to = 200, n = 7, item = 10559, mats = { 3860, 3 } },
    { from = 200, to = 215, n = 20, item = 10560, mats = { 3860, 1, 4338, 1, 10505, 1 } },
    { from = 215, to = 238, n = 40, item = 10561, mats = { 3860, 3 } },
    { from = 238, to = 250, n = 20, item = 10562, mats = { 10561, 2, 10560, 1, 10505, 2 } },
    { from = 250, to = 260, n = 30, item = 15992, mats = { 12365, 2 } },
    { from = 260, to = 285, n = 35, item = 15994, mats = { 12359, 3, 14047, 1 } },
    { from = 285, to = 300, n = 15, item = 15997, mats = { 12359, 2, 15992, 1 } },
}
R[165] = {   -- Lederverarbeitung (Forever)
    { from = 1, to = 30, n = 30, item = 2318, mats = { 2934, 3 } },
    { from = 30, to = 45, n = 18, item = 2304, mats = { 2318, 1 } },
    { from = 45, to = 55, n = 10, item = 4231, mats = { 783, 1, 4289, 1 } },
    { from = 55, to = 85, n = 30, item = 4239, mats = { 2318, 3, 2320, 2 } },
    { from = 85, to = 100, n = 15, item = 4246, mats = { 2318, 6, 2320, 2 } },
    { from = 100, to = 120, n = 22, item = 4249, mats = { 4246, 1, 4233, 1, 2321, 2, 4340, 1 } },
    { from = 120, to = 125, n = 5, item = 4251, mats = { 2319, 4, 4233, 1, 2321, 1 } },
    { from = 125, to = 134, n = 12, item = 4234, mats = { 2319, 5 } },
    { from = 134, to = 137, n = 4, item = 4236, mats = { 4235, 1, 4289, 3 } },
    { from = 137, to = 150, n = 15, item = 4265, mats = { 4234, 5, 2320, 1 } },
    { from = 150, to = 190, n = 42, item = 5964, mats = { 4234, 8, 4236, 1, 2321, 2 } },
    { from = 190, to = 200, n = 10, item = 5966, mats = { 4234, 4, 4236, 1, 4291, 1 } },
    { from = 200, to = 220, n = 20, item = 8173, mats = { 4304, 5, 4291, 1 } },
    { from = 220, to = 230, n = 11, item = 8176, mats = { 4304, 5, 4291, 2 } },
    { from = 230, to = 250, n = 20, item = 8193, mats = { 4304, 14, 4291, 4 } },
    { from = 250, to = 260, n = 12, item = 15564, mats = { 8170, 5 } },
    { from = 260, to = 290, n = 32, item = 15083, mats = { 8170, 8, 2325, 1, 14341, 1 } },
    { from = 290, to = 300, n = 10, item = 15086, mats = { 8170, 12, 2325, 1, 14341, 1 } },
}
R[197] = {   -- Schneidern (Forever)
    { from = 1, to = 45, n = 95, item = 2996, mats = { 2589, 2 } },
    { from = 45, to = 60, n = 17, item = 7026, mats = { 2996, 1, 2320, 1 } },
    { from = 60, to = 70, n = 12, item = 2997, mats = { 2592, 3 } },
    { from = 70, to = 85, n = 18, item = 2584, mats = { 2997, 1, 2321, 1 } },
    { from = 85, to = 125, n = 45, item = 4314, mats = { 2997, 3, 2321, 2 } },
    { from = 125, to = 160, n = 40, item = 4245 },
    { from = 160, to = 170, n = 10, item = 7050, mats = { 4305, 3, 2321, 2 } },
    { from = 170, to = 175, n = 5, item = 4334, mats = { 4305, 3, 2321, 1, 2324, 2 } },
    { from = 175, to = 185, n = 100, item = 4339, mats = { 4338, 5 } },
    { from = 185, to = 205, n = 20, item = 7058, mats = { 4305, 4, 2321, 2, 2604, 2 } },
    { from = 205, to = 215, n = 10, item = 7062, mats = { 4305, 4, 4291, 2, 2604, 2 } },
    { from = 215, to = 220, n = 5, item = 10056, mats = { 4339, 1, 8343, 1, 6261, 1 } },
    { from = 220, to = 230, n = 10, item = 10003, mats = { 4339, 2, 8343, 2 } },
    { from = 230, to = 250, n = 25, item = 10024, mats = { 4339, 3, 8343, 2 } },
    { from = 250, to = 260, n = 155, item = 14048, mats = { 14047, 5 } },
    { from = 260, to = 280, n = 25, item = 13856, mats = { 14048, 3, 14341, 1 } },
    { from = 280, to = 300, n = 20, item = 13863, mats = { 14048, 4, 8170, 4, 14341, 1 } },
}
R[185] = {   -- Kochkunst (Forever)
    { from = 1, to = 50, n = 52, item = 6290, mats = { 6291, 1 } },
    { from = 50, to = 110, n = 70, item = 4592, mats = { 6289, 1 } },
    { from = 110, to = 150, n = 45, item = 4593, mats = { 6308, 1 } },
    { from = 150, to = 175, n = 65, item = 4593, mats = { 6308, 1 } },
    { from = 175, to = 225, n = 55, item = 8364, mats = { 8365, 1 } },
    { from = 225, to = 275, n = 70, item = 6887, mats = { 4603, 1 } },
    { from = 275, to = 300, n = 25, item = 13934, mats = { 13893, 1, 2692, 1, 3713, 1 } },
}
R[129] = {   -- Erste Hilfe (Forever)
    { from = 1, to = 40, n = 45, item = 1251, mats = { 2589, 1 } },
    { from = 40, to = 80, n = 45, item = 2581, mats = { 2589, 2 } },
    { from = 80, to = 115, n = 40, item = 3530, mats = { 2592, 1 } },
    { from = 115, to = 150, n = 40, item = 3531, mats = { 2592, 2 } },
    { from = 150, to = 180, n = 35, item = 6450, mats = { 4306, 1 } },
    { from = 180, to = 210, n = 35, item = 6451, mats = { 4306, 2 } },
    { from = 210, to = 240, n = 35, item = 8544, mats = { 4338, 1 } },
    { from = 240, to = 260, n = 25, item = 8545, mats = { 4338, 2 } },
    { from = 260, to = 290, n = 35, item = 14529, mats = { 14047, 1 } },
    { from = 290, to = 300, n = 10, item = 14530, mats = { 14047, 2 } },
}
R[186] = {   -- Bergbau (Forever)
    { from = 1, to = 65, gather = { 2770 }, A = { 1429, 1426, 1436, 1432 }, H = { 1411, 1412, 1420, 1413 } },
    { from = 65, to = 125, gather = { 2771, 2775 }, A = { 1440, 1437 }, H = { 1440, 1437 } },
    { from = 125, to = 175, gather = { 2772, 2776 }, A = { 1418, 1445, 1446, 1444, 1427 }, H = { 1418, 1445, 1446, 1444, 1427 } },
    { from = 175, to = 245, gather = { 3858, 7911, 11370 }, A = { 1444, 1449, 1452, 1447, 1428 }, H = { 1444, 1449, 1452, 1447, 1428 } },
    { from = 245, to = 300, gather = { 10620 }, A = { 1451, 1449, 1452 }, H = { 1451, 1449, 1452 } },
}
R[182] = {   -- Kräuterkunde (Forever)
    { from = 1, to = 25, gather = { 2447, 765 }, A = { 1429, 1426, 1438 }, H = { 1411, 1412, 1420 } },
    { from = 25, to = 50, gather = { 2449 }, A = { 1429, 1426, 1436, 1432 }, H = { 1411, 1412, 1420, 1413 } },
    { from = 50, to = 100, gather = { 785, 2450, 3820 }, A = { 1436, 1432, 1439 }, H = { 1413, 1421 } },
    { from = 100, to = 150, gather = { 2453, 3355, 3369, 3356 }, A = { 1433, 1437, 1431, 1440 }, H = { 1413, 1442, 1424, 1440 } },
    { from = 150, to = 205, gather = { 3357, 3818, 3821, 3358, 3819 }, A = { 1417, 1434, 1445, 1435, 1416 }, H = { 1417, 1434, 1445, 1435, 1416 } },
    { from = 205, to = 250, gather = { 4625, 8831, 8836, 8838, 8839, 8845 }, A = { 1427, 1418, 1446, 1444, 1425, 1448 }, H = { 1427, 1418, 1446, 1444, 1425, 1448 } },
    { from = 250, to = 300, gather = { 8846, 13464, 13463, 13465, 13466, 13467 }, A = { 1449, 1448, 1447, 1423, 1422, 1452, 1451 }, H = { 1449, 1448, 1447, 1423, 1422, 1452, 1451 } },
}
R[393] = {   -- Kürschnerei (Classic)
    { from = 1, to = 100, gather = { 2318 }, A = { 1429, 1438 }, H = { 1412 } },
    { from = 100, to = 165, gather = { 2319, 2318 }, A = { 1442, 1437 }, H = { 1434, 1417 } },
    { from = 165, to = 225, gather = { 4234, 4304 }, A = { 1446, 1444 }, H = { 1446, 1444, 1448 } },
    { from = 225, to = 300, gather = { 8170 }, A = { 1449, 1423, 1452 }, H = { 1449, 1423, 1452 } },
}
R[356] = {   -- Angeln (Forever)
    { from = 1, to = 75, A = { 1429, 1426, 1438 }, H = { 1411, 1412, 1413 } },
    { from = 75, to = 150, A = { 1453, 1455, 1457, 1436, 1432, 1439 }, H = { 1454, 1458, 1456, 1413, 1421 } },
    { from = 150, to = 225, A = { 1445, 1417, 1443, 1434, 1435, 1441, 1416 }, H = { 1445, 1417, 1443, 1434, 1435, 1441, 1416 } },
    { from = 225, to = 300, A = { 1446, 1444, 1452, 1448, 1425, 1449, 1422 }, H = { 1446, 1444, 1452, 1448, 1425, 1449, 1422 } },
}

-- Forever-Rezepte der Routen: Stufe zum Lernen, Quelle (t Lehrer, v Haendler, d Beute, q Quest, m Muster)
ns.Learn = {
    [3170] = { skill = 15, src = "t" },
    [3177] = { skill = 130, src = "t" },
    [7418] = { skill = 20, src = "t" },
    [7428] = { skill = 24, src = "t" },
    [7745] = { skill = 100, src = "t" },
    [7748] = { skill = 60, src = "t" },
    [7771] = { skill = 70, src = "t" },
    [7861] = { skill = 125, src = "t" },
    [11459] = { skill = 225, src = "v" },
    [13501] = { skill = 130, src = "t" },
    [13607] = { skill = 145, src = "t" },
    [13642] = { skill = 165, src = "t" },
    [13661] = { skill = 180, src = "t" },
    [13663] = { skill = 185, src = "t" },
    [13746] = { skill = 205, src = "t" },
    [13822] = { skill = 210, src = "t" },
    [13917] = { skill = 230, src = "t" },
    [17554] = { skill = 265, src = "t" },
    [1245246] = { skill = 10, src = "t" },
}
