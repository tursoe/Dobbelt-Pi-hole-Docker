# Dobbelt Pi-hole med Docker

[English](README.md) | **Dansk**

Dockerpakke til [Dobbelt Pi-hole](https://github.com/tursoe/Dobbelt-Pi-hole).
Én container leverer kontrolpanelet og Chart.js gennem nginx og videresender
APIkald til to, tre eller fire Pi-hole v6 installationer. Der er ingen
applikationsbackend eller database.

Denne pakke er forberedt til kontrolpanelet **v1.5.011** og Chart.js **4.4.1**.
`DASHBOARD_REF` i Dockerfile indeholder stadig den tidligere kildecommit.
Udskift den med hashen for den endelige v1.5.011, når hovedprojektet er opdateret,
før Docker-imaget bygges lokalt.
Docker imagets version er **1.5.011-1**.
Kontrolpanelet, sprogskabelonen, ikonerne og webmanifestet hentes, når imaget bygges. De hentes ikke ved containerens opstart.
Kontrolpanelets kildekode bliver i det oprindelige repository.

## Kontrolpanel v1.5.011

Denne udgave tilføjer Overblik til sammenligning af instansernes opsætning,
grupper og gruppetilknytninger, lokale CNAME-poster, Teleporter-backup,
sekventiel Gravity-kø, oprydning i netværksenheder og valgfri startfane.
Gruppefelter skjules automatisk, når kun standardgruppen bruges.
Graferne for klientaktivitet viser alle klientserier fra Pi-hole APIet.

## Lokal bygning

Kræver Docker Engine med Compose eller Docker Desktop.
Den medfølgende Compose fil bygger lokalt. Se **Færdigt billede** nedenfor for at bruge det offentliggjorte image.

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

Der skal være internetadgang under bygningen og ved versionstjek. Kontrolpanelet
fungerer stadig med lokale Pi-hole installationer uden internetadgang.
Adgangskoder skal ikke stå i Compose.

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
containerens bruger 101. Den komplette `language.template.js` er med i imaget
og kan hentes under Indstillinger. Gyldige sprogpakker til v1.4.010 understøttes
fortsat; manglende nye tekster vises på engelsk. Skabelonen til v1.5.011 har 368 nøgler.

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
fx `1.5.011-1`. Billedet bygges igen hver mandag, så opdateringer til nginx og Alpine følger
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
`ghcr.io/tursoe/dobbelt-pi-hole:1.5.011-1`.

## Versioner og opdatering

Versionstagget er dashboardets version efterfulgt af Docker-pakkens revision, fx `1.5.011-1`.
`DASHBOARD_REF` i Dockerfile vælger kildecommitten. Den gamle hash bevares,
indtil hovedprojektet er opdateret.

1. Upload de endelige v1.5.011-filer til hovedprojektet.
2. Sæt `DASHBOARD_REF` til den nye commits fulde hash i din lokale Dockerfile.
3. Byg og test lokalt i Docker Desktop med `docker compose up -d --build`.
4. Upload de testede Docker-ændringer. GitHub Actions bygger, tester og udgiver
   derefter imaget.

Bygningen henter alle filer fra kontrolpanelets udgivelsespakke samt `LICENSE`
og Chart.js med tilhørende licens. Opstartsscriptet kopierer dem alle til
webmappen. Kun den midlertidige HTML-kopi får Docker-opsætningen indsat.


## Kontrol af nye kontrolpanelversioner

Opstartsscriptet sætter kun `DOCKER_INSTALLATION = true` i containerens
midlertidige kopi af `index.html`. Hovedprojektets almindelige download ændres ikke.
Browseren foretager ét forsøg på versionstjek pr. fanesession, også ved fejl.
Et nyt besøg i Indstillinger eller genindlæsning bruger det gemte resultat.
En nyere kontrolpanelversion vises med en rød prik på Indstillinger. På siden
vises versionen, et link til udgivelserne og disse kommandoer, der skal køres
i mappen med din `compose.yml`:

```bash
docker compose pull
docker compose up -d
```

Kommandoerne gælder det færdige image. Ved lokal bygning opdateres repositoryet,
og derefter køres `docker compose up -d --build`.

nginx videresender `/versioncheck/` til hovedprojektets `version.js` på GitHub via
HTTPS med certifikatkontrol. Browserens legitimationsoplysninger og indgående
request headers videresendes ikke. DNS opslaget udføres først ved et versionstjek
med containerens konfigurerede DNS. Utilgængelig GitHub forhindrer derfor ikke
nginx i at starte. Et mislykket tjek påvirker ikke kontrolpanelet eller Pi-hole APIerne.

Kontrollen sammenligner det medfølgende kontrolpanels `APP_VERSION` med den
udgivne kontrolpanelversion. Den opdager ikke nye Docker builds med samme
kontrolpanelversion og installerer ikke opdateringer. Ved brug af det færdige image
køres `docker compose pull` og `docker compose up -d`. Ved lokal bygning opdateres
først dette repository, hvorefter `docker compose up -d --build` køres.

## Licens

MIT. Se [LICENSE](LICENSE). Kontrolpanelets MIT-licens og Chart.js' MIT-licens
ligger i imaget under `/opt/dashboard/LICENSE` og `/opt/dashboard/Chart.js.LICENSE`.
