#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../trap.sh"

function onTrap() {
  echo "onTrap"
}

trap - "SIGALRM"
append_to_trap "SIGALRM" "onTrap"
append_to_trap "SIGALRM" "onTrap"
append_to_trap "SIGALRM" "onTrap"
kill -s SIGALRM $BASHPID