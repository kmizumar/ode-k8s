#!/usr/bin/env bash
set -euo pipefail

cat <<EOS
hostname: $(hostname)
hostname --fqdn: $(hostname --fqdn)
domainname: $(domainname)
bootstrap script: $(basename $(readlink -f "${BASH_SOURCE[0]}"))
EOS

OM_METAINFO=/data/ozone.om.db.dirs/om/current/VERSION

if [ -f "${OM_METAINFO}" ]; then
    echo "OM already initialized. skip 'om --init'."
    echo "--------------------------------"
    cat ${OM_METAINFO}
    echo "--------------------------------"
    exit 0
fi

ozone om --init
