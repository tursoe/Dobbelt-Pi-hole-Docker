# Dobbelt Pi-hole med Docker

[English](README.md) | **Dansk**

Dockerpakke til [Dobbelt Pi-hole](https://github.com/tursoe/Dobbelt-Pi-hole).
Én container leverer kontrolpanelet og Chart.js gennem nginx og videresender
APIkald til to, tre eller fire Pi-hole v6 installationer. Der er ingen
applikationsbackend eller database.

Første udgave bruger **v1.3.007** fra den faste kildekodeversion
`64b536ae5d47fec0a6fbe54a70d69626f1a3b03e` samt Chart.js **4.4.1**.
Filerne hentes, når imaget bygges. De hentes ikke ved containerens opstart.
Kontrolpanelets kildekode bliver i det oprindelige repository.

## Første lokale bygning

Kræver Docker Engine med Compose eller Docker Desktop.
Denne første udgave bygges lokalt. Et færdigt image er endnu ikke offentliggjort.

1. Hent filerne fra dette repository, eller klon det:

   ```bash
   git clone https://github.com/tursoe/Dobbelt-Pi-hole-Docker.git
   cd Dobbelt-Pi-hole-Docker
   ```

2. Ret `compose.yml`. Sæt `PIHOLE_1_URL` og `PIHOLE_2_URL` til dine APIadresser,
   og vælg standardnavne.
3. Byg og start:

   ```bash
   docker compose up -d --build
   ```

4. Åbn `http://DIN-DOCKER-SERVER:8080`, og log ind med hver Pi-holes app password.

Der skal være internetadgang under bygningen. Den kørende container behøver kun
adgang til dine Pi-hole installationer. Adgangskoder skal ikke stå i Compose.

## Opsætning

| Variabel | Betydning |
| --- | --- |
| `PIHOLE_COUNT` | `2`, `3` eller `4`. Standard er `2` |
| `PIHOLE_1_URL` … `PIHOLE_4_URL` | HTTP(S) adresse med valgfri afsluttende `/api` til hver aktiv installation |
| `PIHOLE_1_NAME` … `PIHOLE_4_NAME` | Standardnavne. Standard er `Pi-hole 1` osv. |
| `PIHOLE_1_VERIFY_TLS` … `PIHOLE_4_VERIFY_TLS` | Kontrollér HTTPS-certifikater. Standard er `true` |

Eksempler: `http://192.168.1.10/api`, `http://192.168.1.10:8081/api`,
`https://pihole.example.com/api` eller `http://[fd00::10]/api`.
Adressen skal pege direkte på APIet, da redirects afvises. Bruger en installation
HTTPS med et selvsigneret certifikat, skal certifikatet være betroet, eller
`PIHOLE_N_VERIFY_TLS: "false"` angives udtrykkeligt for den installation.

Ved tre eller fire installationer øges `PIHOLE_COUNT`, og de tilhørende adresser
og navne aktiveres ved at fjerne kommentartegnene. Anvend ændringer i Compose med:

```bash
docker compose up -d
```

Ved opstart dannes nginxruter og kontrolpanelets standardnavne automatisk.
Navne, der allerede er gemt i browseren, overstyrer standardnavnene i den browser.
Denne udgave bruger miljøvariabler i Compose og har ingen separat `config.json`.
Filerne i hovedprojektet ændres ikke.

## Porte og netværk

Standard er port `8080` på værten til port `8080` i containeren. Skift venstre
side for at bruge en anden port på værten, eksempelvis `"8090:8080"`.

Pi-hole adresserne skal kunne nås fra containeren. `localhost` og `127.0.0.1`
peger på dashboardcontaineren selv. Brug Pi-holens lokale netværksadresse eller
et containernavn på et fælles Dockernetværk. Kører Pi-hole på samme vært, skal
dens offentliggjorte port bruges i adressen.

Et værtsnavn eller servicenavn skal kunne slås op, når dashboardcontaineren
starter. Ellers fejler `nginx -t`, og containeren stopper. Det kan ske, hvis en
anden container endnu ikke er startet eller tilsluttet det fælles netværk.
Start den tjeneste først, eller brug en tilgængelig lokal netværksadresse.

Containeren leverer HTTP. Brug din eksisterende HTTPS reverse proxy til en
krypteret browserforbindelse. Skal kun en reverse proxy på Dockerværten have
adgang, kan porttilknytningen ændres til `"127.0.0.1:8080:8080"`.

nginx komprimerer HTML samt egnede CSS-, JavaScript- og JSONsvar på mindst
1024 byte, når klienten understøtter gzip. HTTPS-certifikatkontrollen bruger
`proxy_ssl_verify_depth 3` til at understøtte længere certifikatkæder.

## Egen sprogfil

Montér en eksisterende lokal `language.js` oven på den medfølgende fil. Tilføj
dette på samme niveau som `environment` i tjenesten `dashboard`:

```yaml
    volumes:
      - ./language.js:/opt/dashboard/language.js:ro
```

Opstartsscriptet kopierer den monterede fil til den midlertidige webmappe.
Når filen ændres, køres `docker compose restart dashboard`, og browserfanen
genindlæses. Tilføjelse eller ændring af selve monteringen anvendes med
`docker compose up -d`. Filen skal eksistere før opstart og kunne læses af
containerens bruger 101. Se `language.template.js` i hovedprojektet for formatet.

## Drift

```bash
docker compose ps
docker compose logs --tail=100 dashboard
docker compose down
```

Sundhedskontrollen viser kun, om nginx svarer. Den kontrollerer ikke login eller
forbindelsen til Pi-hole. Der kræves intet permanent volumen. Indstillinger og
sessioner ligger i browseren som i hovedprojektet. En genstart ændrer ikke
Pi-hole opsætningen eller DNSdriften.

nginx kører uden rootrettigheder. Compose bruger et skrivebeskyttet filsystem
med midlertidige filer i `/tmp`. Et lille opstartsscript bruger jq til at
kontrollere opsætningen og kode navne sikkert. Der er ingen kørende Python-,
Node.js- eller PHPtjeneste.

## Færdigt billede

GitHub Actions bygger billedet til `linux/amd64` og `linux/arm64` og udgiver det i GitHub
Container Registry som `ghcr.io/tursoe/dobbelt-pi-hole`, mærket `latest` og med versionen,
fx `1.3.007-1`. Billedet bygges igen hver mandag, så opdateringer til nginx og Alpine følger
med. Før hver udgivelse starter workflowen billedet med samme hærdning som i `compose.yml`
ved siden af en falsk Pi-hole og kører `tests/smoke.sh`.

For at bruge det erstattes linjerne `build` og `image` i `compose.yml` med:

```yaml
    image: ghcr.io/tursoe/dobbelt-pi-hole:latest
```

Kør derefter:

```bash
docker compose pull
docker compose up -d
```

Vil du bruge en fast version i stedet for `latest`, angives et versionstag, fx
`ghcr.io/tursoe/dobbelt-pi-hole:1.3.007-1`.

## Versioner og opdatering

Versionstagget er dashboardets version efterfulgt af Docker-pakkens revision, fx `1.3.007-1`.
Dashboardet er fastlåst til en kildecommit med `DASHBOARD_REF` i Dockerfile, så en ny
dashboardversion kræver, at værdien gennemses og ændres, at versionsmærket i Dockerfile
rettes, og at ændringen committes. Workflowen udgiver derefter det nye billede.

## Licens

MIT. Se [LICENSE](LICENSE). Kontrolpanelets MIT-licens og Chart.js' MIT-licens
ligger i imaget under `/opt/dashboard/LICENSE` og `/opt/dashboard/Chart.js.LICENSE`.
