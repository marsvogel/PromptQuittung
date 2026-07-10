# PromptQuittung

**Eine Quittung für jeden KI-Prompt.**

Wer mit [Cursor](https://cursor.com) programmiert, stellt ständig Anfragen an eine KI — und jede davon kostet Geld. Wie viel, sieht man normalerweise erst später im Dashboard auf der Cursor-Webseite.

PromptQuittung macht das sichtbar, und zwar sofort: Die App läuft still in der Menüleiste des Macs und zeigt nach jeder KI-Anfrage eine kleine Mitteilung an — mit dem Preis und der Menge der verbrauchten Tokens. Wie ein Kassenbon, direkt nach dem Einkauf.

So behält man im Alltag ein Gefühl dafür, was die einzelnen Anfragen wirklich kosten.

## Was die App macht

- Sie läuft unauffällig als kleines Symbol in der Menüleiste.
- Sie schaut einmal pro Minute nach, ob es neue Cursor-Anfragen gab.
- Für jede neue Anfrage erscheint eine Mitteilung: **Betrag · Modell · Tokens**.
- Es ist keine Einrichtung nötig — die App nutzt die bestehende Anmeldung der installierten Cursor-App. Es muss nichts eingegeben werden, kein Passwort, kein Schlüssel.

## Ausprobieren

Voraussetzungen: ein Mac mit macOS 15 oder neuer und die installierte Cursor-App (eingeloggt).

1. Unter [Releases](../../releases) (oder bei den Build-Artefakten unter [Actions](../../actions)) das ZIP herunterladen.
2. ZIP entpacken und `PromptQuittung.app` in den Ordner *Programme* ziehen.
3. Beim ersten Start: **Rechtsklick auf die App → Öffnen**. Das ist nötig, weil die App nicht signiert ist — macOS fragt einmal nach, danach startet sie normal.
4. Mitteilungen erlauben, wenn macOS danach fragt.

Danach erscheint das Glocken-Symbol in der Menüleiste, und die Quittungen kommen von selbst.

## Selbst bauen

Das Projekt in Xcode öffnen (`PromptQuittung.xcodeproj`) und starten — mehr ist nicht nötig.

## Datenschutz

Die App liest die Anmeldung der Cursor-App lokal vom eigenen Rechner und fragt damit die Nutzungsdaten direkt bei cursor.com ab — so, wie es das Cursor-Dashboard im Browser auch tut. Es werden keine Daten an andere Stellen geschickt oder gespeichert.
