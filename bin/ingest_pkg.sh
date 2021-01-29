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
Add 1 or more debian package(s) to archive.
Packages must be found at the incoming path for suite.
E.g. ${INCOMING}/<SUITE>/<COMPONENT>/

Usage:
  $ ${BIN_NAME} <SUITE> -c,--comp <C1> <C2> -p,--pack <P1> <P2>

  <SUITE>)
    Name of repository suite. Required argument.

  -c,--comp)
    Name of one or more components of suite. Optional.
    If not specified, packages are ingested from
    all components of suite.

  -p,--packages)
    Name of one or more packages to ingest. Optional.
    If not specified, packages are ingested from
    specified components, if any.

  -h,--help)
    Show this message.

EOF
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

# GOTTA BE ROOT
privilege
ingest_packages $@


