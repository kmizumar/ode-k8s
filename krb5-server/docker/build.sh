#!/usr/bin/env bash
set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"
docker build . -t pfnmaru/krb5-server
