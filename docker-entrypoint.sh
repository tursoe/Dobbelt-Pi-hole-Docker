#!/bin/sh
set -eu

# Opsætningen dannes ved hver opstart. Miljøvariabler bliver ikke evalueret som kode.
fail() {
    printf 'Opsætningsfejl: %s\n' "$1" >&2
    exit 1
}

PIHOLE_COUNT=${PIHOLE_COUNT:-2}
case "$PIHOLE_COUNT" in
    2|3|4) ;;
    *) fail 'PIHOLE_COUNT skal være 2, 3 eller 4.' ;;
esac

# De to stier kan overskrives til lokale konfigurationstests uden Docker.
asset_dir=${DASHBOARD_ASSET_DIR:-/opt/dashboard}
runtime_dir=${DASHBOARD_RUNTIME_DIR:-/tmp/dobbelt-pi-hole}
mkdir -p "$runtime_dir/web" "$runtime_dir/client_temp" "$runtime_dir/proxy_temp"
for file in index.html language.js chart.umd.min.js; do
    [ -r "$asset_dir/$file" ] || fail "Filen $file mangler i imaget."
    cp "$asset_dir/$file" "$runtime_dir/web/$file"
done

# Opret browserens standardnavne som JSON, så citater og specialtegn bevares.
servers='[]'
for index in 1 2 3 4; do
    name=$(printenv "PIHOLE_${index}_NAME" || true)
    name=${name:-Pi-hole $index}
    servers=$(printf '%s' "$servers" | jq -c --arg id "$index" --arg name "$name" \
      '. + [{id: $id, label: $name, base: ("/api" + $id), color: ("c-" + $id), chip: ("s" + $id)}]')
done
# Et navn må ikke kunne lukke HTML-filens scriptblok.
printf '%s' "$servers" | jq -r 'tojson | gsub("<"; "\\u003c") | gsub(">"; "\\u003e") | gsub("&"; "\\u0026")' > "$runtime_dir/servers.json"

# Udskift kun de to kendte opsætningsfelter i kopien af HTML-filen.
awk -v count="$PIHOLE_COUNT" -v config="$runtime_dir/servers.json" '
    /const DEFAULT_SERVER_COUNT[[:space:]]*=/ {
        counts += sub(/const DEFAULT_SERVER_COUNT[[:space:]]*=[[:space:]]*[234];/, "const DEFAULT_SERVER_COUNT = " count ";")
    }
    /const DEFAULT_SERVERS[[:space:]]*=/ {
        if ((getline servers < config) <= 0) exit 1
        print "\t\t\tconst DEFAULT_SERVERS = " servers ";"
        replacing = 1
        arrays++
        if ($0 ~ /\];/) replacing = 0
        next
    }
    replacing { if ($0 ~ /\];/) replacing = 0; next }
    { print }
    END { if (counts != 1 || arrays != 1 || replacing) exit 1 }
' "$asset_dir/index.html" > "$runtime_dir/web/index.html" || fail 'HTML-filens opsætningsfelter kunne ikke genkendes.'

cat > "$runtime_dir/nginx.conf" <<EOF
worker_processes auto;
pid $runtime_dir/nginx.pid;
error_log /dev/stderr warn;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    gzip on;
    gzip_min_length 1024;
    gzip_types text/css text/javascript application/javascript application/json;
    access_log /dev/stdout;
    client_body_temp_path $runtime_dir/client_temp;
    proxy_temp_path $runtime_dir/proxy_temp;
    fastcgi_temp_path $runtime_dir/fastcgi_temp;
    uwsgi_temp_path $runtime_dir/uwsgi_temp;
    scgi_temp_path $runtime_dir/scgi_temp;
    server {
        listen 8080;
        server_name _;
        root $runtime_dir/web;
        index index.html;
        autoindex off;
        client_max_body_size 1m;
        add_header Cache-Control "no-store" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header Referrer-Policy "same-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self';" always;
        location = /healthz { access_log off; default_type text/plain; return 200 "ok\\n"; }
EOF

index=1
while [ "$index" -le "$PIHOLE_COUNT" ]; do
    url=$(printenv "PIHOLE_${index}_URL" || true)
    [ -n "$url" ] || fail "PIHOLE_${index}_URL mangler."
    # Kun en HTTP(S)-adresse med eventuel port og /api accepteres. Dermed kan
    # miljøvariablerne ikke indsætte ekstra nginx-direktiver eller logindata.
    parsed=$(jq -cen --arg url "$url" '
      $url | capture("^(?<scheme>https?)://(?<host>\\[[0-9A-Fa-f:]+\\]|[A-Za-z0-9_][A-Za-z0-9_.-]*)(?::(?<port>[0-9]{1,5}))?(?:/api)?/?$")
      | select(.port == null or ((.port | tonumber) >= 1 and (.port | tonumber) <= 65535))
    ') || fail "PIHOLE_${index}_URL skal fx være http://192.168.1.10/api."
    scheme=$(printf '%s' "$parsed" | jq -r .scheme)
    host=$(printf '%s' "$parsed" | jq -r .host)
    authority=$(printf '%s' "$parsed" | jq -r '.host + (if .port then ":" + .port else "" end)')
    verify=$(printenv "PIHOLE_${index}_VERIFY_TLS" || true)
    verify=${verify:-true}
    case "$verify" in
        true) verify=on ;;
        false) verify=off ;;
        *) fail "PIHOLE_${index}_VERIFY_TLS skal være true eller false." ;;
    esac
    cat >> "$runtime_dir/nginx.conf" <<EOF
        location /api$index/ {
            proxy_pass $scheme://$authority/api/;
            proxy_http_version 1.1;
            proxy_set_header Host $authority;
            proxy_set_header Connection "";
            proxy_set_header Cookie "";
            proxy_set_header Authorization "";
            proxy_ssl_server_name on;
            proxy_ssl_verify $verify;
            proxy_ssl_verify_depth 3;
            proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
            proxy_connect_timeout 10s;
            proxy_read_timeout 300s;
            proxy_buffering off;
        }
EOF
    index=$((index + 1))
done
cat >> "$runtime_dir/nginx.conf" <<'EOF'
        location / { try_files $uri $uri/ =404; }
        location ~ /\. { deny all; }
    }
}
EOF

# Kontroltilstanden skriver kun opsætningen og bruges til lokale tests.
if [ "${1:-}" = '--check-config' ]; then
    printf 'Opsætning oprettet til %s Pi-hole-installationer.\n' "$PIHOLE_COUNT"
    exit 0
fi
nginx -t -c "$runtime_dir/nginx.conf"
exec nginx -c "$runtime_dir/nginx.conf" -g 'daemon off;'
