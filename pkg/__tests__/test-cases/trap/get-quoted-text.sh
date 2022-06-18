#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../trap.sh"

trap - "SIGALRM"
append_to_trap "SIGALRM" "echo 'hey \"hello\" \\\"sup\\\"'"
current_trap_handler "SIGALRM"
