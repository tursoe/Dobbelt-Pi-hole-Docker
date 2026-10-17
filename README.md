# Double Pi-hole Docker

**English** | [Dansk](README.DA.md)

Docker packaging for the [Double Pi-hole dashboard](https://github.com/tursoe/Dobbelt-Pi-hole).
One container serves the dashboard and Chart.js through nginx and proxies requests
to two, three or four Pi-hole v6 instances. There is no application backend or database.

This first package uses dashboard **v1.3.007**, pinned to source commit
`64b536ae5d47fec0a6fbe54a70d69626f1a3b03e`, and Chart.js **4.4.1**.
The lastest version is **v1.4.008** from `f9d67854eb9df0a5cf084da7291c65b3f11eccf3`
The dashboard files are downloaded when the image is built. No files are downloaded
when the container starts. The dashboard source stays in the original repository.

## First local build

Requires Docker Engine with the Compose plugin, or Docker Desktop.
This initial version builds locally; a prebuilt registry image has not been published.

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

Internet access is required while building the image. The running dashboard only
needs access to your Pi-hole instances. No Pi-hole passwords belong in Compose.

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
See `language.template.js` in the main project for the language-pack format.

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
version, for example `1.3.007-1`. The image is rebuilt every Monday to pick up updates to the
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
`ghcr.io/tursoe/dobbelt-pi-hole:1.3.007-1`.

## Versions and updates

The version tag is the dashboard version followed by the Docker packaging revision, for
example `1.3.007-1`. The dashboard is pinned to a source commit by `DASHBOARD_REF` in the
Dockerfile, so a new dashboard version requires reviewing and changing that value, updating
the version label in the Dockerfile and committing. The workflow then publishes the new
image.

## License

MIT; see [LICENSE](LICENSE). The original dashboard's MIT license and Chart.js's
MIT license are included in the image under `/opt/dashboard/LICENSE` and
`/opt/dashboard/Chart.js.LICENSE`.
