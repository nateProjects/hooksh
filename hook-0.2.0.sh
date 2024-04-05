#!/usr/bin/env bash

# Default configuration
HOOK_FILE="${HOOK_FILE:-./hooks.sh}" # Specifies the path to the local hook file. It defaults to ./hooks.sh if not set.
HOOK_PREFIX="${HOOK_PREFIX:-hook_}" #  Sets the prefix for hook function names. It defaults to hook_ if not set.
HOOK_GLOBAL_FILE="${HOOK_GLOBAL_FILE:-}"  # Specifies the path to the global hook file. It defaults to an empty string if not set.
HOOK_GLOBAL_PREFIX="${HOOK_GLOBAL_PREFIX:-global_}" # Sets the prefix for global hook function names. It defaults to global_ if not set.
HOOK_LOG="${HOOK_LOG:-false}" # Determines whether logging is enabled or not. It defaults to false if not set.
HOOK_LOG_FUNC="${HOOK_LOG_FUNC:-_hook_log_msg}" # Specifies the function to be used for logging. It defaults to _hook_log_msg if not set.

# Run the hook
run_hook() {
  local hook_type="$1" # This line assigns the value of the first argument ($1) to the local variable hook_type. It represents the type of hook being run, either "pre" or "post".
  shift # This command shifts the positional parameters to the left by one position. It effectively removes the first argument ($1) from the list of arguments, so the subsequent arguments can be accessed using $1, $2, etc.
  local command="$1" # After the first shift, the original second argument becomes the new first argument. This line assigns the value of the new first argument to the local variable command. It represents the command being hooked.
  shift
  local args=("$@") # This line assigns all the remaining arguments (after the second shift) to the local array variable args. The $@ expands to the list of all remaining arguments, and the parentheses () create an array with those arguments.

  # Source global hooks file if specified
  if [[ -n "$HOOK_GLOBAL_FILE" && -f "$HOOK_GLOBAL_FILE" ]]; then
    _hook_log "DEBUG" "Sourcing global hook file: $HOOK_GLOBAL_FILE"
    source "$HOOK_GLOBAL_FILE"
  fi

  # Source local hooks file if specified
  if [[ -f "$HOOK_FILE" ]]; then
    _hook_log "DEBUG" "Sourcing local hook file: $HOOK_FILE"
    source "$HOOK_FILE"
  fi

  # Run pre-hook
  if [[ "$hook_type" == "pre" ]]; then
    _run_hook_func "${HOOK_PREFIX}pre" "$command" "${args[@]}"
  fi

  # Run the command
  "$command" "${args[@]}"
  local exit_code=$?

  # Run post-hook
  if [[ "$hook_type" == "post" ]]; then
    _run_hook_func "${HOOK_PREFIX}post" "$command" "${args[@]}"
  fi

  return $exit_code
}

# Run the hook function
_run_hook_func() {
  local hook_prefix="$1"
  local command="$2" 
  shift 2
  local args=("$@")

  # Check for global hook function
  local global_hook_func="${HOOK_GLOBAL_PREFIX}${hook_prefix}_${command}"
  if _is_function "$global_hook_func"; then
    _hook_log "INFO" "Running global hook function: $global_hook_func"
    "$global_hook_func" "${args[@]}"
  fi

  # Check for local hook function
  local hook_func="${hook_prefix}_${command}"
  if _is_function "$hook_func"; then
    _hook_log "INFO" "Running local hook function: $hook_func"
    "$hook_func" "${args[@]}"
  fi
}

# Check if a function exists
_is_function() {
  local func_name="$1"
  [[ "$(type -t "$func_name")" == "function" ]]
}

# Log a message
_hook_log() {
  local log_level="$1"
  local message="$2"

  if [[ "$HOOK_LOG" == "true" ]]; then
    "$HOOK_LOG_FUNC" "$log_level" "$message"
  fi
}

# Default log function
_hook_log_msg() {
  local log_level="$1"
  local message="$2"
  echo "[hook] [$log_level] $message"
}

# Run pre-hook and post-hook
hook() {
  run_hook "pre" "$@"
  local exit_code=$?
  run_hook "post" "$@"
  return $exit_code
}
