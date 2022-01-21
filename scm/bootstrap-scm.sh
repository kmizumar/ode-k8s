#!/usr/bin/env bash
set -euo pipefail

cat <<EOS
hostname: $(hostname)
hostname -f: $(hostname -f)
domainname: $(domainname)
bootstrap script: $(basename $(readlink -f "${BASH_SOURCE[0]}"))
EOS

ozone scm --init
ozone scm --bootstrap
