#!/usr/bin/env bash

# A series of helpers to make dealing with the `trap` shell built-in easier.

# current_trap_handler(signal: String)
#
# Modifies Globals:
#   - None
#
# parses trap output to get you the command currently set for a signal.
# However, this has removed all the quoting around the normal trap output so
# you can just immediately plug it into something else.
current_trap_handler() {
  printf '%s' "$(trap -p "$1" | sed "s/trap -- '//g; s/' $1$//g; s/\\\''//g")"
}
export -f current_trap_handler

# set_trap_handler(signal: String, command: String)
#
# Modifies Globals:
#   - None
# Modifies State:
#   - trap for `$signal` gets set to `$command`
#
# set the commands to run for a trap, completely clobbers anything that was
# previously there. If you need to append safely, use `append_to_trap`.
#
# this properly handles an empty string, as the normal trap requires passing
# in `-`.
set_trap_handler() {
  if [ -z "$2" ]; then
    trap - "$1"
  else
    trap "$2" "$1"
  fi
}
export -f set_trap_handler

# append_to_trap(signal: string, to_add: string)
#
# Modifies Globals:
#   - None
# Modifies State:
#   - trap for `$signal` gets set to `$command`
#
# Append some data to a particular signal handler within a
append_to_trap() {
  local -r signal="$1"
  local -r command_to_add="$2"
  local -r current_handler=$(current_trap_handler "$signal")

  if [ -z "$current_handler" ]; then
    set_trap_handler "$signal" "$command_to_add"
  else
    if [[ "$current_handler" == '*;' ]]; then
      set_trap_handler "$signal" "${current_handler}${command_to_add}"
    else
      set_trap_handler "$signal" "${current_handler};${command_to_add}"
    fi
  fi
}
export -f append_to_trap