# Double Pi-hole Docker

**English** | [Dansk](README.DA.md)

Docker packaging for the [Double Pi-hole dashboard](https://github.com/tursoe/Dobbelt-Pi-hole).
One container serves the dashboard and Chart.js through nginx and proxies requests
to two, three or four Pi-hole v6 instances. There is no application backend or database.

This package is prepared for dashboard **v1.5.011** and Chart.js **4.4.1**.
`DASHBOARD_REF` in the Dockerfile still contains the previous source commit.
Replace it with the final v1.5.011 commit after uploading the main dashboard,
before building this Docker image locally.
The Docker image version is **1.5.011-1**.
The dashboard, language template, icons and web manifest are downloaded when the image is built. No files are downloaded
when the container starts. The dashboard source stays in the original repository.

## Dashboard v1.5.012

Updated to v1.5.012

## Dashboard v1.5.011

This release adds Overview for comparing instance configuration, group management
and memberships, local CNAME records, Teleporter backup downloads, a sequential
Gravity queue, network device cleanup and a configurable start tab. Group controls
are hidden automatically when only the default group is used. Client activity
charts show every client series supplied by the Pi-hole API.

## Local build

Requires Docker Engine with the Compose plugin, or Docker Desktop.
The supplied Compose file builds locally. See **Prebuilt image** below to use the registry image.

1. Download this repository, or clone it:

   ```bash
   git clone https://github.com/tursoe/Dobbelt-Pi-hole-Docker.git
   cd Dobbelt-Pi-hole-Docker
   ```

2. Edit `compose.yml`. Replace `PIHOLE_1_URL` and `PIHOLE_2_URL` with the addresses
   of your Pi-hole APIs. Set your preferred display names.
3. Build and start:

   ```bash
   docker compose up -d --build
   ```

4. Open `http://YOUR-DOCKER-HOST:8080` and log in with each Pi-hole's app password.

Internet access is required while building the image and for update checks.
The dashboard remains usable with local Pi-hole instances when internet access is unavailable.
No Pi-hole passwords belong in Compose.

## Configuration

| Variable | Meaning |
| --- | --- |
| `PIHOLE_COUNT` | `2`, `3` or `4`; defaults to `2` |
| `PIHOLE_1_URL` … `PIHOLE_4_URL` | HTTP(S) origin, optionally ending in `/api`, for each active instance |
| `PIHOLE_1_NAME` … `PIHOLE_4_NAME` | Default display names; defaults to `Pi-hole 1` etc. |
| `PIHOLE_1_VERIFY_TLS` … `PIHOLE_4_VERIFY_TLS` | Verify HTTPS certificates; `true` by default |

Examples: `http://192.168.1.10/api`, `http://192.168.1.10:8081/api`,
`https://pihole.example.com/api` or `http://[fd00::10]/api`.
Addresses must point directly to the API; redirects are rejected. An HTTPS instance
with a self-signed certificate needs a trusted certificate or an explicit
`PIHOLE_N_VERIFY_TLS: "false"` for that instance.

For three or four instances, increase `PIHOLE_COUNT` and uncomment the corresponding
URL and name entries. After editing Compose, apply changes with:

```bash
docker compose up -d
```

The container regenerates its nginx routes and dashboard defaults at every startup.
Existing names saved in the browser override the defaults for that browser.
The configuration is provided through Compose; there is no separate config.json
in this first version. The main dashboard's source files are not modified.

## Ports and networks

The default mapping is host port `8080` to container port `8080`. To use another
host port, change the left side, for example `"8090:8080"`.

Pi-hole addresses must be reachable from the container. `localhost` and `127.0.0.1`
refer to the dashboard container itself. Use the Pi-hole host's LAN address, or
a container/service name on a shared Docker network. If your Pi-hole runs on the
same host, use its published port in the URL.

A host or service name must resolve when the dashboard container starts.
Otherwise `nginx -t` fails and the container stops. This can happen if another
container has not started or has not joined the shared network yet. Start that
service first, or use a reachable LAN address.

The container serves HTTP. Use your existing HTTPS reverse proxy for encrypted
browser access. To publish only to a reverse proxy on the Docker host, change
the port mapping to `"127.0.0.1:8080:8080"`.

nginx compresses HTML and eligible CSS, JavaScript and JSON responses of at least
1024 bytes when the client supports gzip. HTTPS certificate verification uses
`proxy_ssl_verify_depth 3` to support longer certificate chains.

## Your own language file

Mount an existing local `language.js` over the bundled file. Add this at the
same level as `environment` in the `dashboard` service:

```yaml
    volumes:
      - ./language.js:/opt/dashboard/language.js:ro
```

The startup script copies the mounted file to the temporary web directory.
After changing the file, run `docker compose restart dashboard` and reload the
browser tab. To add or change the mount itself, use `docker compose up -d`.
The file must exist before startup and be readable by container user 101.
The complete `language.template.js` is included in the image and can be downloaded
through Settings. Existing valid v1.4.010 language packs remain supported; missing
new messages fall back to English. The v1.5.011 template contains 368 message keys.

## Operation

```bash
docker compose ps
docker compose logs --tail=100 dashboard
docker compose down
```

The health check tests whether nginx responds; it does not test Pi-hole login or
reachability. The dashboard has no persistent volume: preferences and sessions
remain in the browser as in the original project. Restarting the container does
not change the Pi-hole configuration or DNS operation.

nginx runs without root privileges. The supplied Compose file uses a read-only
filesystem with temporary generated files in `/tmp`. A small startup shell script
uses jq to validate configuration and encode display names safely. jq is a startup
utility; there is no Python, Node.js or PHP application service.

## Prebuilt image

GitHub Actions builds the image for `linux/amd64` and `linux/arm64` and publishes it to
GitHub Container Registry as `ghcr.io/tursoe/dobbelt-pi-hole`, tagged `latest` and with the
version, for example `1.5.011-1`. The image is rebuilt every Monday to pick up updates to the
nginx and Alpine base images. Before each publication, the workflow starts the image with
the hardening from `compose.yml` next to a fake Pi-hole and runs `tests/smoke.sh`.

To use it, replace the `build` and `image` lines in `compose.yml` with:

```yaml
    image: ghcr.io/tursoe/dobbelt-pi-hole:latest
```

Then run:

```bash
docker compose pull
docker compose up -d
```

To use a fixed version instead of `latest`, give the image a version tag, for example
`ghcr.io/tursoe/dobbelt-pi-hole:1.5.011-1`.

## Versions and updates

The version tag is the dashboard version followed by the Docker packaging revision, for
example `1.5.011-1`. `DASHBOARD_REF` in the Dockerfile selects the source commit.
The old commit is retained until the main dashboard release is uploaded.

1. Upload the final v1.5.011 files to the main dashboard repository.
2. Set `DASHBOARD_REF` to that commit's full hash in your local Dockerfile.
3. Build and test locally in Docker Desktop with `docker compose up -d --build`.
4. Upload the tested Docker changes. GitHub Actions then builds, smoke-tests and
   publishes the image.

The build downloads every file in the dashboard release package, plus `LICENSE`
and Chart.js with its license. The startup script copies all of them to the web
directory; only the runtime HTML copy receives Docker configuration changes.


## Dashboard update check

The startup script sets `DOCKER_INSTALLATION = true` only in the container's
runtime copy of `index.html`. The original dashboard download remains unchanged.
The browser makes one update-check attempt per tab session, including failed attempts.
Opening Settings again or reloading the page reuses that result. A newer dashboard
version adds a red dot to Settings. That page shows the version, a link to releases
and the following commands to run in the directory containing your `compose.yml`:

```bash
docker compose pull
docker compose up -d
```

These commands apply to the prebuilt image. For a local build, update the repository
and run `docker compose up -d --build` instead.

nginx proxies `/versioncheck/` to the main project's `version.js` on GitHub over
verified HTTPS. Browser credentials and incoming request headers are not forwarded.
DNS is resolved when a check is requested using the container's configured DNS,
so GitHub being unreachable does not prevent nginx from starting. A failed check
does not affect the local dashboard or Pi-hole APIs.

This compares the bundled dashboard's `APP_VERSION` with the published dashboard
version. It does not detect image rebuilds that keep the same dashboard version,
and it does not install updates. Use `docker compose pull` and
`docker compose up -d` when using the prebuilt image, or
`docker compose up -d --build` after updating this repository when building locally.

## License

MIT; see [LICENSE](LICENSE). The original dashboard's MIT license and Chart.js's
MIT license are included in the image under `/opt/dashboard/LICENSE` and
`/opt/dashboard/Chart.js.LICENSE`.
