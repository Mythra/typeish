#!/usr/bin/env bash

# __sig_type_exists(type: string) -> boolean
#
# Modifies Globals: None
#
# Determine if a type is a known type. This mainly exists to make it easy for
# checking for generic_types
__sig_type_exists() {
  defer_guard_errors

  local -r type_to_check="$1"
  log:trace "Checking if type exists: ${type_to_check}"

  if contains_map "${__TYPEISH_TYPE_MAP}" "${type_to_check}"; then
    return 0
  fi

  # check for generic types.
  case "${type_to_check}" in
    *"["*"]"*)
      local -r types=($(printf '%s' "${type_to_check}" | sed 's/\[/ /' | sed 's/\]/ /' | tr ' ' "$IFS"))
      # Generics can only be nested one level, reject otherwise invalid types.
      if [ "${#types[@]}" -ne "2" ]; then
        log:debug "Unsupported generic more than two values as expected: ${types[@]}"
        return 1
      fi
      # Next check the type is not only generic, but contains a valid generic'd type.
      if ! contains_map "${__TYPEISH_TYPE_MAP}" "${types[0]}_generic"; then
        log:debug "Type is not generic: ${types[0]} (not registered as: \`${types[0]}_generic\`), and cannot be considered as one."
        return 1
      fi

      # Finally check if all the inner types are valid.
      #
      # Inner types can be seperated by `-` for things like Maps, which have
      # multiple types.
      local -r inner_types=($(__typeish_str_split "${types[1]}" "-"))
      local inner_type=
      for inner_type in "${inner_types[@]}"; do
        if ! contains_map "${__TYPEISH_TYPE_MAP}" "${inner_type}"; then
          log:debug "Type that was in generic is not known: \`${types[1]}\`"
          return 1
        fi
      done

      return 0
      ;;
  esac

  return 1
}