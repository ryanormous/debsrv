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
Rotate log at this path: ${LOG}
Also see: ${CONF_DIR}/logrotate/configuration
Usage:
  $ ${BIN_NAME}

  -h,--help)
    Show this message.

EOF
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    # HELP
    if grep -iq '\-h\|\-\-help' <<<"$@"; then
        usage
        exit 0
    fi
    rotate_log &>>${LOG}
}


main ${ARGV}

