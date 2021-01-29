#!/bin/bash

# SOURCE lib/debsrv.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"

# GLOBALS SET BY PARSING ARGUMENTS
SUITE=""
COMPONENTS=""
PACKAGES=""

ingest_packages $@
