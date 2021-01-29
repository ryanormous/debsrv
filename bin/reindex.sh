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
Reindex section, or part(s) of section.
Use to repair indexes after unanticipated file change.
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
    # GOTTA BE ROOT
    privilege

    parse_section_args $@
    local comp
    local deb
    local conf_dir="${CONF_DIR}/suite/${SUITE}"

    # REINDEX...
    #   a) SPECIFIED ${SUITE},
    #     *AND* IF NO FURTHER OPTON, ALL ${COMPONENTS} OF ${SUITE}
    #   b) IF ${COMPONENTS} ARE SPECIFIED BY OPTION, REINDEX THOSE

    if [[ -n "${COMPONENTS}" ]]; then
        for comp in ${COMPONENTS}; do
            # INDEX
            index_pkgs ${comp}
            # TRY "CLEANING" COMPONENT DATABASE
            ${APTARC}                                 \
                -o="APT::FTPArchive::AlwaysStat=true" \
                -c="${conf_dir}/${comp}/archive.conf" \
                clean "${conf_dir}/${comp}/packages.conf"
        done
    else
        # POOL DIRECTORY
        for comp in $(ls "${POOL}/${SUITE}"); do
            # INDEX
            index_pkgs ${comp}
            # TRY "CLEANING" COMPONENT DATABASE
            ${APTARC}                                 \
                -o="APT::FTPArchive::AlwaysStat=true" \
                -c="${conf_dir}/${comp}/archive.conf" \
                clean "${conf_dir}/${comp}/packages.conf"
        done
    fi
}


main ${ARGV}

