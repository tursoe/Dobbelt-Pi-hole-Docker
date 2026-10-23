#!/bin/sh
# Start the built image with the same hardening as compose.yml next to a fake
# Pi-hole and check the result. Usage: tests/smoke.sh IMAGE (needs docker and curl)
set -eu
image="${1:?usage: tests/smoke.sh IMAGE}"
dir=$(cd "$(dirname "$0")" && pwd)
id=$$
net="dobbelt-smoke-net-$id"
fake="dobbelt-smoke-fake-$id"
app="dobbelt-smoke-app-$id"
base="http://127.0.0.1:18080"
page=$(mktemp)

cleanup() {
	docker rm -f "$app" "$fake" >/dev/null 2>&1 || true
	docker network rm "$net" >/dev/null 2>&1 || true
	rm -f "$page"
}
trap cleanup EXIT

check() {
	if ! "$@"; then
		echo "FAILED: $*" >&2
		docker logs "$app" >&2 || true
		exit 1
	fi
}

docker network create "$net" >/dev/null
docker run -d --name "$fake" --network "$net" \
	-v "$dir/fake-pihole.conf:/etc/nginx/conf.d/default.conf:ro" nginx:alpine >/dev/null

# 192.0.2.x is reserved for documentation, so nothing real is contacted.
docker run -d --name "$app" --network "$net" -p 18080:8080 \
	--read-only --tmpfs /tmp:rw,noexec,nosuid,size=16m,mode=1777 \
	--cap-drop ALL --security-opt no-new-privileges:true \
	-e PIHOLE_COUNT=3 \
	-e PIHOLE_1_URL="http://$fake" -e PIHOLE_1_NAME="Test 1" \
	-e PIHOLE_2_URL=https://192.0.2.2/api -e PIHOLE_2_VERIFY_TLS=false \
	-e PIHOLE_3_URL=http://192.0.2.3:8081/api \
	"$image" >/dev/null

for _ in $(seq 1 30); do
	curl -fsS "$base/healthz" >/dev/null 2>&1 && break
	sleep 1
done

check sh -c "curl -fsS '$base/healthz' | grep -qx ok"
check sh -c "curl -fsS '$base/' > '$page'"
check grep -q 'const DEFAULT_SERVER_COUNT = 3;' "$page"
check grep -q 'const DOCKER_INSTALLATION = true;' "$page"
check grep -q 'const APP_VERSION = "1.5.011";' "$page"
# Test den faktiske nginx konfiguration uden at kræve internetadgang til GitHub.
check sh -c "docker exec '$app' cat /tmp/dobbelt-pi-hole/nginx.conf | grep -q 'location = /versioncheck/'"
check sh -c "docker exec '$app' cat /tmp/dobbelt-pi-hole/nginx.conf | grep -q 'refs/heads/main/version.js'"
check sh -c "docker exec '$app' cat /tmp/dobbelt-pi-hole/nginx.conf | grep -q 'proxy_pass_request_headers off;'"
check grep -q '"label":"Test 1"' "$page"
check sh -c "curl -fsSI -H 'Accept-Encoding: gzip' '$base/' | grep -qi 'content-encoding: gzip'"
check sh -c "curl -fsSI '$base/chart.umd.min.js' | head -n 1 | grep -q 200"
check sh -c "curl -fsSI '$base/language.js' | head -n 1 | grep -q 200"
for asset in language.template.js version.js README.md README.DA.md LICENSE \
    Chart.js.LICENSE favicon.ico icon.svg favicon-16x16.png \
    favicon-32x32.png apple-touch-icon.png android-chrome-192x192.png \
    android-chrome-512x512.png site.webmanifest; do
	check sh -c "curl -fsSI '$base/$asset' | head -n 1 | grep -q 200"
done
check sh -c "curl -fsSI '$base/' | grep -qi 'x-content-type-options: nosniff'"
# End to end through the proxy to the fake Pi-hole.
check sh -c "curl -fsS '$base/api1/auth' | grep -q '\"valid\":false'"
check sh -c "curl -fsS '$base/api1/groups' | grep -q '\"name\":\"Default\"'"
check sh -c "curl -fsS '$base/api1/config/dns/cnameRecords' | grep -q 'alias.test,target.test,60'"
check sh -c "curl -fsS '$base/api1/network/devices?max_devices=2147483647&max_addresses=2147483647' | grep -q 'max_devices=2147483647&max_addresses=2147483647'"
check sh -c "curl -fsS -X DELETE -o /dev/null -w '%{http_code}' '$base/api1/network/devices/12' | grep -qx 204"
check sh -c "curl -fsSI '$base/api1/teleporter' | grep -qi 'content-disposition: attachment'"
check sh -c "[ \"\$(docker exec '$app' id -u)\" = 101 ]"

# Invalid settings must stop the container with a clear message.
if ! docker run --rm -e PIHOLE_1_URL='http://a;b' -e PIHOLE_2_URL=http://b "$image" 2>&1 \
	| grep -q 'PIHOLE_1_URL skal'; then
	echo "FAILED: invalid URL was not rejected" >&2
	exit 1
fi
echo "smoke test OK"
