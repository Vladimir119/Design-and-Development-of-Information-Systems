#!/usr/bin/env bash
# Мониторинг ресурсов Linux.
set -euo pipefail
export LC_ALL=C
umask 077
script=$(readlink -f -- "${BASH_SOURCE[0]}")
identifier=$(printf '%s' "$script" | cksum | awk '{print $1}')
state="${XDG_STATE_HOME:-$HOME/.local/state}/lab1-monitor/$identifier"
mkdir -p -- "$state"
pidfile="$state/monitor.pid"

is_our_process() {
    [[ -f $pidfile ]] || return 1
    read -r pid < "$pidfile" || return 1
    [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/cmdline ]] || return 1
    local -a arguments=()
    mapfile -d '' -t arguments < "/proc/$pid/cmdline" || return 1
    [[ ${arguments[1]:-} == "$script" && ${arguments[2]:-} == __worker ]]
}

worker() {
    local report_dir=$1 interval=$2 pid=$BASHPID
    child=''
    cleanup() {
        if [[ -n $child ]]; then
            kill "$child" 2>/dev/null || true
            wait "$child" 2>/dev/null || true
        fi
        rm -f -- "$pidfile"
    }
    trap cleanup EXIT
    trap 'exit 0' TERM INT HUP
    printf '%s\n' "$pid" > "$pidfile"
    pause() { sleep "$1" 9>&- & child=$!; wait "$child"; child=''; }
    cpu_snapshot() {
        # guest и guest_nice уже входят в user и nice.
        awk '/^cpu / { total=0; for(i=2;i<=9;i++) total+=$i; print total, $5+$6; exit }' /proc/stat
    }
    local total1 idle1 total2 idle2 cpu memory disk load timestamp day report started remaining
    while true; do
        started=$SECONDS
        read -r total1 idle1 < <(cpu_snapshot)
        pause 1
        read -r total2 idle2 < <(cpu_snapshot)
        cpu=$(awk -v t="$((total2-total1))" -v i="$((idle2-idle1))" 'BEGIN {printf "%.2f", (t>0 ? 100*(t-i)/t : 0)}')
        memory=$(awk '/^MemTotal:/ {t=$2} /^MemFree:/ {f=$2} END {if(t<=0) exit 1; printf "%d;%d;%.2f", t,f,100*(t-f)/t}' /proc/meminfo)
        disk=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
        read -r load _ < /proc/loadavg
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        day=${timestamp%% *}
        report="$report_dir/system_report_$day.csv"
        if [[ ! -s $report ]]; then
            printf 'timestamp;all_memory;free_memory;%%memory_used;%%cpu_used;%%disk_used;load_average_1m\n' >> "$report"
        fi
        printf '%s;%s;%s;%s;%s\n' "$timestamp" "$memory" "$cpu" "$disk" "$load" >> "$report"
        remaining=$((interval - (SECONDS-started)))
        if ((remaining > 0)); then pause "$remaining"; fi
    done
}

if [[ ${1:-} == __worker ]]; then
    # Фоновый процесс получает блокировку от START.
    [[ $# == 3 && -e /proc/$$/fd/9 ]] || exit 1
    worker "$2" "$3"
    exit
fi
if [[ $# != 1 || ! $1 =~ ^(START|STOP|STATUS)$ ]]; then
    echo "Использование: $0 START|STOP|STATUS" >&2
    exit 1
fi
# Блокировка 8 — для команд управления, 9 — на время работы монитора.
exec 8> "$state/control.lock"
flock 8
exec 9> "$state/worker.lock"
case "$1" in
    START)
        if ! flock -n 9; then
            if is_our_process; then echo "Уже запущен. PID: $pid"; else echo 'Монитор запускается или завершается.'; fi
            exit 0
        fi
        interval=${MONITOR_INTERVAL_SECONDS:-600}
        [[ $interval =~ ^[1-9][0-9]*$ && ${#interval} -le 7 ]] || { echo 'Некорректный интервал.' >&2; exit 1; }
        report_dir=$(realpath -e -- "${MONITOR_REPORT_DIR:-$PWD}")
        [[ -d $report_dir && -w $report_dir ]] || { echo 'Каталог отчетов недоступен для записи.' >&2; exit 1; }
        rm -f -- "$pidfile"
        nohup bash "$script" __worker "$report_dir" "$interval" 8>&- </dev/null >> "$state/monitor.log" 2>&1 &
        worker_pid=$!
        for ((attempt=0; attempt<50; attempt++)); do
            if is_our_process && [[ $pid == "$worker_pid" ]]; then echo "Запущен. PID: $pid"; exit 0; fi
            kill -0 "$worker_pid" 2>/dev/null || break
            sleep 0.1
        done
        echo "Не удалось запустить монитор. См. $state/monitor.log" >&2
        exit 1;;
    STATUS)
        if ! flock -n 9 && is_our_process; then echo "Запущен. PID: $pid"; else echo 'Не запущен.'; fi;;
    STOP)
        if flock -n 9; then rm -f -- "$pidfile"; echo 'Не запущен.'; exit 0; fi
        if ! is_our_process; then echo 'Не удалось подтвердить PID монитора; процесс не остановлен.' >&2; exit 1; fi
        kill -TERM "$pid"
        if flock -w 5 9; then echo "Остановлен. PID: $pid"; else echo 'Монитор не завершился за 5 секунд.' >&2; exit 1; fi;;
esac
