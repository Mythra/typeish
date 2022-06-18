#!/usr/bin/env bash

# The entrypoint to "type-ish", defines the actual `sig` function that accepts
# user signatures, and sets up the traps to intercept functions, setup argument
# parsing, and type validation.

# Only load `typeish` once, as there is global state that we don't want to
# reinitialize.
if ! declare -f sig ; then

# Load in dependencies.
export TYPEISH_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$TYPEISH_DIR/pkg/defer.sh"
source "$TYPEISH_DIR/pkg/logger.sh"
source "$TYPEISH_DIR/pkg/map.sh"
source "$TYPEISH_DIR/pkg/trap.sh"
source "$TYPEISH_DIR/internal/fns.sh"
source "$TYPEISH_DIR/internal/strings.sh"
source "$TYPEISH_DIR/internal/types.sh"

export __TYPEISH_COUNTER=0
export __TYPEISH_TYPE_MAP=$(make_map "boolean=sig_validate_type_for" "string=sig_validate_type_for" "number=sig_validate_type_for" "array_generic=sig_validate_type_for" "void=sig_validate_type_for")
export __TYPEISH_SIG_MAP=$(make_map)
export __TYPEISH_REMAPPED_FNS=$(make_map)

# sig(type_definition: String) -> boolean
#
# Modifies Globals:
#  - `__TYPEISH_SIG_MAP`
#
# Parses a type definition for a function. Type definitions are formatted like:
# `sig {function_name.params{argument:string}.returns{string}}`. The ordering
# of the components in a sig (function_name, parameters, returns) are not
# order dependent, and can have any variable amount of spacing between them.
#
# The builtin types available are: (string, number, array[Ty], void, boolean). You can
# define custom types, and pass those in (also supported in array[]) with
# `sig_custom_type` which mostly resembles a sig function, but takes a function
# that validates + returns a type that is registered.
#
# Generic types cannot be nested, and you can register your own generic type
# by registering it as: `<type_name>_generic`.
#
# Finally it should also be noted you do not techincally have to specify a
# `params{}`, or a `returns{}` types. Both of these wil be cast to void for
# you.
#
# NOTE: `sig_update_functions` has to be called once the function is defined
# for the signature to take effect.
sig() {
  defer_guard_errors

  local full_sig=$(printf '%s' "${@}")
  log:trace "Found sig: \`${full_sig}\`"

  # First check for the well formed-ness of the sig, does it start with `{`,
  # and end with `}`?
  if [ "${full_sig::1}" != "{" ]; then
    log:error "Received sig: \`${full_sig}\`, expected format of: \`{function_name.params{arg: type}.returns{type}}\`"
    log:error "Sig did not start with \`{\`"
    return 1
  fi
  if [ "${full_sig: -1}" != "}" ]; then
    log:error "Received sig: \`${full_sig}\`, expected format of: \`{function_name.params{arg: type}.returns{type}}\`"
    log:error "Sig did not end with \`}\`"
    return 1
  fi
  # It does! Great! Let's remove those so we just, don't gotta worry about it.
  full_sig="${full_sig:1:-1}"

  # Now let's split it up, and make sure we got enough parts.
  local -r split_sig=($(__typeish_str_split "$full_sig" "."))
  if [ "${#split_sig[@]}" -lt "1" ]; then
    log:error "Signature: \`${full_sig}\` is not well-formed!"
    log:error "Expected a signature that at least contained a function name!"
    return 1
  fi
  if [ "${#split_sig[@]}" -gt "3" ]; then
    log:error "Signature: \`${full_sig}\` is not the expected three parts: \`{function_name.params{arg: type}.returns{type}}\`."
    log:error "Instead of using \`.\` in function names, or argument names perhaps try using \`:\`"
    return 1
  fi

  # Now let's process each part of the sig, keeping track of what we've already
  # seen to make sure we don't have double parts, and can confirm we processed
  # the needed parts.
  local fn_name=""
  local params=$(make_map)
  local returns=""

  local sig_part=
  for sig_part in "${split_sig[@]}"; do
    log:trace "Sig Part: [${sig_part}]"
    
    if [ "${sig_part::7}" = "params{" ]; then
      if [ "${sig_part: -1}" != "}" ]; then
        log:error "Signature: \`${full_sig}\` parameter block: \`${sig_part}\`, did not end with \`}\`"
        return 1
      fi
      if ! is_empty_map "$params"; then
        log:error "Signature: \`${full_sig}\` had two parameter blocks! this is not supported!"
        return 1
      fi

      local param_pairs=($(__typeish_str_split "${sig_part:7:-1}" ","))
      for param_pair in "${param_pairs[@]}"; do
        local split_param=($(__typeish_str_split "${param_pair}" ":"))
        if [ "${#split_param[@]}" -ne "2" ]; then
          log:error "Signature: \`${full_sig}\` had a parameter: \`${param_pair}\`, which was not in the expected format of: \`name:type\`, parameters do not support names with \`:\` in them."
          return 1
        fi
        if ! __sig_type_exists "${split_param[1]}"; then
          log:error "Signature: \`${full_sig}\` had a parameter: \`${param_pair}\`, which had a type of: \`${split_param[1]}\` which is not a known type. Known types are: $(keys_map "${__TYPEISH_TYPE_MAP}")"
          return 1
        fi
        if contains_map "${params}" "${split_param[0]}"; then
          log:error "Signature: \`${full_sig}\` had a parameter: \`${param_pair}\` whose name: \`${split_param[0]}\` which was already registered."
          return 1
        fi
        params=$(upsert_map "$params" "${split_param[0]}=${split_param[1]}")
      done
    elif [ "${sig_part::8}" = "returns{" ]; then
      if [ "${sig_part: -1}" != "}" ]; then
        log:error "Signature: \`${full_sig}\` returns block: \`${sig_part}\`, did not end with \`}\`"
        return 1
      fi
      if [ "x$returns" != "x" ]; then
        log:error "Signature: \`${full_sig}\` had two returns blocks! this is not supported!"
        return 1
      fi

      local ret_ty="${sig_part:8:-1}"
      if ! __sig_type_exists "${ret_ty}"; then
        log:error "Signature: \`${full_sig}\`, found return type of: \`${ret_ty}\` which is not a known type. Known types are: $(keys_map "${__TYPEISH_TYPE_MAP}")"
        return 1
      fi
      returns="$ret_ty"
    else
      if [ "x$fn_name" != "x" ]; then
        log:error "Signature: \`${full_sig}\` had two function names! this is not supported!"
        return 1
      fi
      fn_name="${sig_part}"
    fi
  done

  if [ "x$fn_name" = "x" ]; then
    log:error "Signature: \`${full_sig}\` did not register a function name! This is required, only params/returns are optional."
    return 1
  fi
  if is_empty_map "$params" ; then
    params=$(upsert_map "$params" "placeholder=void")
  fi
  if [ "x$returns" = "x" ]; then
    returns="void"
  fi
  log:trace "Successfully parsed function signature!"

  # Okay! We have a valid signature at this point!
  #
  # We have a function name
  # We have the parameter names+types (and types are valid!)
  # We have the return type (and the return type is valid!)
  #
  # We now need to store these in `__TYPEISH_SIG_MAP`, however we have a map
  # ourself! `params`! Yet our map type doesn't support nesting maps :(
  #
  # Well... we can work around this by doing something that is a definite
  # footgun(!), but we can replace the internal map seperator `$IFS` with just...
  # another character. We'd have to remember to replace it back with the real
  # character when we actually wanted to use it. That's... probably fine. I
  # mean people program in C/C++ which is full of footguns and do just fine!
  # Why can't we throw caution to the wind too?
  #
  # We actually have to nest params in a map, and then nest that map in the
  # sig map! We replace the params `$IFS` with '.' because '.' is guaranteed
  # to not be in a type name that's usable.
  #
  # Next we replace the outer map's `$IFS` with "$" because that can't ever be
  # used, and so it will never be activated in this path.
  params=$(printf '%s' "${params}" | tr "$IFS" '.')
  fn_info_map=$(make_map "function_name=${fn_name}" "params=${params}" "return_type=${returns}")
  fn_info_map=$(printf '%s' "${fn_info_map}" | tr "$IFS" '$')
  __TYPEISH_SIG_MAP=$(upsert_map "${__TYPEISH_SIG_MAP}" "${fn_name}=${fn_info_map}")
  return 0
}

# sig_custom_type(custom_type_definition: string) -> boolean
#
# Modifies Globals:
#  - __TYPEISH_TYPE_MAP
#
# ---
#
# Register a custom type to be handled by type-ish for you. When you register
# a custom type, you are registering a function that gets called everytime your
# type is asked for.
#
# You get passed in 1 argument (or 2! if you're a generic type -- more on this
# below) which is whatever you've specified as your source type. You are
# expected to return 0 or 1 depending on if the type conforms to whatever
# particular value you deem to be required.
#
# If you are a generic type, the second parameter (which may be nothing!) is
# what type if _any_ a user specified as the generic type. You are expected
# to extract the inner value, and call `sig_validate_type_for` for each
# potential item you have. `sig_validate_type_for` takes the type name, and
# the actual raw value.
#
# ---
#
# Sig custom type handlers look roughly like:
#
#   - `sig_custom_type { map_ty.from { string }.produces { Map_generic } }`
#
# This looks very similar to a sig handler, and in essence it is. However,
# this one requires all three parts (unlike a sig handler only requiring)
# a function name!
#
# The `Ty` in `produces {Ty}`, represents the potentially new type name,
# `from {string}` represents a possible previous type this could come from.
# Although there is only allowed to be one function that performs
# TypeA -> TypeB, there can be many TypeA's available.
#
# Although please note: This comes with performance overhead as type-ish
# will have to check every single TypeA in the order they were registered
# in order to determine if it is the correct type.
#
# Since types are really just fancy names we recommend having multiple
# type names available whenever possible. (Perhaps you could even do
# something like the old Golang Egyptian brackets generation trick!) 
sig_custom_type() {
  defer_guard_errors
  
  local full_sig=$(printf '%s' "${@}")
  log:trace "Found sig_custom_type: \`${full_sig}\`"

  # First check for the well formed-ness of the sig, does it start with `{`,
  # and end with `}`?
  if [ "${full_sig::1}" != "{" ]; then
    log:error "Received sig_custom_type: \`${full_sig}\`, expected format of: \`{function_name.from{type}.produces{type}}\`"
    log:error "Sig did not start with \`{\`"
    return 1
  fi
  if [ "${full_sig: -1}" != "}" ]; then
    log:error "Received sig_custom_type: \`${full_sig}\`, expected format of: \`{function_name.from{type}.produces{type}}\`"
    log:error "Sig did not end with \`}\`"
    return 1
  fi
  # It does! Great! Let's remove those so we just, don't gotta worry about it.
  full_sig="${full_sig:1:-1}"
  # Now let's split it up, and make sure we got enough parts.
  local -r split_sig=($(__typeish_str_split "$full_sig" "."))
  if [ "${#split_sig[@]}" -ne "3" ]; then
    log:error "Signature: \`${full_sig}\` is not the expected three parts: \`{function_name.from{type}.produces{type}}\`."
    return 1
  fi

  # Now we can process the custom type. This is pretty much the same as the
  # actual sig flow just for types.
  local fn_name=
  local from_ty=
  local returns_ty=

  local sig_part=
  for sig_part in "${split_sig[@]}"; do
    if [ "${sig_part::5}" = "from{" ]; then
      if [ "x$from_ty" != "x" ]; then
        log:error "sig_custom_type: \`${full_sig}\`, received second \`from{\` block: \`${sig_part}\`, first was: \`${from_ty}\`. Only one from is allowed"
        return 1
      fi
      if [ "${sig_part: -1}" != "}" ]; then
        log:error "sig_custom_type: \`${full_sig}\`, received the start of a from block: \`${sig_part}\`, which did not end with \`}\`. This is required!"
        return 1
      fi

      local potential_ty="${sig_part:5:-1}"
      if ! __sig_type_exists "${potential_ty}"; then
        log:error "sig_custom_type: \`${full_sig}\`, produces type: \`${potential_ty}\`, which is not a known type. Known Types Are: $(keys_map "${__TYPEISH_TYPE_MAP}")"
        return 1
      fi
      from_ty="${potential_ty}"
    elif [ "${sig_part::9}" = "produces{" ]; then
      if [ "x${returns_ty}" != "x" ]; then
        log:error "sig_custom_type: \`${full_sig}\`, received second \`produces{\` block: \`${sig_part}\`, first was: \`${returns_ty}\`. Only one produces is allowed"
        return 1
      fi
      if [ "${sig_part: -1}" != "}" ]; then
        log:error "sig_custom_type: \`${full_sig}\`, received the start of a produces block: \`${sig_part}\`, which did not end with \`}\`. This is required!"
        return 1
      fi

      # This could be a new type! no need to double check!
      returns_ty="${sig_part:9:-1}"
    else
      if [ "x$fn_name" != "x" ]; then
        log:error "sig_custom_type: \`${full_sig}\`, received second function name: \`${sig_part}\`, first was: \`${fn_name}\`. Only one function name is supported!"
        return 1
      fi
      fn_name="${sig_part}"
    fi
  done

  log:debug "Found new type! ${returns_ty}, comes from ${from_ty}, calls function: ${fn_name}!"

  # We have to do something similar here where we store maps in maps, and we do
  # this hackily by replacing $IFS with another character. We use the character
  # `.` as our inner seperator.
  local inner_map=$(get_default_map "$__TYPEISH_TYPE_MAP" "$returns_ty" "$(make_map)" | tr '.' "$IFS")
  if contains_map "$inner_map" "$from_ty" ; then
    log:error "Type conversion from: ${from_ty} -> ${returns_ty} already points to $(get_map "$inner_map" "$from_ty"), cannot also register ${fn_name}"
    return 1
  fi
  inner_map=$(upsert_map "$inner_map" "${from_ty}=${fn_name}")
  inner_map=$(printf '%s' "$inner_map" | tr "$IFS" '.')
  __TYPEISH_TYPE_MAP=$(upsert_map "$__TYPEISH_TYPE_MAP" "${returns_ty}=${inner_map}")

  return 0
}

# sig_validate_type_for(type: String, value: *) -> boolean
#
# sig_validate_type_for takes a type, and a value returning if that value is
# a valid interpretation of type. This searches all types/type conversions
# linearly, and all at once.
sig_validate_type_for() {
  defer_guard_errors

  log:trace "sig_validate_type_for($1, $2)"

  local -r type_to_validate_for=$(printf '%s' "$1" | tr -d '\t' | tr -d '\n' | tr -d ' ')
  local -r value="$2"

  case "$type_to_validate_for" in
    "string")
      # All strings are valid! Thanks bash :)
      log:debug "Asked to validate -- string type for: \`$value\`, always valid."
      return 0
      ;;
    "number" | "boolean")
      case "$value" in
        ''|*[!\+\-\.0-9]*)
          log:error "Argument: \`$value\` is NaN, but was asked to be number/boolean."
          return 1
          ;;
        *)
          log:debug "Argument: \`$value\` is a number."
          return 0
          ;;
      esac
      ;;
    "void")
      if [ "x$value" != "x" ]; then
        log:error "Argument: \`$value\` is not void"
        return 1
      fi

      log:debug "Argument is void!"
      return 0
      ;;
    "array["*"]")
      local inner_type="${type_to_validate_for:6:-1}"
      log:trace "Found array inner type: \`$inner_type\`, validating members"
      local as_array=($(printf '%s' "$value"))
      local array_value=
      for array_value in "${as_array[@]}"; do
        if ! sig_validate_type_for "${inner_type}" "${array_value}"; then
          return 1
        fi
      done

      log:debug "Type matches array type: \`${type_to_validate_for}\`"
      return 0
      ;;
    *)
      if contains_map "${__TYPEISH_TYPE_MAP}" "${type_to_validate_for}"; then
        log:trace "Found non-generic type: ${type_to_validate_for}"
        local inner_type_map=$(get_map "${__TYPEISH_TYPE_MAP}" "${type_to_validate_for}" | tr '.' "$IFS")
        local possible_conversions_from=($( keys_map "${inner_type_map}" ))

        # Need to dig down until we get to a base type. Since types are really
        # just fancy ways of doing casting, and has to come from some type,
        # there is guaranteed to be a path back to a base type.
        #
        # This means we safely recurse til we get a base type which would
        # be validated above, and return true.
        local type_name=
        for type_name in "${possible_conversions_from[@]}"; do
          if ! sig_validate_type_for "${type_name}" "${value}" >/dev/null 2>&1; then
            log:debug "Value: \`${value}\` doesn't match type in the from part of this conversion: \`${type_name}\`, moving on."
            continue
          fi

          local fn_name=$(get_map "${inner_type_map}" "${type_name}")
          # This calls a function stored in `$fn_name`
          if ! $fn_name "$value" >/dev/null 2>&1 ; then
            log:debug "Value: \`${value}\` did match from type: \`${type_name}\`, but could not be converted to: \`${type_to_validate_for}\`"
            continue
          fi
          log:debug "Value: \`${value}\` matches type: \`${type_to_validate_for}\`"
          return 0
        done

        return 1
      fi

      case "${type_to_validate_for}" in
        *"["*"]"*)
          local types=($(printf '%s' "${type_to_validate_for}" | sed 's/\[/ /' | sed 's/\]/ /' | tr ' ' "$IFS"))
          if [ "${#types[@]}" -gt "2" ]; then
            log:error "Unknown type, generic-looking, but Unsupported generic more than two values as expected: ${types[@]}"
            return 1
          fi
          if ! contains_map "${__TYPEISH_TYPE_MAP}" "${types[0]}_generic"; then
            log:error "Unknown type, generic-looking, but Type is not generic: ${types[0]} (not registered as: \`${types[0]}_generic\`), and cannot be considered as one."
            return 1
          fi

          # Okay we now have a generic type, and a potential-type for the
          # actual generic. Now we can do a very similar look as a non-generic
          # type, just making sure to pass in the second parameter.
          local inner_type_map=$(get_map "${__TYPEISH_TYPE_MAP}" "${types[0]}_generic" | tr '.' "$IFS")
          local possible_conversions_from=($( keys_map "${inner_type_map}" ))
          log:trace "Found generic type: \`${types[0]}\`, validating types against: inner map: \`${inner_type_map}\`, possible_conversions_from: \`${possible_conversions_from[@]}\`"

          # Need to dig down until we get to a base type. Since types are really
          # just fancy ways of doing casting, and has to come from some type,
          # there is guaranteed to be a path back to a base type.
          #
          # This means we safely recurse til we get a base type which would
          # be validated above, and return true.
          local type_name=
          for type_name in "${possible_conversions_from[@]}"; do
            log:trace "Checking against \`${type_name}\`"
            if ! sig_validate_type_for "${type_name}" "${value}" >/dev/null 2>&1; then
              log:debug "Value: \`${value}\` doesn't match type in the from part of this conversion: \`${type_name}\`, moving on."
              continue
            fi
  
            local fn_name=$(get_map "${inner_type_map}" "${type_name}")
            if ! $fn_name "$value" "${types[1]}" >/dev/null 2>&1 ; then
              log:debug "Value: \`${value}\` did match from type: \`${type_name}\`, but could not be converted to: \`${type_to_validate_for}\`"
              continue
            fi
            log:debug "Value: \`${value}\` matches type: \`${type_to_validate_for}\`"
            return 0
          done

          log:error "Type: \`${type_to_validate_for}\` could not match against: \`${value}\`"
          return 1
          ;;
        *)
          log:error "Unknown type: \`${type_to_validate_for}\`! Can't validate types!"
          return 1
      esac
      ;;
  esac
}

# sig_update_functions() -> void
#
# sig_update_functions is called whenever you want to reload the function
# definitions to properly handle SIGs. We do this because setting up a
# `trap` on `DEBUG` with functrace is the only other way to properly intercept
# functions that are about to be called, but that adds such an incredibly
# high overhead that it makes it impossible to truly do anything.
sig_update_functions() {
  defer_guard_errors

  local -r functions=($(declare -F | sed s/declare\ -f\ //))
  local fn=
  for fn in "${functions[@]}"; do
    if ! contains_map "${__TYPEISH_SIG_MAP}" "${fn}"; then
      log:trace "Found function: \`${fn}\`, which was not in sig map. Not hi-jacking."
      continue
    fi
    if contains_map "${__TYPEISH_REMAPPED_FNS}" "${fn}"; then
      log:trace "Found function: \`${fn}\`, which  was already hijacked. Skipping"
      continue
    fi

    log:trace "Found function: \`${fn}\` which is in sig map and not hijacked -- hijacking."
    local remapped_name="__typeish_do_not_use_seriously_stop_it_dont_no_i_know_youre_thinking_about_it_stop_dont_${__TYPEISH_COUNTER}"
    rename_function "${fn}" "${remapped_name}"
    __TYPEISH_COUNTER=$(( __TYPEISH_COUNTER + 1 ))
    
    local fn_body="function ${fn} () {
"
    local fn_wrapper_map=$(get_map "${__TYPEISH_SIG_MAP}" "${fn}" | tr '$' "$IFS")
    local return_ty=$(get_map "${fn_wrapper_map}" "return_type")
    log:trace "Mapped function: \`${fn}\` returns: \`${return_ty}\`"
    local params=$(get_map "${fn_wrapper_map}" "params" | tr '.' "$IFS")

    local param_names=($(keys_map "${params}"))
    local param_idx=1
    local param=
    for param in "${param_names[@]}"; do
      local param_ty=$(get_map "${params}" "${param}")
      log:trace "Mapped function: \`${fn}\`, found parameter, named: \`${param}\`, typed: \`${param_ty}\`"
      # For each parameter, validate it's type, and then assign it to a local
      # variable.
      #
      # Local variables will automatically go out of scope when our wrapper
      # function exits, and luckily for us unlike users might expect, local
      # doesn't imply can only be accessed in our wrapper function. It's just
      # like any variable visible anywhere, but only for the lifetime of our
      # wrapper function!
      fn_body="${fn_body}
  if ! sig_validate_type_for \"${param_ty}\" \"\${${param_idx}-}\" ; then
    return 1
  fi
  local ${param}=\"\${${param_idx}-}\"
"
      param_idx=$(( param_idx + 1 ))
    done
    fn_body="${fn_body}
  # Call our original function making sure positional args still work.
  local output=
  if ! output=\$(${remapped_name} \"\${@}\"); then
    return 1
  fi
  if ! sig_validate_type_for \"${return_ty}\" \"\$output\"; then
    log:error \"return type was not correct! [\$output] does not match [${return_ty}]\"
    return 1
  fi
  printf '%s' \"\$output\"
  return 0
}"
    eval "$fn_body"
  done
}

fi