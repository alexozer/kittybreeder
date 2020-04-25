#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
IFS=$'\n\t'

BG_TERMS=5
RUNNING_DIR=/tmp/kittybreeder/running
CLAIMED_DIR=/tmp/kittybreeder/claimed
LOCKFILE=/tmp/kittybreeder/kittybreeder.lock

function fast_basename() {
    echo "${1##*/}"
}

function get_available_terms() {
    for f in "$RUNNING_DIR"/*; do
        echo "$f"
    done
}

function launch_terms() {
    curr_terms="$(get_available_terms | wc -l)"
    for ((i=curr_terms;i<BG_TERMS;i++)); do
        term_uuid="$(uuidgen)"
        running_term_path="$RUNNING_DIR"/"$term_uuid"
        mkfifo "$running_term_path"
        kitty --name "$term_uuid" "$0" fakeshell "$running_term_path" & disown
    done
}

function show_term() {
    echo "one"
    running_term_path="$(get_available_terms | head -n1)"
    if [[ -z "$running_term_path" ]]; then
        echo 'Could not show a new terminal as none are currently launched'
        return 1
    fi

    echo "two"
    term_uuid="$(fast_basename "$running_term_path")"
    claimed_term_path="$CLAIMED_DIR"/"$term_uuid"

    echo "three $term_uuid"
    # Attempt an atomic move to new dir to claim terminal, else try again
    if ! mv "$running_term_path" "$claimed_term_path"; then
        echo 'Race condition!'
        return 1
    fi

    echo "four $term_uuid"
    # Write command to run in terminal to FIFO
    echo "$2" > "$claimed_term_path"
    rm "$claimed_term_path"

    echo "five $term_uuid"
    # Show the terminal
    if [[ "$1" == "show" ]]; then
        i3-msg "[instance=\"$term_uuid\"] scratchpad show, floating disable" > /dev/null
    elif [[ "$1" == "showfloat" ]]; then
        i3-msg "[instance=\"$term_uuid\"] scratchpad show" > /dev/null
    else
        echo 'Internal error: invalid command passed to show_term'
        return 1
    fi
}

mkdir -p "$RUNNING_DIR"
mkdir -p "$CLAIMED_DIR"
cmd="${1:-}"

if [[ "$cmd" == "fakeshell" ]]; then
    eval $(<$2)

else
    (
        flock -x -w 5 200 || echo 'Failed to acquire lock' && exit 1
        
        if [[ "$cmd" == "init" ]]; then
            killall kitty 2> /dev/null || :

            # Remove sockets manually so we don't have to wait for terminals to die
            rm -r "$RUNNING_DIR"
            rm -r "$CLAIMED_DIR"
            mkdir -p "$RUNNING_DIR"
            mkdir -p "$CLAIMED_DIR"

            launch_terms

        elif [[ "$cmd" == "show" || "$cmd" == "showfloat" ]]; then
            set +e
            show_term "$cmd" "$2"
            show_term_ret=$?
            set -e

            launch_terms

            exit "$show_term_ret"

        else
            echo "Invalid command: $cmd"
            echo "Usage: $(fast_basename "$0") <init|show|showfloat>"
            exit 1
        fi

    ) 200>"$LOCKFILE"

fi
