#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

ARGV=$@
BIN_NAME=$(basename "${BASH_SOURCE[0]}")

# SOURCE lib/debsrv.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"

# GLOBALS SET BY PARSING ${ARGV}
SUITE=""
# SPACE SEPARATED FIELDS FOR ${COMPONENTS}
COMPONENTS=""


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

function usage() {
    local EOF
    cat << EOF
Remove section, or part(s) of section, from repository.
Usage:
  $ ${BIN_NAME} <SUITE> -c,--comp <C1> <C2>

  <SUITE>)
    Name of repository suite. Required argument.

  -c,--comp)
    Name of one or more components of suite. Optional.

  -h,--help)
    Show this message.

EOF
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    parse_section_args $@
    local comp
    local deb
    local d

    # REMOVE...
    #   a) SPECIFIED ${SUITE},
    #     *AND* IF NO FURTHER OPTON, ALL ${COMPONENTS} OF ${SUITE}
    #   b) IF ${COMPONENTS} SPECIFIED BY OPTION, REMOVE THOSE

    # REMOVE EMPTY ${SUITE} DIRECTORIES FOR:
    #   CACHE
    #   SUITE
    #   CONFIG
    #   INCOMING
    #   POOL
    if [[ -n "${COMPONENTS}" ]]; then
        for comp in ${COMPONENTS}; do
            rm_section ${SUITE} ${comp}
        done
    else
        for comp in $(
            find                             \
                "${CONF_DIR}/suite/${SUITE}" \
                -mindepth 1 -maxdepth 1      \
                -type d -printf "%f\n"
        ); do
            rm_section ${SUITE} ${comp}
        done
    fi

    # SOURCES LIST
    if [[ -d "${CONF_DIR}/suite/${SUITE}" ]] \
    && [[ ! "$(ls -A ${CONF_DIR}/suite/${SUITE})" ]]; then
        # NO SOURCES REMAINING
        rm -v "${SOURCES}/${NAME}-${SUITE}.list"
    else
        write_src_list
    fi

    # REMOVE DIRS IF EMPTY
    find                             \
        "${CACHE}/${SUITE}"          \
        "${DISTRIBUTION}/${SUITE}"   \
        "${CONF_DIR}/suite/${SUITE}" \
        -type d -empty               \
        -exec rmdir -v {} \;

    # POOL
    if [[ ! "$(ls -A ${POOL}/${SUITE})" ]]; then
        rmdir -v "${POOL}/${SUITE}"
    fi

    # INCOMING
    if [[ ! "$(ls -A ${INCOMING}/${SUITE})" ]]; then
        rmdir -v "${INCOMING}/${SUITE}"
    fi

    # STANDBY
    if [[ ! "$(ls -A ${STANDBY}/${SUITE})" ]]; then
        rmdir -v "${STANDBY}/${SUITE}"
    fi
}


main ${ARGV}


