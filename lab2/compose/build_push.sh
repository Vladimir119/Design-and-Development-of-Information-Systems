#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 || -z $1 || -z $2 || $2 == latest ]]; then
    echo "Использование: $0 <registry/user/image> <тег, не latest>" >&2
    exit 1
fi
cd -- "$(dirname -- "$0")"
docker build --pull -t "$1:$2" .
docker push "$1:$2"
