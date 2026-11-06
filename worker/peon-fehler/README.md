# Peon Fehlerberichte (Cloudflare Worker)

Der Peon Manager schickt Fehler und Rückmeldungen an diesen Worker. Der Worker legt je Eintrag ein Issue in einem privaten GitHub-Repo an. Nutzer brauchen weder Konto noch Token, der GitHub-Token liegt nur bei Cloudflare.

Ablauf: Manager → `POST /bericht` → Prüfung von Format, Größe und Anzahl → je Eintrag ein Issue → Bestätigung der angelegten Einträge → der Manager löscht genau diese.

Der Worker läuft unter `https://peon-fehler.karloderbaer.workers.dev`. Ohne eingetragene Adresse bleibt der Knopf „Alles senden“ gesperrt.

## Einmalig einrichten (KarloDerBaer)

1. **Privates Repo anlegen:** auf GitHub ein neues privates Repo `peon-fehler`. Bei einem anderen Namen `GITHUB_REPO` in `wrangler.toml` anpassen.
2. **Labels anlegen:** `fehler`, `verbesserung`, `idee`, `sonstiges`.
3. **Token erstellen:** GitHub, Settings, Developer settings, Personal access tokens, Fine-grained tokens. Nur dieses eine Repo auswählen, Berechtigung „Issues: Read and write“.
4. **Cloudflare-Konto anlegen:** auf cloudflare.com, die Gratis-Stufe reicht.
5. **Worker hochladen:** in diesem Ordner nacheinander ausführen. Den Token gibst du beim zweiten Befehl ein, er kommt nicht ins Repo.

   ```bash
   npx wrangler login
   ```

   ```bash
   npx wrangler secret put GITHUB_TOKEN
   ```

   ```bash
   npx wrangler deploy
   ```

6. **Subdomain prüfen:** Cloudflare bildet die Adresse aus dem Konto und kann dabei den echten Namen verwenden. Dann die Subdomain im Dashboard unter Workers & Pages ändern, bevor die Adresse ins Repo kommt.
7. **Adresse eintragen:** Der letzte Befehl nennt die Adresse des Workers. In `manager/src/core/reports.js` die Konstante `REPORT_URL` auf `<Adresse>/bericht` setzen und den Manager neu bauen. Zum Ausprobieren ohne Neubau geht auch die Umgebungsvariable `PEON_MANAGER_REPORT_URL`.

## Berichte lesen

```bash
gh issue list --repo KarloDerBaer/peon-fehler
```

## Schutz gegen Missbrauch

Die Adresse steht im öffentlichen Repo, der Worker ist also für jeden erreichbar. Deshalb gilt:

- Es werden nur Berichte im erwarteten Format angenommen, höchstens 64 KB und 20 Einträge je Sendung, Addon-Namen nur `Peon` oder `Peon_...`.
- Höchstens 5 Sendungen je Stunde und Adresse und 30 je Stunde insgesamt. Die Zähler gelten je Rechenzentrum von Cloudflare, sie sind also eine Bremse und keine harte Grenze.
- Fehlertexte stehen im Issue in Codeblöcken, damit sie weder das Issue verändern noch jemanden benachrichtigen.
- Der Token darf nur Issues dieses einen Repos schreiben. Wird der Worker doch zugemüllt, reicht es, den Token zu löschen.
- Die IP-Adresse wird nur als Prüfsumme für die Zähler verwendet und nach einer Stunde verworfen.

## Tests

Die Tests liegen bei denen des Managers: `manager/test/reports.test.js` (`npm test` im Ordner `manager`).
