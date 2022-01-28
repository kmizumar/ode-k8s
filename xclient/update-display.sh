#!/usr/bin/env bash
set -euo pipefail

#
# update ConfigMap's value with DISPLAY environment variable's value
#
kubectl patch configmap xclient --type='json' -n default -p "[{
  \"op\": \"replace\",
  \"path\": \"/data/envvar-display\",
  \"value\": \"${DISPLAY}\"
}]"
