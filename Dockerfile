# syntax=docker/dockerfile:1

# Hent en fast udgave af hovedprojektet, mens imaget bygges.
FROM alpine:3 AS assets
RUN apk add --no-cache curl ca-certificates
ARG DASHBOARD_REF=9e1404990df350cff461f00e10cfd4ef714d40ff
WORKDIR /assets
RUN set -eu; \
    for file in index.html language.js LICENSE; do \
        curl --fail --location --retry 3 \
          "https://raw.githubusercontent.com/tursoe/Dobbelt-Pi-hole/${DASHBOARD_REF}/${file}" \
          --output "${file}"; \
    done; \
    curl --fail --location --retry 3 \
      https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js \
      --output chart.umd.min.js; \
    echo '81ffafe13c37e1b25793b020d446f4d9739b949dadb7f9f79d709a0cad781c2f  chart.umd.min.js' | sha256sum -c -; \
    curl --fail --location --retry 3 \
      https://raw.githubusercontent.com/chartjs/Chart.js/v4.4.1/LICENSE.md \
      --output Chart.js.LICENSE

# nginx betjener siden. jq bruges kun til sikker behandling af opsætningen.
FROM nginx:alpine
RUN apk add --no-cache jq ca-certificates
COPY --from=assets /assets/ /opt/dashboard/
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
RUN chmod 0555 /opt/docker-entrypoint.sh

LABEL org.opencontainers.image.title="Double Pi-hole Docker" \
      org.opencontainers.image.source="https://github.com/tursoe/Dobbelt-Pi-hole-Docker" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.4.010-1"

# Alt genereret indhold er midlertidigt. Ingen adgangskoder gemmes her.
USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["/opt/docker-entrypoint.sh"]
