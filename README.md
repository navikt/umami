Umami
=====

Umami er et åpent kildekode produktanalyseverktøy som brukes til å spore og analysere data på Navs nettsider og apper.

---

# Tracking Scripts (Sporings-skript)

Dette repositoriet inneholder tilpassede Umami tracking-skript for ResearchOps-teamet.

## Struktur

```
src/tracker/          # Kildefiler (rediger disse)
  ├── index.js        # Base tracker → sporing.js
  ├── sporing-dev.js  # Dev tracker med hardkodet endpoint
  └── README.md       # Detaljert dokumentasjon

public/sporing/       # Build output (git-ignored)
  ├── sporing.js      # Minifisert base tracker
  ├── sporing-dev.js  # Minifisert dev tracker
  └── (eldre filer)   # Gamle varianter som fases ut
```

## Utvikling

```bash
# Installer avhengigheter
npm install

# Bygg minifiserte skript
npm run build:tracker
```

Se [src/tracker/README.md](src/tracker/README.md) for detaljert dokumentasjon.

---

# Henvendelser om Umami

Du kan sende spørsmål på e-post til [researchops@nav.no](mailto:researchops@nav.no).

## For NAV-ansatte

Se [startumami.ansatt.nav.no](https://startumami.ansatt.nav.no/).

Du kan sende spørsmål i Slackkanalen [#researchops](https://nav-it.slack.com/archives/C02UGFS2J4B), eller på e-post til [researchops@nav.no](mailto:researchops@nav.no)

## erstattet country mmdb
Erstatte maxminddb-filen med en som bare finner land og ikke by
```bash
curl -L https://download.db-ip.com/free/dbip-country-lite-$(date +%Y-%m).mmdb.gz \
  | gunzip -c > dbip-country-lite.mmdb
```