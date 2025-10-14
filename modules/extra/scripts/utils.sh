#! /usr/bin/env bash

# shellcheck disable=SC2148
reset=$(tput sgr0)
# shellcheck disable=SC2034
null=/dev/null
declare -A tool_log_colors=(
    [DEFAULT]=""
)
declare -A log_level_colors=(
    [ERROR]=$(tput setaf 1)
    [WARNING]=$(tput setaf 5)
    [INFO]=$(tput setaf 4)
)
declare -A exit_status_codes=(
    [SUCCESS]=0
    [FAILURE]=1
    [INVALID]=2
)

function logfx() {
    local "$@"
    local _file="${_file:-null}" tool="${tool:-DEFAULT}" level="${level:-INFO}" prefix=

    # Catch invalid function calls
    if [[ ! -v tool_log_colors[$tool] ]]; then
        message="'$tool' is not a valid tool among: ${!tool_log_colors[*]}"
        logfx level=ERROR exit_status=INVALID <<<"$message"
    fi
    if [[ ! -v log_level_colors[$level] ]]; then
        message="'$level' is not a valid log level among: ${!log_level_colors[*]}"
        logfx level=ERROR exit_status=INVALID <<<"$message"
    fi
    if [[ -v exit_status && ! -v exit_status_codes[$exit_status] ]]; then
        message="'$exit_status' is not a valid exit status among: ${!exit_status_codes[*]}"
        logfx level=ERROR exit_status=INVALID <<<"$message"
    fi

    # Build the logging prefix
    if [[ $level != INFO ]]; then
        prefix="${log_level_colors[$level]}$level$reset $prefix"
    fi
    if [[ $tool != DEFAULT ]]; then
        prefix="${tool_log_colors[$tool]}$tool$reset $prefix"
    fi

    # Log stderr
    tee -a "${!_file}" | sed "s/^/$prefix /" 1>&2

    # Exit the program if specified
    if [[ -v exit_status ]]; then
        exit "${exit_status_codes[$exit_status]}"
    fi
}

get_duplicates() {
    if [[ $# -ne 1 ]]; then
        logfx log_level=ERROR exit_status=INVALID <<<"You must pass an existing array name to 'get_duplicates'"
    fi
    local -n array=$1
    printf '%s\0' "${array[@]}" | sort --zero-terminated | uniq --zero-terminated --repeated
}

has_duplicates() {
    if [[ $# -ne 1 ]]; then
        logfx log_level=ERROR exit_status=INVALID <<<"You must pass an existing array name to 'has_duplicates'"
    fi
    local duplicates
    readarray -td '' duplicates < <(get_duplicates "$1")
    if ((${#duplicates[@]} > 0)); then
        return 0
    else
        return 1
    fi
}

contains() {
    if [[ $# -ne 2 ]]; then
        logfx log_level=ERROR exit_status=INVALID <<<"You must pass a value and an array name only to 'contains'"
    fi
    local -n array=$2
    # shellcheck disable=SC2034
    contains_array=("$1" "${array[@]}")
    has_duplicates contains_array
}

has_intersection() {
    if [[ $# -lt 2 ]]; then
        logfx log_level=ERROR exit_status=INVALID <<<"You must pass multiple values to 'contains_any'"
    fi

    has_intersection_array=()
    for name in "$@"; do
        local -n array=$name
        has_intersection_array+=("${array[@]}")
    done
    has_duplicates has_intersection_array
}

"$@"
