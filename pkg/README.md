# `pkg/` - Packages Suitable for Third Party Use #

This directory contains a series of functions, that are guaranteed to be loaded
as part of type-ish, but can also be loaded without type-ish. These are each
freestanding libraries that are tested, and validated to work for fairly common
cases.

## `defer.sh` ##

The Defer library implements the `defer` language feature from golang, but for
functions in bash. A couple notes about the defer library:

1. It is unsafe to defer to a function (as if that function defers we will
   loop forever, right now we do our best to disable this as typeish doesn't
   need it, and we want to try and prevent refactors from causing infinite
   loops).
2. There is a common case to set the error mode (`set -e`) for just the scope
   of a function. To make this really easy, and also safer than just a standard
   defer implementation we have created: `defer_guard_errors`, and
   `defer_ignore_errors`. These handle setting error mode for the scope of a
   function for you.
3. Defer's run in a Last In - First Out order. Meaning the last defer that's
   been registered will be run first.

```bash
#!/usr/bin/env bash

set -e

source "defer.sh"

deferBashCommand() {
  defer "ls -lart -hu $(pwd)"
  echo "hihi!"
}

deferCleanup() {
  defer_ignore_errors
  defer "rm /tmp/my-test" # script will not exit because ignore errors is on
  echo "knock knock!"
}

deferFailure() {
  defer_guard_errors # techincally isn't needed since we have set script on -e, but why not!
  defer "false" # this will cause script to exit!
  echo "bye!"
}

deferBashCommand
deferCleanup
deferFailure
```

## `logger.sh` ##

A common logger that makes logging with debugging information much easier.
Specifically by default the logger contains information about how critical
something is, where it came from, and logs to STDERR so it can't be confused
for a return value in bash.

You can define the logging format with the `LOG_FORMAT` environment variable,
the default is: `[{level} @ {file}:{function} / {time}] {message}`
The following variables you can set are:

- `{file}`: the file that generated this log line.
- `{function}`: the function name that generated this log line, if a function
                is active.
- `{level}`: the name of the log level that this message is on.
- `{line}`: the line of the closest function that generated this log line.
- `{message}`: the actual log message being logged.
- `{process}`: the pid of the process that generated this log line.
- `{time}`: the time at which this message was generated.

You can set the log level initially with the environment variable `LOG_LEVEL`,
to change the log level dynamically you should call: `log:level "<new level>"`.
The following log levels are available:

- `trace`: the highest and most in-depth logging level.
- `debug`: contain some debug information without massive amounts of logging.
- `info`: the standard logging level configured, information messages.
- `warn`: warning messages that something may be going wrong.
- `error`: an error message that something has definetly gone wrong.

## `map.sh` ##

A replacement for a "map"/"table"/"associative-array" type for Bashv3 shells
(OSX machines by default have Bash-v3 without the user installing it, and
specifically targeting it).

Maps can be transferred around just as any normal variable, and don't require
anything special. Techincally they're represented as a string array internally
(if you're looking to apply type's to it ;) ).

See the source file for functions, and their definitions.

## `trap.sh` ##

Small utility wrappers to help dealing with the `trap` built-in on bash.
Specifically this allows you to get trapped commands without the weird
quoting of the normal builtin, as well as safely appending to a trap.
By default `trap command SIG` completely clobbers anything that was there.
If you care about compatability as type-ish does, we recommend using this
to append to a trap safely.

See the source file for functions, and their definitions.