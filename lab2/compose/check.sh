#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
export POSTGRES_DB=lab2 POSTGRES_USER=lab2
export POSTGRES_PASSWORD
POSTGRES_PASSWORD=$(openssl rand -hex 24)
mkdir -p screenshots
trap 'docker compose -p lab2-compose down' EXIT
docker compose -p lab2-compose up -d --build --wait --wait-timeout 120
test "$(curl -s -o /dev/null -w '%{http_code}' localhost/health)" = 200
test "$(docker compose -p lab2-compose exec -T app id -u)" = 10001
for service in app db; do
    container=$(docker compose -p lab2-compose ps -q "$service")
    test "$(docker inspect --format '{{len .HostConfig.PortBindings}}' "$container")" = 0
done
before=$(curl -fsS localhost/ | python3 -c 'import json,sys; print(json.load(sys.stdin)["visits"])')
docker compose -p lab2-compose down
docker compose -p lab2-compose up -d --wait --wait-timeout 120
after=$(curl -fsS localhost/ | python3 -c 'import json,sys; print(json.load(sys.stdin)["visits"])')
test "$after" -eq "$((before + 1))"
docker compose -p lab2-compose stop db
test "$(curl -s -o /dev/null -w '%{http_code}' localhost/health)" = 503
docker compose -p lab2-compose up -d --wait --wait-timeout 120
{
    echo '$ docker compose ps'
    docker compose -p lab2-compose ps
    echo '$ curl -i localhost/health'
    curl -i localhost/health
    echo
    echo '$ curl localhost/'
    curl -fsS localhost/
    echo
    echo "visits before down/up: $before"
    echo "visits after down/up: $after"
    echo 'app/db: no published ports; app UID: 10001'
    echo 'Database stopped: /health returned 503; database restarted: healthy'
} > screenshots/check.txt
python3 - <<'PY'
from pathlib import Path
from html import escape
text = Path('screenshots/check.txt').read_text()
Path('screenshots/check.html').write_text('<meta charset="utf-8"><title>Лаба 2.2</title><h1>Лаба 2.2 — проверка в Ubuntu</h1><pre style="font-size:16px;white-space:pre-wrap">' + escape(text) + '</pre>')
PY
google-chrome --headless --no-sandbox --disable-gpu --hide-scrollbars --window-size=1600,1000 --screenshot="$PWD/screenshots/status.png" "file://$PWD/screenshots/check.html"
google-chrome --headless --no-sandbox --disable-gpu --window-size=1000,600 --screenshot="$PWD/screenshots/health.png" http://localhost/health
