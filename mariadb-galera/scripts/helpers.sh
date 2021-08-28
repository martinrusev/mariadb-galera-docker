#!/bin/bash
set -eo pipefail
shopt -s nullglob

# Constants
RESET='\033[0m'
RED='\033[38;5;1m'
GREEN='\033[38;5;2m'
YELLOW='\033[38;5;3m'
MAGENTA='\033[38;5;5m'
CYAN='\033[38;5;6m'


# logging functions
mysql_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
mysql_note() {
	mysql_log Note "$@"
}
mysql_warn() {
	mysql_log Warn "$@" >&2
}
mysql_error() {
	mysql_log ERROR "$@" >&2
	exit 1
}


# Functions

########################
# Print to STDERR
# Arguments:
#   Message to print
# Returns:
#   None
#########################
stderr_print() {
    # 'is_boolean_yes' is defined in libvalidations.sh, but depends on this file so we cannot source it
    local bool="${BITNAMI_QUIET:-false}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if ! [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        printf "%b\\n" "${*}" >&2
    fi
}

########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
log() {
    stderr_print "${CYAN}${MODULE:-} ${MAGENTA}$(date "+%T.%2N ")${RESET}${*}"
}
########################
# Log an 'info' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
info() {
    log "${GREEN}INFO ${RESET} ==> ${*}"
}
########################
# Log message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
warn() {
    log "${YELLOW}WARN ${RESET} ==> ${*}"
}
########################
# Log an 'error' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
error() {
    log "${RED}ERROR${RESET} ==> ${*}"
}

########################
# Log an 'debug' message
# Arguments:
#   Message to log
# Returns:
#   None
#########################
debug() {
    log "${MAGENTA}DEBUG${RESET} ==> ${*}"
}

########################
# Checks whether a file can be written to or not
# arguments:
#   $1 - file
# returns:
#   boolean
#########################
is_file_writable() {
    local file="${1:?missing file}"
    local dir
    dir="$(dirname "$file")"

    if [[ ( -f "$file" && -w "$file" ) || ( ! -f "$file" && -d "$dir" && -w "$dir" ) ]]; then
        true
    else
        false
    fi
}

########################
# Retries a command a given number of times
# Arguments:
#   $1 - cmd (as a string)
#   $2 - max retries. Default: 12
#   $3 - sleep between retries (in seconds). Default: 5
# Returns:
#   Boolean
#########################
retry_while() {
    local cmd="${1:?cmd is missing}"
    local retries="${2:-12}"
    local sleep_time="${3:-5}"
    local return_value=1

    read -r -a command <<< "$cmd"
    for ((i = 1 ; i <= retries ; i+=1 )); do
        "${command[@]}" && return_value=0 && break
        sleep "$sleep_time"
    done
    return $return_value
}

########################
# Check if the provided argument is a boolean or is the string 'yes/true'
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_boolean_yes() {
    local -r bool="${1:-}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        true
    else
        false
    fi
}

########################
# Ensure a directory exists and, optionally, is owned by the given user
# Arguments:
#   $1 - directory
#   $2 - owner
# Returns:
#   None
#########################
ensure_dir_exists() {
    local dir="${1:?directory is missing}"
    local owner="${2:-}"

    mkdir -p "${dir}"
    if [[ -n $owner ]]; then
        owned_by "$dir" "$owner"
    fi
}

########################
# Check if the script is currently running as root
# Arguments:
#   $1 - user
#   $2 - group
# Returns:
#   Boolean
#########################
am_i_root() {
    if [[ "$(id -u)" = "0" ]]; then
        true
    else
	false
    fi
}

########################
# Check if the provided argument is an empty string or not defined
# Arguments:
#   $1 - Value to check
# Returns:
#   Boolean
#########################
is_empty_value() {
    local -r val="${1:-}"
    if [[ -z "$val" ]]; then
        true
    else
        false
    fi
}

########################
# Checks whether a directory is empty or not
# arguments:
#   $1 - directory
# returns:
#   boolean
#########################
is_dir_empty() {
    local dir="${1:?missing directory}"

    if [[ ! -e "$dir" ]] || [[ -z "$(ls -A "$dir")" ]]; then
        true
    else
        false
    fi
}


########################
# Checks whether a mounted directory is empty or not
# arguments:
#   $1 - directory
# returns:
#   boolean
#########################
is_mounted_dir_empty() {
    local dir="${1:?missing directory}"

    if is_dir_empty "$dir" || find "$dir" -mindepth 1 -maxdepth 1 -not -name ".snapshot" -not -name "lost+found" -exec false {} +; then
        true
    else
        false
    fi
}


########################
# Read the provided pid file and returns a PID
# Arguments:
#   $1 - Pid file
# Returns:
#   PID
#########################
get_pid_from_file() {
    local pid_file="${1:?pid file is missing}"

    if [[ -f "$pid_file" ]]; then
        if [[ -n "$(< "$pid_file")" ]] && [[ "$(< "$pid_file")" -gt 0 ]]; then
            echo "$(< "$pid_file")"
        fi
    fi
}

########################
# Replace a regex in a file
# Arguments:
#   $1 - filename
#   $2 - match regex
#   $3 - substitute regex
#   $4 - use POSIX regex. Default: true
# Returns:
#   None
#########################
replace_in_file() {
    local filename="${1:?filename is required}"
    local match_regex="${2:?match regex is required}"
    local substitute_regex="${3:?substitute regex is required}"
    local posix_regex=${4:-true}

    local result

    # We should avoid using 'sed in-place' substitutions
    # 1) They are not compatible with files mounted from ConfigMap(s)
    # 2) We found incompatibility issues with Debian10 and "in-place" substitutions
    del=$'\001' # Use a non-printable character as a 'sed' delimiter to avoid issues
    if [[ $posix_regex = true ]]; then
        result="$(sed -E "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    else
        result="$(sed "s${del}${match_regex}${del}${substitute_regex}${del}g" "$filename")"
    fi
    echo "$result" > "$filename"
}


#########################
# Redirects output to /dev/null if debug mode is disabled
# Globals:
#   DEBUG
# Arguments:
#   $@ - Command to execute
# Returns:
#   None
#########################
debug_execute() {
    if ${DEBUG}; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

########################
# Check if a provided PID corresponds to a running service
# Arguments:
#   $1 - PID
# Returns:
#   Boolean
#########################
is_service_running() {
    local pid="${1:?pid is missing}"

    kill -0 "$pid" 2>/dev/null
}

########################
# Stop a service by sending a termination signal to its pid
# Arguments:
#   $1 - Pid file
#   $2 - Signal number (optional)
# Returns:
#   None
#########################
stop_service_using_pid() {
    local pid_file="${1:?pid file is missing}"
    local signal="${2:-}"
    local pid

    pid="$(get_pid_from_file "$pid_file")"
    [[ -z "$pid" ]] || ! is_service_running "$pid" && return

    if [[ -n "$signal" ]]; then
        kill "-${signal}" "$pid"
    else
        kill "$pid"
    fi

    local counter=10
    while [[ "$counter" -ne 0 ]] && is_service_running "$pid"; do
        sleep 1
        counter=$((counter - 1))
    done
}
