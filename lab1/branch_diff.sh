#!/usr/bin/env bash
# Сравнение двух веток.
set -euo pipefail
export LC_ALL=C

if [[ $# -ne 3 ]]; then
    echo "Использование: $0 <репозиторий> <ветка_1> <ветка_2>" >&2
    exit 1
fi
repository=$1
branch1=$2
branch2=$3
for branch in "$branch1" "$branch2"; do
    git check-ref-format "refs/heads/$branch" >/dev/null || {
        echo "Недопустимое имя ветки: $branch" >&2; exit 1;
    }
done
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
git init --bare -q "$temporary/repo"
git -C "$temporary/repo" fetch --quiet --no-tags --depth=1 -- "$repository" \
    "refs/heads/$branch1:refs/reports/first"
git -C "$temporary/repo" fetch --quiet --no-tags --depth=1 -- "$repository" \
    "refs/heads/$branch2:refs/reports/second"
# Переименование считаем удалением и добавлением.
git -C "$temporary/repo" diff --no-renames --name-status -z \
    refs/reports/first refs/reports/second > "$temporary/changes"
total=0 added=0 deleted=0 modified=0 other=0
while IFS= read -r -d '' status && IFS= read -r -d '' path; do
    ((total+=1))
    case "$status" in
        A) ((added+=1));;
        D) ((deleted+=1));;
        M) ((modified+=1));;
        *) ((other+=1));;
    esac
    # Экранируем пробелы и переводы строк в именах файлов.
    printf '%s\t%q\n' "$status" "$path" >> "$temporary/list"
done < "$temporary/changes"
# Убираем из имени отчета символы вроде /.
safe_name() {
    local value=$1 character index
    for ((index=0; index<${#value}; index++)); do
        character=${value:index:1}
        case "$character" in
            [a-zA-Z0-9._-]) printf '%s' "$character";;
            *) printf '%%%02X' "'$character";;
        esac
    done
}
report="diff_report_$(safe_name "$branch1")_vs_$(safe_name "$branch2").txt"
{
    printf 'Отчет о различиях между ветками\n\n================================\n'
    printf 'Репозиторий:     %s\nВетка 1:        %s\nВетка 2:        %s\n' "$repository" "$branch1" "$branch2"
    printf 'Дата генерации: %s\n================================\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'СПИСОК ИЗМЕНЕННЫХ ФАЙЛОВ:\n'
    if ((total)); then cat "$temporary/list"; else printf 'Различий нет.\n'; fi
    printf '\nСТАТИСТИКА:\nВсего измененных файлов: %s\nДобавлено (A): %s\nУдалено (D): %s\nИзменено (M): %s\nПрочие (например, T — изменение типа): %s\n' \
        "$total" "$added" "$deleted" "$modified" "$other"
} > "$report"
printf 'Отчет сохранен: %s\n' "$report"
