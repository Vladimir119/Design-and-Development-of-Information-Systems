#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p screenshots
trap 'docker compose -p lab2-docker -f docker_compose.yml down; docker rm -f lab2-run >/dev/null 2>&1 || true' EXIT
docker build -t lab2-app:1.0 .
docker run -d --name lab2-run -p 8080:8080 -e APP_MESSAGE=Test lab2-app:1.0
for attempt in {1..30}; do
    if curl -fsS localhost:8080/health; then break; fi
    sleep 1
done
curl -fsS localhost:8080/health | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"] == "ok"'
curl -fsS localhost:8080/ | python3 -c 'import json,sys; assert json.load(sys.stdin)["message"] == "Test"'
test "$(docker exec lab2-run id -u)" = 10001
docker rm -f lab2-run
docker compose -p lab2-docker -f docker_compose.yml up -d --wait --wait-timeout 90
test "$(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health)" = 200
{
    echo '$ docker compose -f docker_compose.yml ps'
    docker compose -p lab2-docker -f docker_compose.yml ps
    echo '$ curl -i localhost:8080/health'
    curl -i localhost:8080/health
    echo
    echo '$ docker compose -f docker_compose.yml exec -T app id'
    docker compose -p lab2-docker -f docker_compose.yml exec -T app id
    echo '$ docker image inspect lab2-app:1.0 --format {{.Size}}'
    docker image inspect lab2-app:1.0 --format '{{.Size}}'
} > screenshots/check.txt
python3 - <<'PY'
from pathlib import Path
from html import escape
text = Path('screenshots/check.txt').read_text()
Path('screenshots/check.html').write_text('<meta charset="utf-8"><title>Лаба 2.1</title><h1>Лаба 2.1 — проверка в Ubuntu</h1><pre style="font-size:16px;white-space:pre-wrap">' + escape(text) + '</pre>')
PY
google-chrome --headless --no-sandbox --disable-gpu --hide-scrollbars --window-size=1600,900 --screenshot="$PWD/screenshots/status.png" "file://$PWD/screenshots/check.html"
google-chrome --headless --no-sandbox --disable-gpu --window-size=1000,600 --screenshot="$PWD/screenshots/health.png" http://localhost:8080/health
