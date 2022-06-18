#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

in_defer() {
  echo "echo 'I was called whoops!'"
}

to_defer() {
  defer "in_defer" # this will fail because this could potentially loop forever if it also had a defer.
  echo "will not be printed" # setting up the defer will fail
}

to_defer