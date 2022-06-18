#!/usr/bin/env bash

# Implement `defer` which allows you to defer commands until the end of a
# function. This package also has some helpers around `set -e`, which is a very
# common case of defer (allowing safety at just a function scope).
#
# Modifies State:
#
#  - Runs: `set -o functrace`, this is required by this package, and should
#          never be unset.

# Check if defer is already loaded, as there is global state that is not safe
# to re-initialize.
if ! declare -f defer >/dev/null 2>&1 ; then

# Load in our dependencies on:
#
#  - `pkg/trap.sh`
__PKG_DEFER_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "${__PKG_DEFER_DIR}/trap.sh"

# Check if we're being loaded in an environment with `set -e` already enabled,
# this way we know what to set our environment back too when done.
#
# We use a case statement here to avoid compiling a regex for just a single
# character.
case "$-" in
  *"e"*)
    __base_error_mode=1
    ;;
  *)
    __base_error_mode=0
    ;;
esac

# Create a hashmap of functions that have per-function `set -e` state.
#
# We split this into two arrays, we don't want to use `pkg/map.sh` to
# prevent loops where function return trap calls a function which calls
# a function return trap, and so on.
#
# We keep both of these in sync so `${__error_stack_key[idx]}`, is the key
# of a map, and `${__error_stack_value[idx]}` is the value for the key at
# `idx`.
__error_stack_key=()
__error_stack_value=()

# Create a hashmap of commands to run when a function exits.
#
# We split this into two arrays, we don't want to use `pkg/map.sh` to
# prevent loops where function return trap calls a function which calls
# a function return trap, and so on.
#
# We keep both of these in sync so `${__defer_stack_key[idx]}`, is the key
# of a map, and `${__defer_stack_value[idx]}` is the value for the key at
# `idx`.
__defer_stack_key=()
__defer_stack_value=()

# __push_error_stack(func_name: String, err_mode: boolean)
#
# Modifies Globals:
#   * __error_stack_key
#   * __error_stack_value
# Modifies State:
#   * Error Mode.
#
# Pushes onto the error stack.
__push_error_stack() {
  __error_stack_key=("${__error_stack_key[@]}" "$1")
  __error_stack_value=("${__error_stack_value[@]}" "$2")

  if [ "$2" -eq "1" ]; then
    set -e
  else
    set +e
  fi
}

# __pop_err_stack()
#
# Modifies Globals:
#   * __error_stack_key
#   * __error_stack_value
# Modifies State:
#   * Error Mode
#
# Should be called when a function exits. Checks to see
# if the function exiting had an artificial error state, and unsets it.
__pop_err_stack() {
  local -r func_name="${FUNCNAME[1]}"

  # Check if we have any artifical states at all, to check.
  local -r stack_size="${#__error_stack_key[@]}"
  if [ "$stack_size" -eq "0" ]; then
    return 0
  fi
  local -r stack_le_index=$(( stack_size - 1 ))

  # Get the last function that set an artifical error state, and if we
  # just exited from it.
  local -r stack_last_element="${__error_stack_key[$stack_le_index]}"
  if [ "$stack_last_element" = "$func_name" ]; then
    # if this is the last item in our stack...
    if [ "$stack_size" -eq "1" ]; then
      # Reset back to what we were originally.
      if [ "$__base_error_mode" -eq "1" ]; then
        set -e
      else
        set +e
      fi
      __error_stack_key=()
      __error_stack_value=()
      return 0
    fi

    # Check the item that came before the function just exiting, and
    # make sure it's on the correct error mode.
    if [ "${__error_stack_value[$stack_le_index]}" -eq "1" ]; then
      set +e
    else
      set -e
    fi

    # Finally pop off ourselves from the stack.
    unset '__error_stack_key[-1]'
    unset '__error_stack_value[-1]'
  else
    # If we are still actively in our function that has an artifical error
    # state, make sure that no one has stomped over this in another command
    # since this is a global, by re-setting what we'd expect it to be at.
    if [ "${__error_stack_value[$stack_le_index]}" -eq "1" ]; then
      set -e
    else
      set +e
    fi
  fi

  return 0
}

# __defer_invoke()
#
# Modifies Globals:
#   * __defer_stack_key
#   * __defer_stack_value
# Modifies State:
#   * Potentially (user defined)
#
# Should be called when a function exits. Checks to see if the function exiting
# had any actions that have been defer'd, and runs them.
__defer_invoke() {
  local -r func_name="${FUNCNAME[1]}"

  # Check if we have any defer'd actions that have been registered.
  local stack_size="${#__defer_stack_key[@]}"
  if [ "$stack_size" -eq 0 ]; then
    return 0
  fi

  # For each item in the stack, check if it needs to run at the end
  # of the function that just exited.
  local stack_le_index=$(( stack_size - 1 ))
  local stack_last_element="${__defer_stack_key[$stack_le_index]}"
  # While we have actions to run for the function that just exited (this lets
  # us have multiple defer's).
  while [ "$stack_last_element" = "$func_name" ]; do
    # If we're the last element in the stack, run the users command, and
    # then exit early.
    if [ "$stack_size" -eq 1 ]; then
      ${__defer_stack_value[0]}
      __defer_stack_key=()
      __defer_stack_value=()
      return 0
    fi

    # If we're not the last element, run the action, and
    # 'pop' ourselves off of the stack.
    ${__defer_stack_value[$stack_le_index]}
    unset '__defer_stack_key[-1]'
    unset '__defer_stack_value[-1]'
    stack_le_index=$(( stack_le_index - 1 ))
    stack_size=$(( stack_size - 1 ))
    stack_last_element="${__defer_stack_key[$stack_le_index]}"
  done

  return 0
}

set -o functrace
append_to_trap "RETURN" "__defer_invoke;__pop_err_stack"

# defer_ignore_errors()
#
# Modifies Variables:
#   * __error_stack_key
#   * __error_stack_value
# Modifies State:
#   * Error Mode.
#
# sets the error mode to be off for the duration of this function.
defer_ignore_errors() {
  __push_error_stack "${FUNCNAME[1]}" "0"
}

# defer_guard_errors()
#
# Modifies Variables:
#   * __error_stack_key
#   * __error_stack_value
# Modifies State:
#   * Error Mode.
#
# sets the error mode to be on for the duration of this function.
defer_guard_errors() {
  __push_error_stack "${FUNCNAME[1]}" "1"
}

# defer(command: String) -> boolean
#
# Modifies Variables:
#   * __defer_stack_key
#   * __defer_stack_value
# Modifies State:
#   None
#
# defer a statement to be run at the end of the current function, can be called
# multiple times in the same function.
#
# NOTE: defer cannot accept a function, as then defer would loop forever, we
# try to guard against this by returning one. This is possible to get around,
# but you've been warned.
defer() {
  if ! declare -f "${1}" >/dev/null 2>&1 ; then
    __defer_stack_key=("${__defer_stack_key[@]}" "${FUNCNAME[1]}")
    __defer_stack_value=("${__defer_stack_value[@]}" "$@")
  else
    return 1
  fi

  return 0
}

fi