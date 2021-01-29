#!/bin/bash

#TODO: show architectures for component

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

ARGV=$@
BIN_NAME=$(basename "${BASH_SOURCE[0]}")

# SOURCE lib/debsrv.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

function usage() {
    local EOF
    cat << EOF
List sections for repository.

Options:
  -h,--help)
    Show this message.

EOF
}


function find_sections() {
    local conf="${CONF_DIR}/suite"
    find ${conf}                \
        -mindepth 1 -maxdepth 1 \
        -type d -empty          \
        -printf "%f\n"
    find ${conf}                \
        -mindepth 2 -maxdepth 2 \
        -type d                 \
        -printf "%P\n"
}


function list_sections() {
    echo -e "\033[4mSUITE\033[0m\t\033[4mCOMPONENT\033[0m"
    find_sections | sort | sed 's/\//\t/g'
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    # ARGUMENTS
    if grep -iq '\-h\|\-\-help' <<<"$@"; then
        usage
        exit 0
    fi
    list_sections | column -t
}


main ${ARGV}

