#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

source_again() {
  source "$SCRIPT_DIR/../../../defer.sh"
}

in_func() {
  defer "echo defer_post"
  source_again
  defer "echo defer_pre"

  echo "in_func"
}

in_func