#!/usr/bin/env bash

set -eo pipefail

# Validate someones settings don't impact the test.
if [ "x$LOG_LEVEL" != "x" ]; then
  export __SCOPED_PREV_LOG_LEVEL="$LOG_LEVEL"
  export LOG_LEVEL="info"
  if declare -f "log:level" >/dev/null 2>&1 ; then
    export __SCOPED_SHOULD_SET="true"
    log:level "info"
  fi
fi
if [ "x$LOG_FORMAT" != "x" ]; then
  export __SCOPED_PREV_LOG_FORMAT="$LOG_FORMAT"
fi
export LOG_FORMAT="{message}"

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$SCRIPT_DIR/../../../logger.sh"

log_all() {
  log:trace "trace"
  log:debug "debug"
  log:info "info"
  log:warn "warn"
  log:error "error"
}

log_all
log:level "trace"
log_all
log:level "error"
log_all

# Resetup the users environment.
if [ "x$__SCOPED_PREV_LOG_LEVEL" != "x" ]; then
  export LOG_LEVEL="$__SCOPED_PREV_LOG_LEVEL"
  if [ "x$__SCOPED_SHOULD_SET" != "x" ]; then
    log:level "$__SCOPED_PREV_LOG_LEVEL"
  fi
fi
if [ "x$__SCOPED_PREV_LOG_FORMAT" != "x" ]; then
  export LOG_FORMAT="$__SCOPED_PREV_LOG_FORMAT"
fi