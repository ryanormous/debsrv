#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

BIN_NAME=$(basename "${BASH_SOURCE[0]}")

# SOURCE lib/config.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"

# TOP LEVEL DIRECTORIES
CGI="${ROOT}/cgi-bin"
LIB="${ROOT}/lib"
SYSTEMD="${ROOT}/systemd"
WWW="${ROOT}/www"
DIRS=(
    ${ROOT}
    ${CACHE}
    ${CGI}
    ${DISTRIBUTION}
    ${INCOMING}
    ${LIB}
    ${POOL}
    ${SOURCES}
    ${STANDBY}
    ${SYSTEMD}
    ${WWW}
    ${BIN_DIR}
    ${CONF_DIR}
    ${DOC_DIR}
    ${GPG_DIR}
    ${SRV_DIR}
    ${LOG_DIR}
    ${PUB_DIR}
    "${CONF_DIR}/httpd"
    "${CONF_DIR}/logrotate"
    "${CONF_DIR}/suite"
    "${SRV_DIR}/job"
    "${STANDBY}/.job"
    "${ROOT}/doc"
)
FUNCTIONALITY=""

# SYSTEMD UNIT DIRECTORY
UNIT_DIR=$(
    pkg-config --variable=systemdsystemunitdir systemd
)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# CONFIGURATION FUNCTIONS

# USAGE
function usage() {
    local EOF
    cat << EOF
Usage:
${BIN_NAME} sets up files and directories at this path: ${ROOT}
Optionally, ${BIN_NAME} can also teardown most of the paths it creates.
Note that archived packages are not deleted, but moved to standby directory.

  -i,--install)
    Default functionality.

  -u,--uninstall)
    Optional.

  -h,--help)
    Shows this message.
EOF
}


function parse_args() {
    # DEFAULT
    if (( "$#" == 0 )); then
        FUNCTIONALITY="setup"
    # HELP
    elif grep -iq '\-h\|\-\-help' <<<"$@"; then
        usage
        exit 0
    # UNINSTALL
    elif grep -iq '\-u\|\-\-uninst' <<<"$@"; then
        FUNCTIONALITY="teardown"
    # UNINSTALL
    elif grep -iq '\-i\|\-\-inst' <<<"$@"; then
        FUNCTIONALITY="setup"
    else
        usage
        exit 1
    fi
}


function require_path() {
    local exe
    local msg="ERROR. MISSING REQUIRED EXECUTABLE:"
    for exe in    \
        ${APTARC} \
        ${APTCFG} \
        ${APTGET} \
        ${APTKEY} \
        ${BBOX}
    do
        if [[ ! -e "${exe}" ]]; then
            echo ${msg} ${exe}
            exit 1
        fi
    done
}


# LOGROTATE CONFIGURATION
function write_logrotate_conf() {
    local conf="${CONF_DIR}/logrotate/configuration"
    local rotate="2" # DEFAULT
    local unxz_cmd=$(which unxz)
    local xz_cmd=$(which xz)
    local EOF

    cat << EOF > ${conf}
${LOG_DIR}/*.log {
    compress
    compresscmd ${xz_cmd}
    create 644 root root
    size 2M
    missingok
    notifempty
    rotate ${rotate}
    uncompresscmd ${unxz_cmd}
}
EOF
    chown -v ${OWNER} ${conf}
}


# HTTPD CONFIGURATION
function write_httpd_conf() {
    local conf="${CONF_DIR}/httpd/httpd.conf"
    local EOF

    cat << EOF > ${conf}
# DEFINE SERVER ROOT, OR \${HOME}
H:${ROOT}

# INDEX
I:${ROOT}/www/index.html

# PROXY

# ALLOW ADDRESS

EOF
    chown -v ${OWNER} ${conf}
}


# WRITE FILE FOR GPG PARAMETERS
# SEE: https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
function write_key_params() {
    local EOF
    cat << EOF > "${GPG_DIR}/params.txt"
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Name-Comment: ${NAME}
Expire-Date: 0
%no-ask-passphrase
%no-protection
%commit
EOF
}


# debsrv SERVICE CONFIGURATION
function write_debsrv_service_conf() {
    local conf="${SYSTEMD}/${NAME}.service"
    local EOF
    cat << EOF > ${conf}
[Unit]
Description=${NAME} | debian package server
After=local-fs.target network-online.target
Wants=network-online.target

[Service]
ExecStart=${SRV_DIR}/serve.sh
Restart=always
RestartSec=2
Type=simple
KillMode=mixed
User=${USERNAME}
Group=${GROUPNAME}

[Install]
WantedBy=multi-user.target ${NAME}-job.service
EOF
    chown -v ${OWNER} ${conf}
}


# debsrv-job CONFIGURATION
function write_job_service_conf() {
    local conf="${SYSTEMD}/${NAME}-job.service"
    local EOF
    cat << EOF > ${conf}
[Unit]
Description=${NAME}-job | ${NAME} job service
Wants=${NAME}.service

[Service]
ExecStart=${SRV_DIR}/job.sh
Type=oneshot
KillMode=mixed
User=${USERNAME}
Group=${GROUPNAME}

[Install]
WantedBy=multi-user.target
EOF
    chown -v ${OWNER} ${conf}
}


# debsrv-job PATH CONFIGURATION
function write_path_service_conf() {
    local conf="${SYSTEMD}/${NAME}-job.path"
    local EOF
    cat << EOF > ${conf}
[Unit]
Description=path specification for ${NAME}-job service

[Path]
DirectoryNotEmpty=${SRV_DIR}/job

[Install]
WantedBy=multi-user.target
EOF
    chown -v ${OWNER} ${conf}
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# SETUP FUNCTIONS

function setup_gpg() {
    export GNUPGHOME=${GPG_DIR}
    write_key_params
    gpg --gen-key --batch ${GPG_DIR}/params.txt >${NULL}
    rm -f "${GPG_DIR}/params.txt"
    gpg --armor --output ${PUB_DIR}/${NAME}.gpg --export
    unset GNUPGHOME
}


function setup_systemd() {
    local D=${CWD}

    write_debsrv_service_conf
    write_job_service_conf
    write_path_service_conf

    # CHANGE TO SYSTEMD UNIT DIRECTORY
    cd ${UNIT_DIR}

    # LINK SERVICE FILES
    if [[ ! -L "${NAME}.service" ]]; then
        ln -vs ${SYSTEMD}/${NAME}.service ${NAME}.service
    fi
    if [[ ! -L "${NAME}-job.path" ]]; then
        ln -vs ${SYSTEMD}/${NAME}-job.path ${NAME}-job.path
    fi
    if [[ ! -L "${NAME}-job.service" ]]; then
        ln -vs ${SYSTEMD}/${NAME}-job.service ${NAME}-job.service
    fi

    # CHANGE DIRECTORY
    cd ${D}

    # ENABLE SERVICES
    if ! systemctl -q is-enabled ${NAME}.service; then
        systemctl --no-reload enable ${NAME}.service
    fi
    if ! systemctl -q is-enabled ${NAME}-job.path; then
        systemctl --no-reload enable ${NAME}-job.path
    fi
    if ! systemctl -q is-enabled ${NAME}-job.service; then
        systemctl --no-reload enable ${NAME}-job.service
    fi

    # RELOAD
    systemctl daemon-reload

    # START SERVICES
    if ! systemctl -q is-active ${NAME}.service; then
        systemctl start ${NAME}.service
    fi
    if ! systemctl -q is-active ${NAME}-job.path; then
        systemctl start ${NAME}-job.path
    fi
    # NOTE: ${NAME}-job.service IS TRIGGERED BY ${NAME}-job.path
}


function setup_debsrv() {
    # MAKE DIRS
    if [[ ! -d "${ROOT}" ]]; then
        mkdir -v ${ROOT}
    fi
    for i in ${DIRS[@]}; do
        install_dir ${i}
    done

    # LOG
    touch ${LOG}
    chown -v ${OWNER} ${LOG}
    write_logrotate_conf

    # HTTPD
    write_httpd_conf

    # GPG
    if [[ ! -e "${PUB_DIR}/${NAME}.gpg" ]]; then
        setup_gpg
    fi

    # GPG PERMISSION
    chmod -v 6710 ${GPG_DIR}
    chown -Rv ${OWNER} ${GPG_DIR}
    chown -v ${OWNER} ${PUB_DIR}/*

    # DEPLOY SOURCE TO ROOT
    local src=$(dirname "${CWD}")
    rsync                                \
        --chown ${USERNAME}:${GROUPNAME} \
        --chmod=go-w                     \
        -avv ${src}/ ${ROOT}/

    # DOCUMENTATION
    mv -v ${ROOT}/README.txt ${ROOT}/doc/info.txt

    # SYSTEMD
    setup_systemd

    # DONE
    echo -en "\nSUCCESS. ${BIN_NAME} SET UP FILES"
    echo " AND DIRECTORIES AT THIS PATH: ${ROOT}"
    echo "SERVING http://${IP}:${PORT}"
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# TEARDOWN FUNCTIONS

function teardown_systemd() {
    local D=${CWD}

    # STOP SERVICES
    if systemctl -q is-active ${NAME}.service; then
        systemctl stop ${NAME}.service
    fi
    if systemctl -q is-active ${NAME}-job.path; then
        systemctl stop ${NAME}-job.path
    fi
    if systemctl -q is-active ${NAME}-job.service; then
        systemctl stop ${NAME}-job.service
    fi

    # DISABLE SERVICES
    if systemctl -q is-enabled ${NAME}.service; then
        systemctl disable ${NAME}.service
    fi
    if ! systemctl -q is-enabled ${NAME}-job.path; then
        systemctl disable ${NAME}-job.path
    fi
    if ! systemctl -q is-enabled ${NAME}-job.service; then
        systemctl disable ${NAME}-job.service
    fi

    # RELOAD
    systemctl daemon-reload

    # CHANGE TO SYSTEMD UNIT DIRECTORY
    cd ${UNIT_DIR}

    # UNLINK SERVICE FILES
    if [[ -L "${NAME}.service" ]]; then
        unlink ${NAME}.service
    fi
    if [[ -L "${NAME}-job.path" ]]; then
        unlink ${NAME}-job.path
    fi
    if [[ -L "${NAME}-job.service" ]]; then
        unlink ${NAME}-job.service
    fi

    # CHANGE DIRECTORY
    cd ${D}

    # REMOVE debsrv SERVICE CONFIGURATION
    rm -vf ${SYSTEMD}/${NAME}.service

    # REMOVE debsrv-job CONFIGURATION
    rm -vf ${SYSTEMD}/${NAME}-job.service

    # REMOVE debsrv-job PATH CONFIGURATION
    rm -vf ${SYSTEMD}/${NAME}-job.path
}


function teardown_debsrv() {
    local suite
    local comp
    local d
    local rm_dirs=(
        ${CACHE}
        ${DISTRIBUTION}
        ${INCOMING}
        ${POOL}
        ${SOURCES}
        ${SYSTEMD}
        ${CONF_DIR}
        ${PUB_DIR}
        ${LOG_DIR}
        "${ROOT}/doc"
    )

    # SYSTEMD
    teardown_systemd

    # REMOVE ALL SECTIONS
    for suite in $(ls "${CONF_DIR}/suite"); do
        for comp in $(
            find                             \
                "${CONF_DIR}/suite/${suite}" \
                -mindepth 1 -maxdepth 1      \
                -type d -printf "%f\n"
        ); do
            rm_section ${suite} ${comp}
        done
    done

    # REMOVE PATHS CREATED BY setup_debsrv
    for d in ${rm_dirs[@]}; do
        rm -vfr ${d}
    done

    # DONE
    echo -e "\n${BIN_NAME} TEARDOWN COMPLETE."
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    # GOTTA BE ROOT
    privilege
    # ARGUMENTS
    parse_args $@
    # ESTABLISH FUNCTIONALITY
    if [[ "${FUNCTIONALITY}" == "teardown" ]]; then
        teardown_debsrv
    else
        require_path
        setup_debsrv
    fi
}


main $@

