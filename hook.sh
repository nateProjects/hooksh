#!/usr/bin/env bash

# Set default values for environment variables
export HOOK_LOG="${HOOK_LOG:-false}" # Determines whether logging is enabled or not. It defaults to false if not set.
export HOOK_LOG_FUNC="${HOOK_LOG_FUNC:-_hook_log_msg}" # Specifies the function to be used for logging. It defaults to _hook_log_msg if not set.
export HOOK_PREFIX=${HOOK_PREFIX:-hook_} #  Sets the prefix for hook function names. It defaults to hook_ if not set.
export HOOK_GLOBAL_PREFIX=${HOOK_GLOBAL_PREFIX:-global_} # Sets the prefix for global hook function names. It defaults to global_ if not set.
export HOOK_FILE="${HOOK_FILE:-./hooks.sh}" # Specifies the path to the local hook file. It defaults to ./hooks.sh if not set.
export HOOK_GLOBAL_FILE="${HOOK_GLOBAL_FILE:-}" # Specifies the path to the global hook file. It defaults to an empty string if not set.
export HOOK_LAST_EXIT_CODE #  Stores the last exit code of the executed command.

hook() {
  # Declare arrays to store functions before and after hook execution
  local -a functions_before_hook
  local -a functions_after_hook
  HOOK_LAST_EXIT_CODE=''

  # Get the list of functions before hook execution
  mapfile -t functions_before_hook < <(declare -F | sed 's/declare -f //g')

  # Check if a global hook file is defined and source it if it exists
  if [[ ${HOOK_GLOBAL_FILE} != "" ]]; then
    if [[ -f "${HOOK_GLOBAL_FILE:?}" ]]; then
      _hook_log DEBUG "sourcing global hook file (${HOOK_GLOBAL_FILE:?})"
      # shellcheck source=/dev/null
      source "${HOOK_GLOBAL_FILE:?}"
    else
      _hook_log WARN "global hook file not found (${HOOK_GLOBAL_FILE:?})"
    fi
  else
    _hook_log TRACE "no global hook file defined"
  fi

  # Check if a hook file is defined and source it if it exists
  if [[ -f "${HOOK_FILE:?}" ]]; then
    _hook_log DEBUG "sourcing hook file (${HOOK_FILE:?})"
    # shellcheck source=/dev/null
    source "${HOOK_FILE:?}"
  else
    _hook_log WARN "hook file not found (${HOOK_FILE:?})"
  fi

  # Get the list of functions after hook execution
  mapfile -t functions_after_hook < <(declare -F | sed 's/declare -f //g')

  # Execute the "pre" hook with the provided arguments
  _hook "${HOOK_PREFIX:?}pre" "$@"

  # Execute the original command with the provided arguments
  "$@"
  HOOK_LAST_EXIT_CODE=$?

  # Execute the "post" hook with the provided arguments
  _hook "${HOOK_PREFIX:?}post" "$@"

  # Iterate over the functions after hook execution
  for f in "${functions_after_hook[@]}"; do
    # Check if the function starts with "hook_"
    if [[ "${f:-}" =~ ^hook_\.* ]]; then
      # Check if the function was not present before hook execution
      if ! _hook_array_contains "${f:-}" "${functions_before_hook[@]}"; then
        # Unset the function
        unset -f "${f:-}"
      fi
    fi
  done

  # Return the last exit code
  return ${HOOK_LAST_EXIT_CODE:?}
}

_hook() {
  local prefix="${1:?'A prefix must be given'}"
  shift

  local index # Stores the current index during argument iteration.
  local -a args # An array to store the arguments passed to the function.
  local arg # Stores the current argument being processed.
  local rest_args_start # Stores the starting index of the remaining arguments.
  local rest_args_end # Stores the ending index of the remaining arguments.
  local -a rest_args # An array to store the remaining arguments.
  local hook_func # Stores the name of the hook function to be executed.

  args=("$@") # Assigns the positional arguments passed to the function to the args array.
  hook_func="${prefix}" # Initializes hook_func with the value of the prefix parameter.

  # Execute the hook function with the provided arguments
  _hook_exec "${hook_func:?}" "${args[@]}"

  # Iterate over the arguments
  for ((index = 0; index < ${#args[@]}; index++)); do
    arg="${args[index]}"
    if [[ "${arg}" != '' ]]; then
      rest_args_start=${index+1}
      rest_args_end=${#args[@]}
      rest_args=("${args[@]:${rest_args_start:?}:${rest_args_end:?}}")

      # Construct the hook function name by appending the argument
      hook_func="${hook_func:?}_${arg:?}"

      # Execute the hook function with the remaining arguments
      _hook_exec "${hook_func:?}" "${rest_args[@]}"
    fi
  done
}

_hook_exec() {
  local hook_func="${1:?'A hook function must be provided!'}"
  shift

  # Check if the global hook function exists and execute it
  if [[ "$(type -t "${HOOK_GLOBAL_PREFIX:?}${hook_func:?}")" == 'function' ]]; then
    _hook_log INFO "executing \"${HOOK_GLOBAL_PREFIX:?}${hook_func}\" (${HOOK_GLOBAL_FILE})"
    "${HOOK_GLOBAL_PREFIX:?}${hook_func:?}" "$@"
    _hook_log DEBUG "finished executing \"${HOOK_GLOBAL_PREFIX:?}${hook_func}\" (${HOOK_GLOBAL_FILE})"
  fi

  # Check if the hook function exists and execute it
  if [[ "$(type -t "${hook_func:?}")" == 'function' ]]; then
    _hook_log INFO "executing \"${hook_func}\" (${HOOK_FILE:?})"
    "${hook_func:?}" "$@"
    _hook_log DEBUG "finished executing \"${hook_func}\" (${HOOK_FILE:?})"
  fi
}

_hook_array_contains() {
  local -r needle="$1" # Stores the value to be searched for in the array. It is declared as read-only (-r) to prevent modification.
  shift # Shifts the positional arguments to the left, removing the first argument ($1)
  local -ra haystack=("$@") # An array to store the remaining arguments after shifting. It is declared as read-only (-r) to prevent modification
  local item # Stores the current item being processed during array iteration.

  # Check if the needle exists in the haystack array
  for item in "${haystack[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

_hook_log() {
  # Log a message if the log level is ERROR or if HOOK_LOG is set to true
  if [[ "$1" == 'ERROR' || "${HOOK_LOG}" == 'true' && "${HOOK_LOG_FUNC}" != '' ]]; then
    "${HOOK_LOG_FUNC:?}" "$@" || true
  fi
}

_hook_log_msg() {
  # Format and output the log message
  echo "[hook] [$1] ${*:2}"
}
