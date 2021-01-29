#!/bin/bash


#TODO 404 ERROR
# # UNSURE
# elif [[ "${REQUEST_METHOD}" == "GET" ]]; then
#     get_header
#     echo -ne "</body>\n</html>\n"

#TODO "POST" could be...
#  a) ingest packages from incoming
#  b) egest archived packages
#  c) reindex section


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# GLOBAL

# SOURCE lib/debsrv.sh
CWD=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
source "$(dirname ${CWD})/lib/debsrv.sh"

# WEB DIRECTORY
WWW="$(dirname ${CWD})/www"


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# UTILITY

function exit501() {
    echo -ne "HTTP/1.0 501 Not Implemented\n\n"
    exit 0
}


function get_header() {
    local EOF
    local css
    css=$(<"${WWW}/style.css")
    cat << EOF
Content-type: text/html

<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>debsrv</title>
<style type="text/css">
${css}
</style>
</head>
<body>
<a id="root" href="/">debsrv</a>
EOF
}


function lsdir() {
    local i
    echo "<a href=\"../\">../</a>"
    for i in $(ls -p1 "${URI}"); do
        echo "<a href=\"${REQUEST_URI}${i}\">${i}</a>"
    done
    echo "</body></html>"
}


function get_log() {
    local EOF
    local log
    log=$(tail -99 "${LOG}")
    cat << EOF
<pre>${log}</pre></body></html>
EOF
}


function get_src_list() {
    local EOF
    local i
    local src
    for i in $(ls -p1 "${URI}"); do
        src=$(<"${URI}/${i}")
        cat << EOF
<a href="${REQUEST_URI}${i}">${i}</a>
<pre class="src">${src}</pre>
EOF
    done
    echo "</body></html>"
}


function get_doc() {
    local EOF
    local doc
    doc=$(<"${DOC_DIR}/info.txt")
    cat << EOF
<pre class="doc">${doc}</pre></body></html>
EOF
}


cd ${ROOT}
URI=$(realpath -e "${ROOT}${REQUEST_URI}" 2>${NULL})
if [[ "${URI}" =~ ^${ROOT} ]]; then
    # DISTRIBUTION OR POOL OR STANDBY
    if [[ "${URI}" =~ ^${DISTRIBUTION}|^${POOL}|^${STANDBY} ]]; then
        if [[ -f "${URI}" ]]; then
            echo -ne "Content-type: application/octet-stream\n\n"
            dd status=none if=${URI}
        elif [[ -d "${URI}" ]]; then
            cat <(get_header) <(lsdir)
        else
            echo "NOT HANDLING REQUEST: ${REQUEST_METHOD} URI: ${URI}" 1>&2
            exit501
        fi
    # INCOMING
    elif [[ "${URI}" =~ ^${INCOMING} ]]; then
        if [[ "${REQUEST_METHOD}" == "GET" ]] && [[ -d "${URI}" ]]; then
            cat <(get_header) <(lsdir)
        elif [[ "${REQUEST_METHOD}" == "POST" ]]; then
            write_job "ingest" "${REQUEST_URI}" 1>&2
            echo -ne "HTTP/1.0 200 OK\n\n"
        else
            echo "NOT HANDLING REQUEST: ${REQUEST_METHOD} URI: ${URI}" 1>&2
            exit501
        fi
    # LOG FILE
    elif [[ "${URI}" =~ ^${LOG_DIR}/?$ ]]; then
        cat <(get_header) <(get_log)
    # SOURCES LIST
    elif [[ "${URI}" =~ ^${SOURCES}/? ]]; then
        cat <(get_header) <(get_src_list)
    # HELP
    elif [[ "${URI}" =~ ^${DOC_DIR}/? ]]; then
        cat <(get_header) <(get_doc)
    # GPG KEYFILE
    elif [[ "${URI}" == "${PUB_DIR}/${NAME}.gpg" ]]; then
        echo -ne "Content-type: application/octet-stream\n\n"
        dd status=none if="${PUB_DIR}/${NAME}.gpg"
    # UNKNOWN
    else
        echo "NOT HANDLING REQUEST: ${REQUEST_METHOD} URI: ${URI}" 1>&2
        exit501
    fi
# UNKNOWN
else
    echo "NOT HANDLING REQUEST: ${REQUEST_METHOD} URI: ${REQUEST_URI}" 1>&2
    exit501
fi


