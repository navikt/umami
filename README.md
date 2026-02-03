Umami
=====

Umami er et åpent kildekode produktanalyseverktøy som brukes til å spore og analysere data på Navs nettsider og apper.

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