#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

BIN_NAME=$(basename "${BASH_SOURCE[0]}")

# SOURCE lib/debsrv.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"

# GLOBALS SET BY PARSING ARGUMENTS
SUITE=""
COMPONENTS=""
PACKAGES=""


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

function usage() {
    local EOF
    cat << EOF
Remove 1 or more debian package(s) from archive.

Usage:
  $ ${BIN_NAME} <SUITE> -c,--comp <C1> <C2> -p,--pack <P1> <P2>

  <SUITE>)
    Name of repository suite. Required argument.

  -c,--comp)
    Name of one or more components of suite from which packages will be removed.
    Required.

  -p,--packages)
    Name of one or more packages to remove.
    Required.

  -h,--help)
    Show this message.

EOF
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

# GOTTA BE ROOT
privilege
egest_packages $@


