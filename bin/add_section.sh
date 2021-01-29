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
# SPACE SEPARATED FIELDS FOR ${COMPONENTS} AND ${ARCHITECTURES}
COMPONENTS=""
ARCHITECTURES=""


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

function usage() {
    local EOF
    cat << EOF
Add section, or parts of section, to repository.
Usage:
  $ ${BIN_NAME} <SUITE> -c,--comp <C1> <C2> -a,--arch <i386> <amd64>

  <SUITE>)
    Name of repository suite. Required argument.

  -c,--comp)
    Name of one or more components of suite. Optional.
    Default is "main".

  -a,--arch)
    Name of one or more architectures of components. Optional.
    Default is \"${DEFAULT_ARCHITECTURES}\".

  -h,--help)
    Show this message.

EOF
}


# ARCHIVE CONFIGURATION FOR SUITE
# SEE:
#   apt/doc/examples/apt-ftparchive.conf
function write_archive_conf() {
    local comp=$1
    local conf="${CONF_DIR}/suite/${SUITE}/${comp}/archive.conf"
    local arch
    local d
    local EOF
    cat << EOF > ${conf}
APT::FTPArchive {
    IncludeArchitectureAll true;
};
Dir {
    CacheDir ".cache";
};
Tree "${DISTRIBUTION}/${SUITE}" {
    Sections "${comp}";
    Architectures "${ARCHITECTURES}";
};
BinDirectory "pool/${SUITE}/${comp}" {
EOF
    for arch in ${ARCHITECTURES}; do
        d="dists/${SUITE}/${comp}/binary-${arch}"
        cat << EOF >> ${conf}
    Packages "${d}/Packages;
EOF
    done
    echo '};' >> ${conf}
    chown -v ${USERNAME}:${GROUPNAME} ${conf}
}


# PACKAGES CONFIGURATION FOR SUITE/COMPONENT PAIRING
function write_packages_conf() {
    local comp=$1
    local conf="${CONF_DIR}/suite/${SUITE}/${comp}/packages.conf"
    local cache="${CACHE}/${SUITE}/${comp}"
    local arch
    local EOF
    cat << EOF > ${conf}
APT::FTPArchive {
    IncludeArchitectureAll true;
    ShowCacheMisses true;
};
BinDirectory "pool/${SUITE}/${comp}" {
EOF
    for arch in ${ARCHITECTURES}; do
        cat << EOF >> ${conf}
    BinCacheDB "${cache}/packages-${arch}.db";
EOF
    done
    echo '};' >> ${conf}
    chown -v ${USERNAME}:${GROUPNAME} ${conf}
}


# RELEASE CONFIGURATION FOR SUITE/COMPONENT PAIRING
function write_release_conf() {
    local conf="${CONF_DIR}/suite/${SUITE}/release.conf"
    local EOF
    cat << EOF > ${conf}
APT::FTPArchive::Release {
    Origin "${ORIGIN}";
    Suite "${SUITE}";
    Codename "${CODENAME}";
    Architectures "${ARCHITECTURES}";
    Components "${COMPONENTS}";
    Description "${ORIGIN} debian package repository";
};
EOF
    chown -v ${USERNAME}:${GROUPNAME} ${conf}
}


# RELEASE METADATA FOR SUITE/COMPONENT PAIRING
function write_release_stanza() {
    local comp=$1
    local arch=$2
    local conf="${DISTRIBUTION}/${SUITE}/${comp}/binary-${arch}"
    local EOF
    cat << EOF > "${conf}/Release"
Archive: ${SUITE}
Component: ${comp}
Origin: ${ORIGIN}
Label: ${ORIGIN}
Architecture: ${arch}
EOF
    chown -v ${USERNAME}:${GROUPNAME} "${conf}/Release"
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MAIN

function main() {
    # GOTTA BE ROOT
    privilege

    # ARGUMENTS
    parse_section_args $@
    local arch
    local comp

    if [[ -z "${COMPONENTS}" ]]; then
        COMPONENTS=${DEFAULT_COMPONENTS}
    fi

    if [[ -z "${ARCHITECTURES}" ]]; then
        ARCHITECTURES=${DEFAULT_ARCHITECTURES}
    fi

    # CONFIG DIRECTORY
    install_dir "${CONF_DIR}/suite/${SUITE}"

    # POOL DIRECTORY
    install_dir "${POOL}/${SUITE}"

    # CACHE DIRECTORY
    install_dir "${CACHE}/${SUITE}"

    # INCOMING DIRECTORY
    install_dir "${INCOMING}/${SUITE}"

    # DISTRIBUTION DIRECTORY
    install_dir "${DISTRIBUTION}/${SUITE}"

    # STANDBY PATH FOR SUITE
    install_dir "${STANDBY}/${SUITE}"

    # COMPONENT DIRECTORIES
    for comp in ${COMPONENTS}; do
        # CONFIG DIRECTORY
        install_dir "${CONF_DIR}/suite/${SUITE}/${comp}"

        # POOL DIRECTORY
        install_dir "${POOL}/${SUITE}/${comp}"

        # CACHE DIRECTORY
        install_dir "${CACHE}/${SUITE}/${comp}"

        # INCOMING DIRECTORY
        install_dir "${INCOMING}/${SUITE}/${comp}"

        # DISTRIBUTION DIRECTORIES
        #   EACH SUITE, EACH COMPONENT, EACH ARCHITECTURE
        install_dir "${DISTRIBUTION}/${SUITE}/${comp}"
        for arch in ${ARCHITECTURES}; do
            install_dir "${DISTRIBUTION}/${SUITE}/${comp}/binary-${arch}"
        done

        # STANDBY PATH FOR COMPONENT
        install_dir "${STANDBY}/${SUITE}/${comp}"
    done

    # CONFIGURATION

    # CONFIG FILE
    #     ${CONF_DIR}/suite/${SUITE}/release.conf
    write_release_conf

    for comp in ${COMPONENTS}; do
        # RELEASE METADATA CONFIG FILE
        #   EACH SUITE, EACH COMPONENT, EACH ARCHITECTURE
        for arch in ${ARCHITECTURES}; do
            write_release_stanza ${comp} ${arch}
        done

        # CONFIG FILES
        #     ${CONF_DIR}/suite/${SUITE}/${comp}/archive.conf
        #     ${CONF_DIR}/suite/${SUITE}/${comp}/packages.conf
        write_archive_conf ${comp}
        write_packages_conf ${comp}

        # CREATE INDEXES
        index_pkgs ${comp} || continue
        for arch in ${ARCHITECTURES}; do
            chown -v ${USERNAME}:${GROUPNAME} \
                "${CACHE}/${SUITE}/${comp}/packages-${arch}.db"
        done
    done

    # SOURCES LIST
    #   ${SOURCES}/${NAME}-${SUITE}.list
    write_src_list
}


main ${ARGV}

