#!/usr/bin/env bash
set -eu

#
# NOTE: change the following build args to match your environment
#
cd "$(dirname "${BASH_SOURCE[0]}")"
docker build . -t pfnmaru/ode-xclient \
   --build-arg USER=$(id -un) \
   --build-arg GROUP=$(id -gn) \
   --build-arg UID=$(id -u) \
   --build-arg GID=$(id -g)
