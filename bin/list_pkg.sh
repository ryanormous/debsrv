#!/bin/bash

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
List sections and packages for repository.

Options:
  -h,--help)
    Show this message.

EOF
}


function find_archive_pkgs() {
    local sec
    echo -e "\033[4mSUITE\033[0m\t\033[4mCOMPONENT\033[0m\t\033[4mPACKAGE\033[0m"
    for sec in $(
        find ${POOL}                \
            -maxdepth 2 -mindepth 2 \
            -type d -not -empty     \
            -printf "%P\n"
    ); do
        find ${POOL}/${sec}         \
            -mindepth 2 -maxdepth 2 \
            -type f -name "*.deb"   \
            -printf "${sec/\//\ }\t%f\n"
    done | sort
}


function find_standby_pkgs() {
    local sec
    echo -e "\033[4mSUITE\033[0m\t\033[4mCOMPONENT\033[0m\t\033[4mPACKAGE\033[0m"
    for sec in $(
        find ${STANDBY}             \
            -maxdepth 2 -mindepth 2 \
            -type d -not -empty     \
            -printf "%P\n"
    ); do
        find ${STANDBY}/${sec}      \
            -mindepth 1 -maxdepth 1 \
            -type f -name "*.deb"   \
            -printf "${sec/\//\ }\t%f\n"
    done | sort
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    # ARGUMENTS
    if grep -iq '\-h\|\-\-help' <<<"$@"; then
        usage
        exit 0
    fi

    echo -e "\033[7m ARCHIVED PACKAGES \033[0m"
    find_archive_pkgs | column -t

    echo -e "\n\033[7m STANDBY PACKAGES \033[0m"
    find_standby_pkgs | column -t
}


main ${ARGV}

