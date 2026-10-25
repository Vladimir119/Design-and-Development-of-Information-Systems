# Лаба 2.1

Простое приложение на Python. Нужны Docker и Docker Compose.
Команды выполняются из `lab2/docker`.

## Сборка и запуск

```bash
docker build -t lab2-app:1.0 .
docker run -d --name lab2-app -p 8080:8080 -e APP_MESSAGE="Hello" lab2-app:1.0
curl -i localhost:8080/health
curl localhost:8080/
docker ps
docker inspect --format '{{.State.Health.Status}}' lab2-app
docker exec lab2-app id
```

`/health` возвращает HTTP 200 и `{"status": "ok"}`. На `/` выводится
APP_MESSAGE. Проверка Docker переходит в healthy примерно через 10 секунд.
Приложение работает с UID 10001, без root.

В builder исходник компилируется в байткод, в runtime копируется только
готовый файл. Обе стадии используют одну версию Python и slim-образ.
Внешних Python-зависимостей нет.

## Через Compose

Сначала остановить контейнер из предыдущего примера, чтобы освободить порт:

```bash
docker rm -f lab2-app
docker compose -f docker_compose.yml up -d --build
docker compose -f docker_compose.yml ps
curl -i localhost:8080/health
docker compose -f docker_compose.yml down
```

## Загрузка в registry

Подставить свой логин и название образа. Для Docker Hub:

```bash
docker login
bash build_push.sh docker.io/LOGIN/lab2-app 1.0
```

На другой машине:

```bash
docker run -d -p 8080:8080 -e APP_MESSAGE="Hello" docker.io/LOGIN/lab2-app:1.0
curl -i localhost:8080/health
```

Скрипт выполняет сборку и push; данные для входа в репозиторий не входят.
