#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
export COMPOSE_PROJECT_NAME=lab4-check
mkdir -p screenshots
trap 'docker compose logs --tail=30; docker compose down -v' EXIT
docker compose up -d --build --wait --wait-timeout 120
docker compose exec -T nginx sh -c '! command -v nginx'
docker compose exec -T app test ! -d /opt/labapp
docker compose exec -T master ansible-playbook playbook.yml --syntax-check
docker compose exec -T master ansible-playbook playbook.yml | tee screenshots/deploy.txt
docker compose exec -T master ansible-playbook playbook.yml | tee screenshots/repeat.txt
test "$(grep -Ec '^app +:.*changed=0.*unreachable=0.*failed=0|^nginx +:.*changed=0.*unreachable=0.*failed=0' screenshots/repeat.txt)" = 2
curl -fsS localhost:8080/health | python3 -c 'import sys,json; assert json.load(sys.stdin)["status"] == "ok"'
curl -fsS localhost:8080/ | python3 -c 'import sys,json; assert json.load(sys.stdin)["message"] == "Lab 4"'
docker compose exec -T master ansible-playbook playbook.yml -e app_message=Updated
curl -fsS localhost:8080/ | python3 -c 'import sys,json; assert json.load(sys.stdin)["message"] == "Updated"'
docker compose exec -T master ansible-playbook playbook.yml
docker compose restart app nginx
for attempt in {1..30}; do
    if curl -fsS localhost:8080/health; then break; fi
    sleep 1
done
test "$(curl -s -o /dev/null -w '%{http_code}' localhost:8080/health)" = 200
for service in master app; do
    test "$(docker inspect --format '{{len .HostConfig.PortBindings}}' "$(docker compose ps -q "$service")")" = 0
done
{
    echo '$ docker compose ps'
    docker compose ps
    echo '$ docker compose exec nginx supervisorctl status'
    docker compose exec -T nginx supervisorctl status
    echo '$ docker compose exec app supervisorctl status'
    docker compose exec -T app supervisorctl status
    echo '$ curl -i localhost:8080/health'
    curl -i localhost:8080/health
    echo
    echo '$ curl localhost:8080/'
    curl -fsS localhost:8080/
    echo
    echo 'Second playbook run:'
    sed -n '/PLAY RECAP/,$p' screenshots/repeat.txt
    echo 'Configuration update and container restart: OK'
} > screenshots/check.txt
python3 - <<'PY'
from pathlib import Path
from html import escape
text = Path('screenshots/check.txt').read_text()
Path('screenshots/check.html').write_text('<meta charset="utf-8"><title>Лаба 4</title><h1>Лаба 4 — проверка в Ubuntu</h1><pre style="font-size:16px;white-space:pre-wrap">' + escape(text) + '</pre>')
PY
google-chrome --headless --no-sandbox --disable-gpu --hide-scrollbars --window-size=1600,1000 --screenshot="$PWD/screenshots/status.png" "file://$PWD/screenshots/check.html"
google-chrome --headless --no-sandbox --disable-gpu --window-size=1000,600 --screenshot="$PWD/screenshots/health.png" http://localhost:8080/health
