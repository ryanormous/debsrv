#!/bin/bash

# RUN JOBS FOUND IN JOB DIRECTORY

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

# SOURCE lib/config.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/config.sh"

# JOB DIRECTORY
JDIR="${SRV_DIR}/job"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

sleep 1s

for j in $(ls -1 "${JDIR}" | sort -Vr); do
    # JOB SORTED BY VERSION
    "${JDIR}/${j}"
    if (( "$?" == 0 )); then
        rm -v "${JDIR}/${j}" &>>${LOG}
    else
        echo "${j} EXITED BAD" >>${LOG}
        mv -v "${JDIR}/${j}" "${STANDBY}/.job/" &>>${LOG}
    fi
done

