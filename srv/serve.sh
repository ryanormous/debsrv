#!/bin/bash


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

# SOURCE lib/config.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/config.sh"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

cd ${ROOT}

# BUSYBOX OPTIONS
#   -f            Don't daemonize
#   -v[v]         Verbose
#   -p [IP:]PORT  Bind to IP:PORT (default *:80)
${BBOX} httpd -f -${VERB} -p ${IP}:${PORT} -c ${CONF_DIR}/httpd/httpd.conf 2>>${LOG}

