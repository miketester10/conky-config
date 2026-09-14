#!/usr/bin/env bash

set -u

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
lock_file="${XDG_RUNTIME_DIR:-/tmp}/conky-display-watch.lock"

exec 9>"$lock_file"
flock -n 9 || exit 0

conky_pid=''

start_conky() {
    if [ -n "$conky_pid" ] && kill -0 "$conky_pid" 2>/dev/null; then
        kill "$conky_pid"
        for _ in {1..10}; do
            kill -0 "$conky_pid" 2>/dev/null || break
            sleep 0.1
        done
        if kill -0 "$conky_pid" 2>/dev/null; then
            kill -KILL "$conky_pid"
        fi
        wait "$conky_pid" 2>/dev/null || true
    fi

    "$config_dir/conky-blur-background.sh" || true
    conky --pause=1 --config "$config_dir/conky.conf" &
    conky_pid=$!
}

start_conky
last_restart=0

# COSMIC mantiene l'output "enabled" anche quando il monitor viene spento.
# Tuttavia registra queste righe quando ricrea l'output al suo ritorno.
journalctl --user -f -n 0 -o cat _COMM=cosmic-comp | while IFS= read -r message; do
    case "$message" in
        *"Failed to destroy old mode property blob"*|*"Failed to set xwayland primary output"*)
            now=$(date +%s)
            if (( now - last_restart >= 8 )); then
                last_restart=$now
                # Breve attesa per il completamento della riconfigurazione COSMIC.
                sleep 1
                start_conky
            fi
            ;;
    esac
done
