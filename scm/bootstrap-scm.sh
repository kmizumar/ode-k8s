#!/usr/bin/env bash
set -euo pipefail

cat <<EOS
hostname: $(hostname)
hostname --fqdn: $(hostname --fqdn)
domainname: $(domainname)
bootstrap script: $(basename $(readlink -f "${BASH_SOURCE[0]}"))
EOS

SCM_METAINFO=/data/ozone.scm.db.dirs/scm/current/VERSION

if [ -f "${SCM_METAINFO}" ]; then
    echo "SCM already initialized. skip both 'scm --init' and 'scm --bootstrap'."
    echo "--------------------------------"
    cat ${SCM_METAINFO}
    echo "--------------------------------"
    exit 0
fi

ozone scm --init         # has effects on primordial SCM
ozone scm --bootstrap    # has effects on non-primordial SCM
