#!/bin/bash

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

# SOURCE lib/config.sh
CWD=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${CWD}/config.sh"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

# REQUIRE ROOT PRIVILEGE
function privilege() {
    if (( "${EUID}" != 0 )); then
        echo "RUN ${BIN_NAME} AS SUDO."
        exit 1
    fi
}


function check_args() {
    local msg
    # ARG REQUIRED
    if (( "$#" < 1 )); then
        echo "${FUNCNAME[0]} BAD USAGE." 1>&2
        usage
        exit 1
    fi
    # HELP
    if grep -iq '\-h\|\-\-help' <<<"$@"; then
        usage
        exit 0
    fi
    # SUITE
    if [[ ! "$1" =~ ^[A-Za-z] ]]; then
        msg="ERROR. ${BIN_NAME} DOES NOT "
        msg+="ACCEPT \"$1\" FOR SUITE NAME."
        echo "${msg}" 1>&2
        exit 1
    fi
}


function parse_section_args() {
    # TAKES ARGV, SETS GLOBAL VALUES FOR...
    #   ${SUITE}
    #   ${COMPONENTS}
    #   ${ARCHITECTURES}
    local i

    # CHECK ARGUMENTS
    check_args $@

    # SUITE
    SUITE=$1
    shift

    # PARSE
    while (( "$#" )); do
        case "$1" in
            -c|--comp*)
                shift
                while (( "$#" )); do
                    if [[ "$1" =~ ^\- ]]; then
                        break
                    else
                        if [[ "$1" =~ , ]]; then
                            # HANDLE COMMA SEPARATOR
                            for i in ${1//,/\ }; do
                                COMPONENTS+="${i} "
                            done
                            shift
                        else
                            COMPONENTS+="$1 "
                            shift
                        fi
                    fi
                done
            ;;
            -a|--arch*)
                shift
                while (( "$#" )); do
                    if [[ "$1" =~ ^\- ]]; then
                        break
                    else
                        if [[ "$1" =~ , ]]; then
                            # HANDLE COMMA SEPARATOR
                            for i in ${1//,/\ }; do
                                ARCHITECTURES+="${i} "
                            done
                            shift
                        else
                            ARCHITECTURES+="$1 "
                            shift
                        fi
                    fi
                done
            ;;
            *)
                if [[ "$1" =~ ^\- ]]; then
                    echo "BAD OPTION: $1" 1>&2
                    usage
                    exit 1
                else
                    break
                fi
            ;;
        esac
    done
    # REMOVE TRAILING SPACES
    COMPONENTS="${COMPONENTS%%\ }"
    ARCHITECTURES="${ARCHITECTURES%%\ }"
}


function parse_package_args() {
    # TAKES ARGV, SETS GLOBAL VALUES FOR...
    #   ${SUITE}
    #   ${COMPONENTS}
    #   ${PACKAGES}
    local i

    # CHECK ARGUMENTS
    check_args $@

    # SUITE
    SUITE=$1
    shift

    # PARSE
    while (( "$#" )); do
        case "$1" in
            -c|--comp*)
                shift
                while (( "$#" )); do
                    if [[ "$1" =~ ^\- ]]; then
                        break
                    else
                        if [[ "$1" =~ , ]]; then
                            # HANDLE COMMA SEPARATOR
                            for i in ${1//,/\ }; do
                                COMPONENTS+="${i} "
                            done
                            shift
                        else
                            COMPONENTS+="$1 "
                            shift
                        fi
                    fi
                done
            ;;
            -p|--pack*)
                shift
                while (( "$#" )); do
                    if [[ "$1" =~ ^\- ]]; then
                        break
                    else
                        if [[ "$1" =~ , ]]; then
                            # HANDLE COMMA SEPARATOR
                            for i in ${1//,/\ }; do
                                PACKAGES+="${i} "
                            done
                            shift
                        else
                            PACKAGES+="$1 "
                            shift
                        fi
                    fi
                done
            ;;
            *)
                if [[ "$1" =~ ^\- ]]; then
                    echo "BAD OPTION: $1" 1>&2
                    usage
                    exit 1
                else
                    break
                fi
            ;;
        esac
    done
}


function install_dir() {
    local d=$1
    install                  \
        --directory          \
        --owner=${USERNAME}  \
        --group=${GROUPNAME} \
        --mode=6775          \
        --verbose ${d} 1>&2
}


function rotate_log() {
    local STATE
    local log_stat
    local conf="${CONF_DIR}/logrotate"
    if [[ ! -e "${conf}/status" ]]; then
        touch "${conf}/status"
        return
    fi
    log_stat=$(lsof -t +D "${conf}")
    if [[ "${log_stat}" =~ ^[0-9]+$ ]]; then
        echo "SKIPPING LOGROTATE, STATE FILE IN USE." 1>&2
        return
    fi
    logrotate --state "${conf}/status" "${conf}/configuration" 1>&2
}


# WRITE FILE FOR SOURCES LIST
function write_src_list() {
    local src_list="${SOURCES}/${NAME}-${SUITE}.list"
    local tmp=$(mktemp)
    local uri="http://${IP}:${PORT}"
    local archs
    local comp
    local conf
    local EOF

    echo "WRITING SOURCES FILE: \"${NAME}-${SUITE}.list\" ..."

    # CREATE NEW SOURCES LIST
    for comp in $(
        find                             \
            "${CONF_DIR}/suite/${SUITE}" \
            -mindepth 1 -maxdepth 1      \
            -type d -printf "%f\n"
    ); do
        # ARCHIVE CONFIGURATION FILE
        conf="${CONF_DIR}/suite/${SUITE}/${comp}/archive.conf"

        # ARCHITECTURES
        eval "$(${APTCFG} -c ${conf} shell archs Tree::Architectures)"

        cat << EOF >> ${tmp}
deb [ arch=${archs/\ /,} ] ${uri} ${SUITE} ${comp}
EOF

    done
    if (( "${EUID}" == 0 )); then
        rsync                                \
            --remove-source-files            \
            --chown ${USERNAME}:${GROUPNAME} \
            --chmod 664                      \
            ${tmp} ${src_list}
    else
        mv ${tmp} ${src_list}
        chmod go+r ${src_list}
    fi
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# INDEXING

# SIGN RELEASE FILES
function sign_release() {
    local release_path="${DISTRIBUTION}/${SUITE}"

    echo "SIGNING \"Release\" FILES FOR SUITE: \"${SUITE}\" ..."

    rm -f "${release_path}/InRelease"
    rm -f "${release_path}/Release.gpg"
    export GNUPGHOME=${GPG_DIR}

    gpg --clearsign -o              \
        "${release_path}/InRelease" \
        "${release_path}/Release"   \
    2>${NULL}

    gpg -abs -o                       \
        "${release_path}/Release.gpg" \
        "${release_path}/Release"     \
    2>${NULL}

    unset GNUPGHOME
    if (( "${EUID}" == 0 )); then
        chown -v ${USERNAME}:${GROUPNAME} "${release_path}/InRelease"
        chown -v ${USERNAME}:${GROUPNAME} "${release_path}/Release.gpg"
    fi
}


# CREATE RELEASE FILES
function mk_release() {
    local conf="${CONF_DIR}/suite/${SUITE}/release.conf"
    local release_path="${DISTRIBUTION}/${SUITE}"

    echo "WRITING \"Release\" FILE FOR SUITE: \"${SUITE}\" ..."

    ${APTARC} release -c=${conf} ${release_path} > "${release_path}/Release"
    if (( "${EUID}" == 0 )); then
        chown -v ${USERNAME}:${GROUPNAME} "${release_path}/Release"
    fi
}


# CREATE PACKAGES FILES
function mk_packages() {
    local comp=$1
    local arch=$2
    local db
    local packages_conf
    local archive_path
    local packages
    local fsize
    local msg

    # PATH TO DATA CACHE
    db="${CACHE}/${SUITE}/${comp}/packages-${arch}.db"

    # PATH TO "packages.conf"
    packages_conf="${CONF_DIR}/suite/${SUITE}/${comp}/packages.conf"

    # PATH TO SECTION IN ARCHIVE
    archive_path="pool/${SUITE}/${comp}"

    # PATH TO "Packages" FILE
    packages="${DISTRIBUTION}/${SUITE}/${comp}/binary-${arch}/Packages"

    msg="WRITING \"Packages\" FILE FOR"
    msg+=" SUITE: \"${SUITE}\""
    msg+=" COMPONENT: \"${comp}\""
    msg+=" ARCHITECTURE \"${arch}\" ..."
    echo ${msg}

    ${APTARC} packages      \
        --db ${db}          \
        -c=${packages_conf} \
        ${archive_path}     \
        > ${packages}
    chown ${USERNAME}:${GROUPNAME} ${packages}

    fsize=$(stat --printf="%s" "${packages}")
    if (( "${fsize}" > 0 )); then
        gzip -c ${packages} > "${packages}.gz"
        chown ${USERNAME}:${GROUPNAME} "${packages}.gz"
    else
        if [ -e "${packages}.gz" ]; then
            rm "${packages}.gz"
        fi
    fi
}


# INDEX PACKAGES
function index_pkgs() {
    local comp=$1
    local conf_dir="${CONF_DIR}/suite/${SUITE}/${comp}"
    local arch
    local architectures

    if [[ -z "${SUITE}" ]] || [[ ! -d "${POOL}/${SUITE}" ]]; then
        echo "ERROR. ${FUNCNAME[0]} CANNOT FIND SUITE: \"${SUITE}\"" 1>&2
        return 1
    fi
    # ARCHIVE CONFIGURATION PATH
    if [[ ! -d "${conf_dir}" ]]; then
        echo "ERROR. ${FUNCNAME[0]} CANNOT FIND COMPONENT: \"${comp}\"" 1>&2
        return 1
    fi

    # READ CONFIGURED ARCHITECTURES TO VAR ${architectures}
    eval "$(${APTCFG} -c ${conf_dir}/archive.conf shell architectures Tree::Architectures)"

    echo "INDEXING PACKAGES FOR SUITE: \"${SUITE}\" ..."
    # apt-ftparchive packages <PATH>
    # WANTS RELATIVE PATH
    cd ${ROOT}

    for arch in ${architectures}; do
        mk_packages ${comp} ${arch}
    done
    mk_release
    sign_release
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MANAGE PACKAGES

# MOVE SINGLE PACKAGE FROM INCOMING TO ARCHIVE
function ingest_pkg() {
    local suite=$1
    local comp=$2
    local deb=$3
    local pool="${POOL}/${suite}/${comp}/${deb::1}"
    local opts=""

    # MAKE PATH
    pool="${POOL}/${suite}/${comp}/${deb::1}"
    if [[ ! -d "${pool}" ]]; then
        install_dir ${pool}
    fi

    # OPTIONS ACCORDING TO PRIVILEGE
    if (( "${EUID}" == 0 )); then
        opts="--chown ${USERNAME}:${GROUPNAME} --chmod 744"
    fi

    # MOVE PACKAGE FROM INCOMING TO ARCHIVE
    echo "INGESTING PACKAGE: ${deb} -> ${pool}/${deb}"
    rsync --remove-source-files ${opts} \
        ${INCOMING}/${suite}/${comp}/${deb} ${pool}/
}


# INGEST INCOMING PACKAGES
function ingest_packages() {
    parse_package_args $@
    local comp
    local deb
    local i
    local msg
    local incoming
    local reindex=""

    if [[ -z "${COMPONENTS}" ]]; then
        # ALL COMPONENTS OF SUITE
        COMPONENTS=$(
            find                        \
                "${INCOMING}/${SUITE}"  \
                -maxdepth 1 -mindepth 1 \
                -type d -printf "%f\n"
        )
    fi

    # COMPONENT(S)
    for comp in ${COMPONENTS}; do
        incoming="${INCOMING}/${SUITE}/${comp}"
        if [[ ! -e "${incoming}" ]]; then
            msg="WARNING. COMPONENT \"${comp}\" NOT FOUND. SKIPPING..."
            echo ${msg}
            continue
        fi
        # PACKAGES
        if [[ -n "${PACKAGES}" ]]; then
            for i in "${PACKAGES}"; do
                if [[ ! "${i}" =~ \.deb$ ]]; then
                    msg="WARNING. INVALID PACKAGE NAME: \"${i}\". SKIPPING..."
                    echo ${msg}
                    continue
                fi
                deb=$(find  "${incoming}" -type f -name "${i}" -printf "%f\n")
                if [[ ! -e "${deb}" ]]; then
                    msg="WARNING. PACKAGE \"${i}\" NOT FOUND. SKIPPING..."
                    echo ${msg}
                    continue
                fi
                ingest_pkg ${SUITE} ${comp} ${deb}
                if (( "$?" == 0 )); then
                    reindex+="${comp} "
                fi
            done
        else
            for deb in $(
                find "${incoming}" -type f -name "*.deb" -printf "%f\n"
            ); do
                ingest_pkg ${SUITE} ${comp} ${deb}
                if (( "$?" == 0 )); then
                    reindex+="${comp} "
                fi
            done
        fi
    done

    # REINDEX COMPONENTS
    for comp in $(for i in ${reindex}; do echo "${i}"; done | sort -u); do
        index_pkgs ${comp}
    done
}

# MOVE SINGLE PACKAGE FROM ARCHIVE TO STANDBY
function egest_pkg() {
    local suite=$1
    local comp=$2
    local deb=$3

    # MOVE PACKAGE FROM ARCHIVE TO STANDBY
    echo -n "EGESTING PACKAGE: ${deb} -> "
    echo "${STANDBY}/${suite}/${comp}/${deb}"
    mv                                            \
        ${POOL}/${suite}/${comp}/${deb::1}/${deb} \
        ${STANDBY}/${suite}/${comp}/              \
    || return 1

    # UPDATE MTIME
    touch -mc ${STANDBY}/${suite}/${comp}/${deb}
}


# EGEST ARCHIVED PACKAGES
function egest_packages() {
    parse_package_args $@
    local comp
    local deb
    local i
    local msg
    local reindex=""

    if [[ -z "${COMPONENTS}" ]]; then
        echo "ERROR. ${BIN_NAME} HAS NO \"component\"." 1>&2
        exit 1
    fi
    if [[ -z "${PACKAGES}" ]]; then
        echo "ERROR. ${BIN_NAME} HAS NO \"package\"." 1>&2
        exit 1
    fi

    # COMPONENT(S)
    for comp in ${COMPONENTS}; do
        if [[ ! -e "${POOL}/${SUITE}/${comp}" ]]; then
            msg="WARNING. COMPONENT \"${comp}\" NOT FOUND. SKIPPING..."
            echo ${msg}
            continue
        fi
        # PACKAGES
        for deb in "${PACKAGES}"; do
            # REMOVE SPACES
            deb="${deb//\ /}"
            if [[ ! "${deb}" =~ \.deb$ ]]; then
                msg="WARNING. INVALID PACKAGE NAME: \"${deb}\". SKIPPING..."
                echo ${msg}
                continue
            fi
            if [[ ! -e "${POOL}/${SUITE}/${comp}/${deb::1}/${deb}" ]]; then
                msg="WARNING. PACKAGE \"${deb}\" NOT FOUND. SKIPPING..."
                echo ${msg}
                continue
            fi
            egest_pkg ${SUITE} ${comp} ${deb}
            if (( "$?" == 0 )); then
                reindex+="${comp} "
            fi
        done
    done

    # REINDEX COMPONENTS
    for comp in $(for i in ${reindex}; do echo "${i}"; done | sort -u); do
        index_pkgs ${comp}
    done
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# MANAGE SECTIONS

function rm_section() {
    suite=$1
    comp=$2

    if [[ -z "${suite}" ]]; then
        echo "ERROR. ${BIN_NAME} HAS NO \"suite\"." 1>&2
        exit 1
    fi
    if [[ -z "${comp}" ]]; then
        echo "ERROR. ${BIN_NAME} HAS NO \"component\"." 1>&2
        exit 1
    fi
    if [[ ! -e "${POOL}/${suite}" ]]; then
        msg="WARNING. ARCHIVE SUITE \"${suite}\" NOT FOUND. SKIPPING..."
        echo ${msg}
        return 1
    fi
    if [[ ! -e "${POOL}/${suite}/${comp}" ]]; then
        msg="WARNING. ARCHIVE SECTION \"${suite}/${comp}\" NOT FOUND. SKIPPING..."
        echo ${msg}
        return 1
    fi

    echo "REMOVING SECTION \"${suite}/${comp}\" ..."

    # REMOVE ARCHIVED PACKAGES
    find                           \
        "${POOL}/${suite}/${comp}" \
        -type f -name "*.deb"      \
        -exec mv -v {}             \
        "${STANDBY}/${suite}/${comp}" \;

    # MOVE ANY PACKAGES FROM INCOMING DIRECTORY
    find                               \
        "${INCOMING}/${suite}/${comp}" \
        -type f -name "*.deb"          \
        -exec mv -v {}                 \
        "${STANDBY}/${suite}/${comp}" \;

    # CACHE PATHS
    rm -vr "${CACHE}/${suite}/${comp}"

    # DISTRIBUTION PATHS
    rm -vr "${DISTRIBUTION}/${suite}/${comp}"

    # CONFIG PATHS
    rm -vr "${CONF_DIR}/suite/${suite}/${comp}"

    # INCOMING PATHS
    rm -vr "${INCOMING}/${suite}/${comp}"

    # POOL PATHS
    rm -vr "${POOL}/${suite}/${comp}"

    # REMOVE STANDBY DIR IF EMPTY
    if [[ ! "$(ls -A ${STANDBY}/${suite}/${comp})" ]]; then
        rmdir -v "${STANDBY}/${suite}/${comp}"
    fi
}


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# JOB

function stamp() {
    # DATE FORMAT "%Y-%m-%d_%s"
    # "%s" HYPHENATED FOR READABILITY
    local date_str
    local epoch
    read -r date_str epoch <<<$(
        date '+%Y-%m-%d %s' |\
        awk '{print $1" "$2}'
    )
    date_str+="_${epoch:0:4}-"
    date_str+="${epoch:4:3}-"
    date_str+="${epoch:7:3}"
    echo -n ${date_str}
}


function write_job() {
    local name=$1
    local exe="${SRV_DIR}/${name}.sh"
    local job="${name}_$(stamp)"
    local uri=(
        $(awk -F/ '{print $3" "$4" "$5}' <<<"$2")
    )
    local EOF

    case ${#uri[@]} in
        1)
            # ${SUITE}
            exe+=" ${uri[0]}"
        ;;
        2)
            # ${SUITE} ${COMP}
            exe+=" ${uri[0]} -c ${uri[1]}"
        ;;
        3)
            # ${SUITE} ${COMP} ${DEB}
            exe+=" ${uri[0]} -c ${uri[1]} -p ${uri[2]}"
        ;;
    esac

    # WRITE JOB SCRIPT
    cat << EOF > "${STANDBY}/.job/${job}.job"
#!/bin/bash
${exe} &>>${LOG}
EOF

    rsync                            \
        --remove-source-files        \
        --chmod 754                  \
        "${STANDBY}/.job/${job}.job" \
        "${SRV_DIR}/job/${job}.sh"

    echo "CREATED JOB \"${job}.sh\""
}


