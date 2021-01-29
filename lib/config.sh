#!/bin/bash

# NAME
NAME="debsrv"

# ROOT DIRECTORY
ROOT="/opt/${NAME}"

# USER + GROUP
USERNAME="www-data"
GROUPNAME="www-data"
OWNER="${USERNAME}:${GROUPNAME}"

# SECTION INFO
ORIGIN=${NAME}
CODENAME="sid"

# ALIAS
CACHE="${ROOT}/.cache"
DISTRIBUTION="${ROOT}/dists"
INCOMING="${ROOT}/incoming"
POOL="${ROOT}/pool"
SOURCES="${ROOT}/sources.list.d"
STANDBY="${ROOT}/standby"

# PATHS
BIN_DIR="${ROOT}/bin"
CONF_DIR="${ROOT}/.config"
DOC_DIR="${ROOT}/doc"
GPG_DIR="${CONF_DIR}/gpg"
SRV_DIR="${ROOT}/srv"
LOG_DIR="${ROOT}/log"
PUB_DIR="${ROOT}/gpg"

# LOG FILE
LOG="${LOG_DIR}/debsrv.log"

# SERVICE ADDRESS
IP="127.0.0.1"
PORT="8888"

# SERVICE VERBOSITY
VERB="vvv"

# APT EXECUTABLES
APTARC="/usr/bin/apt-ftparchive"
APTCFG="/usr/bin/apt-config"
APTGET="/usr/bin/apt-get"
APTKEY="/usr/bin/apt-key"

# BUSYBOX EXECUTABLE
BBOX="/usr/bin/busybox"

# NULL
NULL="/dev/null"
if [[ ! -w "${NULL}" ]]; then
    mknod -m 666 ${NULL} -c 2 2
fi

# DEFAULT VALUES FOR...
#   ${COMPONENTS}
#   ${ARCHITECTURES}
# USED FOR add_section.sh
# NOTE: MULTIPLE FIELDS MAY BE GIVEN IF SPACE-SEPARATED
DEFAULT_ARCHITECTURES=$(
    sed -z 's/\n/\ /g' "/var/lib/dpkg/arch" | sed 's/\s$//'
)
DEFAULT_COMPONENTS="main"

