#!/usr/bin/env bash

# Check if our logger is already loaded, as there is global state that can be
# expensive to reinitialize.
if ! declare -f log:info >/dev/null 2>&1 ; then

# Ensure we always have a log format/log level.
if [ -z "${LOG_FORMAT+x}" ]; then
  export LOG_FORMAT="[{level} @ {file}:{function} / {time}] {message}"
fi
if [ -z "${LOG_LEVEL+x}" ]; then
  export LOG_LEVEL="info"
fi

# Rather than constantly converting a log level which can be any case like
# `tRaCe` to all lowercase, and then comparing everytime. We store it as a
# number in a private variable, updating the number only when it has changed.
#
# This also happens to make us resilient to other tools using the `LOG_LEVEL`
# environment variable after we've already initialized.
#
#   - `__num_for_lvl` is a private function that turns a level into a number.
#   - `__reset_log_lvl_number` is what actually refreshes the log level env
#     var.

# We also practice a similar conversion for log format-ing just incase someone
# else needs to use it. However, there is currently no way to reset this up,
# mainly because I haven't had a need for this.

# __num_for_lvl(level: string) -> number
#
# Modifies Globals:
#   None
#
# Turn a log level into a number so it's quick to check.
__num_for_lvl() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
  "trace")
    echo "0"
    ;;
  "debug")
    echo "1"
    ;;
  "info")
    echo "2"
    ;;
  "warn")
    echo "3"
    ;;
  "error")
    echo "4"
    ;;
  *)
    (>&2 echo -e "Unknown log level: [$1] defaulting to info")
    echo "2"
    ;;
  esac
}
export -f __num_for_lvl

# __reset_log_lvl_number()
#
# Modifies Globals:
#   - `__LOG_LEVEL_NUM`
#
# Ensure the exported `__LOG_LVL_NUM` is set to what the log implementation
# uses.
__reset_log_lvl_number() {
  export __LOG_LVL_NUM=$(__num_for_lvl "$LOG_LEVEL")
}
export -f __reset_log_lvl_number
# Call `__reset_log_lvl_number` to properly set the `__LOG_LVL_NUM` env var
# for the first time this is loaded.
__reset_log_lvl_number

# __has_in_format(format_str: String, format_id: String) -> 0 || 1
#
# Modifies Globals: None
#
# Rather than typing a whole bunch of long case statements, this checks
# if a particular string has another string inside of it. This way we can
# check 
__has_in_format() {
  case "$1" in
  *"$2"*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}
export -f __has_in_format

# Save the log format, and what we should replace, not only so we
# have to check the format string each time, but also so other tools that use
# `LOG_FORMAT` can continue working fine.

export __SAVED_LOG_FORMAT="${LOG_FORMAT}"
if __has_in_format "$__SAVED_LOG_FORMAT" "{file}" ; then
export __LOG_REPLACE_FILE=1
else
export __LOG_REPLACE_FILE=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{function}" ; then
export __LOG_REPLACE_FN=1
else
export __LOG_REPLACE_FN=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{level}" ; then
export __LOG_REPLACE_LVL=1
else
export __LOG_REPLACE_LVL=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{line}" ; then
export __LOG_REPLACE_LINE=1
else
export __LOG_REPLACE_LINE=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{message}" ; then
export __LOG_REPLACE_MSG=1
else
export __LOG_REPLACE_MSG=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{process}" ; then
export __LOG_REPLACE_PROC=1
else
export __LOG_REPLACE_PROC=0
fi
if __has_in_format "$__SAVED_LOG_FORMAT" "{time}" ; then
export __LOG_REPLACE_TIME=1
else
export __LOG_REPLACE_TIME=0
fi

# __log_impl(level: String, to_log: String)
#
# Modifies Globals: None
#
# Log out a message, don't call directly otherwise function name replacement
# will fail. Will log to STDERR to not be interpreted as a return value.
__log_impl() {
  local msg="$__SAVED_LOG_FORMAT"
  local -r lvl="$1"
  local -r to_log="$2"
  local -r lvl_num=$(__num_for_lvl "$lvl")

  if [ "$lvl_num" -lt "$__LOG_LVL_NUM" ]; then
    return 0
  fi

  if [ "$__LOG_REPLACE_TIME" -eq "1" ]; then
    msg="${msg/\{time\}/$(date)}"
  fi
  if [ "$__LOG_REPLACE_PROC" -eq "1" ]; then
    local -r pid="$$"
    msg="${msg/\{process\}/$pid}"
  fi
  if [ "$__LOG_REPLACE_MSG" -eq "1" ]; then
    msg="${msg/\{message\}/$to_log}"
  fi
  if [ "$__LOG_REPLACE_LINE" -eq "1" ]; then
    local -r line_number="${BASH_LINENO[2]}"
    msg="${msg/\{line\}/$line_number}"
  fi
  if [ "$__LOG_REPLACE_LVL" -eq "1" ]; then
    msg="${msg/\{level\}/$lvl}"
  fi
  if [ "$__LOG_REPLACE_FN" -eq "1" ]; then
    # We get called through things like log:info, so we're 2 back in the
    # callstack.
    local -r func_name="${FUNCNAME[2]}"
    msg="${msg/\{function\}/$func_name}"
  fi
  if [ "$__LOG_REPLACE_FILE" -eq "1" ]; then
    local -r source_name="${BASH_SOURCE[2]/.\//}"
    msg="${msg/\{file\}/$source_name}"
  fi

  # Print to STDERR
  (>&2 printf '%s\n' "$msg")
}
export -f __log_impl

# log:level(new_level: String)
#
# Modifies Globals:
#  - `LOG_LEVEL`
#  - `__LOG_LEVEL_NUM`
#
# Change the logging level.
log:level() {
  export LOG_LEVEL="$1"
  __reset_log_lvl_number
}
export -f log:level

# log:trace(to_log: String)
#
# Modifies Globals: None
#
# Log a message at the trace level.
log:trace() {
  __log_impl "trace" "$1"
}
export -f log:trace

# log:debug(to_log: String)
#
# Modifies Globals: None
#
# Log a message at the debug level.
log:debug() {
  __log_impl "debug" "$1"
}
export -f log:debug

# log:info(to_log: String)
#
# Modifies Globals: None
#
# Log a message at the info level.
log:info() {
  __log_impl "info" "$1"
}
export -f log:info

# log:warn(to_log: String)
#
# Modifies Globals: None
#
# Log a message at the warn level.
log:warn() {
  __log_impl "warn" "$1"
}
export -f log:warn

# log:error(to_log: String)
#
# Modifies Glboals: None
#
# Log a message at the error level.
log:error() {
  __log_impl "error" "$1"
}
export -f log:error

fi