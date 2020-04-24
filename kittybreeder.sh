#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
IFS=$'\n\t'

# TODO fix race condition when launching terminals in quick succession

BG_TERMS=5
RUNNING_DIR=/tmp/kittybreeder/running
HIDDEN_DIR=/tmp/kittybreeder/hidden

function fast_basename() {
    echo "${1##*/}"
}

function get_available_terms() {
    for f in "$HIDDEN_DIR"/*; do
        echo "$f"
    done
}

function launch_terms() {
    curr_terms="$(get_available_terms | wc -l)"
    for ((i=curr_terms;i<BG_TERMS;i++)); do
        id="$(uuidgen)"
        kitty --name "$id" --listen-on unix:"$RUNNING_DIR"/"$id"& disown
        ln -s "$RUNNING_DIR"/"$id" "$HIDDEN_DIR"/"$id"
    done
}

function show_term() {
    hidden_term_path="$(get_available_terms | head -n1)"
    if [[ -z "$hidden_term_path" ]]; then
        echo 'Could not show a new terminal as none are currently launched'
        return 1
    fi

    # Remove symlink ASAP
    hidden_term_uuid="$(fast_basename "$hidden_term_path")"
    active_term_path="$RUNNING_DIR"/"$hidden_term_uuid"
    rm "$hidden_term_path"

    text=${2:-}
    [[ -n "$text" ]] && kitty @ --to unix:"$active_term_path" send-text "$text"

    if [[ "$1" == "show" ]]; then
        i3-msg "[instance=\"$hidden_term_uuid\"] scratchpad show, floating disable" > /dev/null
    elif [[ "$1" == "showfloat" ]]; then
        i3-msg "[instance=\"$hidden_term_uuid\"] scratchpad show" > /dev/null
    else
        echo 'Internal error: invalid command passed to show_term'
        return 1
    fi
}

mkdir -p "$RUNNING_DIR"
mkdir -p "$HIDDEN_DIR"
cmd="${1:-}"

if [[ "$cmd" == "init" ]]; then
    killall kitty 2> /dev/null || :

    # Remove sockets manually so we don't have to wait for terminals to die
    rm -r "$RUNNING_DIR"
    rm -r "$HIDDEN_DIR"
    mkdir -p "$RUNNING_DIR"
    mkdir -p "$HIDDEN_DIR"

    launch_terms

elif [[ "$cmd" == "show" || "$cmd" == "showfloat" ]]; then
    set +e
    show_term "$cmd" "${2:-}"
    show_term_ret=$?
    set -e

    launch_terms

    exit "$show_term_ret"

# elif [[ "$cmd" == "fakeshell" ]]; then
#     $(<$1)

else
    echo "Invalid command: $cmd"
    echo "Usage: $(fast_basename $0) <init|show|showfloat>"
    exit 1
fi
