#!/usr/bin/env bash

# copy_function(
#  function_name_one: string,
#  function_name_two: string
# ) -> boolean
#
# Copy a function to a new name, this works by first testing for the function
# with `declare -f` which prints out a full declaration statement, if this
# fails we return 1 immediately, this function doesn't exist.
#
# If it succeeds we do the cryptic: `eval "${_/$1/$2}"` this roughly evaluates
# to:
#
#   1. For the output of the last command.
#   2. Swap argument one (which is the original function name).
#   3. For the second argument.
#
# this means we end up with the output of the full function body, and we've
# pattern matched swapped out the function name, with our new function name.
copy_function() {
  test -n "$(declare -f "$1")" || return 1
  eval "${_/$1/$2}"
  return 0
}

# rename_function(
#  function_name_one: string,
#  function_name_two: string
# ) -> boolean
#
# This renames any arbitrary function by first copying it to a new name, and
# then unset'ing the first function.
rename_function() {
  copy_function "$1" "$2" || return 1
  unset -f "$1"
  return 0
}