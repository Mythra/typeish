# Type-ish #

Type-ish is a runtime type checker for bash functions, implemented entirely in
bash. This way you can accept arguments, and be sure they conform to whatever
sort of shape you want them too. ***It is also a very cursed idea taken way too far,
and I do not apologize for it.***

***NOTE: as of this moment type-ish has only been tested on bashv4 everything
should be compatible with bashv3 (what OSX ships), but I haven't actually
tested it out yet.***

In essence type-ish allows you to runtime type your functions with
type-signatures like:

```bash
#!/usr/bin/env bash

set -euo pipefail
source "typeish.sh"

sig {always_fails.returns { number }}
always_fails() {
  echo "hi" # This will always fail cause it doesn't return a number!
}

sig { add_numbers.params { a: number, b: number }.returns{ number }}
add_numbers() {
  printf '%s' "$((a + b))"
}

sig_update_functions # Actually process the functions that have signatures!
                     # This is separate so you can avoid runtime overhead
                     # if you don't want to pay for it all the time!
add_numbers "a" "2" || echo "Failed to add the letter! didn't pass the type check!"
add_numbers "1" "2" && echo " Successfully was able to add numbers!"
always_fails
```

This will print the following for you:

```
[error @ typeish.sh:sig_validate_type_for / {TIMESTAMP}] Argument: `a` is NaN, but was asked to be number/boolean.
Failed to add the letter! didn't pass the type check!
3 Successfully was able to add numbers!
[error @ typeish.sh:sig_validate_type_for / {TIMESTAMP}] Argument: `hi` is NaN, but was asked to be number/boolean.
[error @ typeish.sh:always_fails / {TIMESTAMP}] return type was not correct! [hi] does not match [number]
```

To use it's as simple as:


1. Load in `typeish.sh`.
2. Define a series of signatures for your functions.
3. Define your functions.
4. Call `sig_update_functions` to tell type-ish to update the list of functions to type-check.
5. Run your code as normal!

That's not all though! There are lots of cool things below -- like define'ing
your own types, generics, type generation, and making type-checking optional
so you don't always have to pay the perf overhead!

## Sig's ##

Signatures are the core part of type-ish, they allow defining the actual
parameter names/types+return types of any arbitrary function. They follow
the general format of:

- `sig {function_name_i_apply_too.params { param_name: param_type, other_param: param_type_two }.returns { a_type }}`

A couple things to note here:

1. The function name determines what function this applies too, nothing else
   does. Yes this means signatures are completely disjoint from the actual
   functions, so yes you can stick the signature definitions behind an if
   branch -- this is useful if wanting to avoid the performance overhead of
   typeish in certain situations.
2. `params {}`, and `returns {}` are optional, if you do not define them they
   are both expected to return + accept `void` which is short for nothing.
   (note: since STDOUT is where you return values, if you have a void return
   type this means you can't print anything to STDOUT, you should print to
   STDERR).
3. Parameters map to their order (e.g. `param_name` will be equivalent to
   `$1`), and you can reference it either by its name, or position.
4. All types have to be known at the time `sig {}` is written, the builtin
   types are:
   - `void`: the absence of a value.
   - `string`: in bash everything is a string, so this is basically an any
               type.
   - `number`: any type of number (including decimals! and including
               signs `-`, or `+`)
   - `boolean`: a shortcut for returning a number (as numbers are booleans).
   - `array[ty]`: an array which can hold any type (yes the inner array values
                  are validated!)
5. The "sig" line is actually a valid bash function! Calling it with a whole
   bunch of string arguments! Meaning ***you can actually generate eval calls
   to sig where you actually fully generate the signature pragmatically***!
   Yes this is probably a bad idea, but WHY NOT.

## Custom Types ##

Type-ish allows defining custom types. Which in reality is just a way of doing
checked casting from one type to another. These types can also be generic,
and have multiple types in the generic (like if you want a map type)!

First let's start out with the simple case, a very simple type:

```bash
sig_custom_type { forced_start.from { string }.produces { ForcedStartTy } }
forced_start() {
  case "$1" in
    "["*)
      return 0
      ;;
    *)
      log:error "String: \`$1\` does not start with '[', not valid."
      return 1
      ;;
  esac
}
```

In this case we define a conversion from `string` -> `ForcedStartTy`, this is
how you introduce a new type. We tell type-ish to call `forced_start` every time
it needs to check if a string is a valid `ForcedStartTy` it will be passed a
single parameter which is the value to check, this will return an error if the
type is not a valid cast, otherwise it will return 0, signaling this is okay.

Sig Custom Type otherwise has the very similar behavior to sig, it just uses
`from`, and `produces` rather than `params`, and `returns`.

A couple notes:

1. It is only possible to have one conversion from Type A -> Type B. You cannot
   register multiple conversions for the same type (call it something else)!.
2. While it is possible to have many types all convert into another type, this
   gets expensive very very fast (as we have to check each conversion in the
   order it was registered)! In general try to see if you can just use a
   different type name (maybe even borrow that old golang egyptian brackets
   trick(!) -- _yes this is a terrible idea, but just as terrible as the rest
   of this_).

### Generic's ###

It is possible to register generic types in `sig_custom_type`, by doing so you
inherit a lot of responsibility, but it's worth it for generics, _probably_.
A generic is identified by having it's produces block be in the form of:
`.produces { Map_generic }`, in this case you will have a type called `Map`
that can be used as a generic.

In this case your first argument will the value to typecheck, and the second
will be a generic type if any is present.

Notes:

1. Type-ish does not guarantee that a generic type has to have defined what
   type it's holding. If you need type parameters/a specific amount of them
   it is on you to validate it.
2. You cannot nest generics in generics.
3. If you need to accept multiple concrete types such as a map which has a key,
   and a value you need to use the `-` character: `Map[number-string]`.
   _yes i realize this is a bad choice, but I didn't really have a better
   character because many others are reserved internally._
4. You take on the responsibility of calling the validation for the inner type
   you are holding. If you do not, you can introduce a type error, and it'll
   be bad.

As an example implementation take a definition of map (which is just an array
with a special identifier at the beginning, and methods to interact with the
array):

```bash
sig { does_start_with_map_id.params { map: string }.returns { void } }
does_start_with_map_id() {
  # <snipped>
}
sig { split.params { to_split: string, split_by: string }.returns { array[string] } }
split() {
  # <snipped>
}
sig { keys_map.params { map: string }.returns { array[string] } }
keys_map() {
  # <snipped>
}
sig { values_map.params { map: string }.returns { array[string] } }
values_map() {
  # <snipped>
}

sig_custom_type { map_ty.from { string }.produces { Map_generic } }
map_ty() {
  # Check map starts with __MAP_ID
  if ! does_start_with_map_id "$1"; then
    log:error "Type isn't actually a valid map!"
    return 1
  fi
  if [ "x${2+x}" == "x" ]; then
    # No generic types on this map exit early.
    log:warn "Map called with no generic types -- which were expected."
    return 0
  fi
  local -r generic_types=($(split "$2" "-"))
  
  # Validate keys!
  if [ "x${generic_types[0]}" != "x" ]; then
    log:trace "Validating map key type against type: ${generic_types[0]}"
    local keys=($(keys_map "$1"))
    local key=
    for key in "${keys[@]}"; do
      if ! sig_validate_type_for "${generic_types[0]}" "${key}"; then
        log:error "Key of map: \`${key}\` was not valid for type: ${generic_types[0]}"
        return 1
      fi
    done
  fi
  # Validate values!
  if [ "x${generic_types[1]}" != "x" ]; then
    log:trace "Validating map value type against type: ${generic_types[1]}"
    local values=($(values_map "$1"))
    local value=
    for value in "${values[@]}"; do
      if ! sig_validate_type_for "${generic_types[1]}" "${value}"; then
        log:error "Value of map: \`${value}\` was not valid for type: ${generic_types[1]}"
        return 1
      fi
    done
  fi

  # We all good!
  return 0
}
```

In this case the `log:${level}` functions, and `sig_validate_type_for` are
provided by type-ish. The rest the user wrote to validate a map.

## Performance ##

First off, type-ish has prettttty high overhead. There's just a lot we're
doing, and that comes at a huge price. In order to make this cost easier
to digest though we've made it so all parts of type-ish are opt-in.

First off the "biggest hammer" not paying the cost for sig parsing +
type-checking:

```bash
#!/usr/bin/env bash

set -e

add_numbers() {
  local -r first_num=$1
  local -r second_num=$2
  printf '%d' "$(( first_num + second_num ))"
}

if [ "x$ENABLE_TYPEISH" != "x" ]; then
  source "path/to/typeish.sh"
  sig { add_numbers.params { num_one: number, num_two: number }.returns { number } }
  sig_update_functions
fi

add_numbers "1" "2"
```

In this case type-ish will not be loaded, parsed, or impact loading in
anyway. Note the use of `$1`/`$2` instead of the names provided by type-ish,
this allows for compatibility when type-ish isn't loaded, and hasn't set
those variable names. _this can also be used as a way to feature detect, and
do something if type-ish is loaded vs not_.

There is a second option which is to still parse `sig` lines so you can ensure
they're not typo'd but not impact the actual function timings themselves (you
will only pay a small load cost to parse the signatures), this also is a bit
cleaner to write:

```bash
#!/usr/bin/env bash

set -e

source "path/to/typeish.sh"

sig { add_numbers.params { num_one: number, num_two: number }.returns { number } }
add_numbers() {
  local -r first_num=$1
  local -r second_num=$2
  printf '%d' "$(( first_num + second_num ))"
}

if [ "x$ENABLE_TYPEISH" != "x" ]; then
  sig_update_functions
fi

add_numbers "1" "2"
```

In this case we load type-ish, and let it parse the `sig` to validate it's
well formed, and also look nice. But we never call `sig_update_functions` so
type-ish unless asked too, which means we never actually start doing the
type-checking. As a result we still have to use positional arguments, since
type-ish may not be actually doing something on our function.

Overall these two knobs should help you keep the performance of type-ish in
check.

## I Hate This ##

The feeling is mutual.

## Why? ##

:)