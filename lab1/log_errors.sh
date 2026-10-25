#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || -z $2 ]]; then
    echo "Использование: $0 <лог-файл> <непустое ключевое слово>" >&2
    exit 1
fi
log=$1
keyword=$2
if [[ ! -f $log || ! -r $log ]]; then
    echo "Лог-файл не существует или недоступен для чтения: $log" >&2
    exit 1
fi
if [[ $keyword == *$'\n'* ]]; then
    echo 'Ключевое слово должно занимать одну строку.' >&2
    exit 1
fi
# A separate directory prevents overwriting the input or previous reports.
directory=$(mktemp -d ./log_report.XXXXXX)
complete=0
trap 'if (( ! complete )); then rm -rf -- "$directory"; fi' EXIT
result=0
grep -a -F -- "$keyword" "$log" > "$directory/errors.txt" || result=$?
if ((result > 1)); then
    echo 'Ошибка чтения лог-файла.' >&2
    exit "$result"
fi
count=$(wc -l < "$directory/errors.txt")
printf 'Количество найденных строк: %s\n' "$count" | tee "$directory/count.txt"
complete=1
printf 'Найденные строки: %s/errors.txt\nОтчет: %s/count.txt\n' "$directory" "$directory"
