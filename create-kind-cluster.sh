#!/usr/bin/env bash
set -euo pipefail

KINDEST_NODE_VERSION=v1.24.1

function usage {
    printf 'usage: %s [-x|--with-xclient]\n' ${0##*/} >&2
    exit 1
}

VARIANT=''
while (( $# > 0 )); do
    case $1 in
        -x|--with-xclient)
            VARIANT="-xclient"
        ;;
        *)
            usage
        ;;
    esac
    shift
done

kind create cluster --config kind-config${VARIANT}.yaml --image kindest/node:${KINDEST_NODE_VERSION}

# needs to add `endpoint_pod_names` to CoreDNS ConfigMap:
#
#  Kubernetes cluster.local in-addr.arpa ip6.arpa {
#     pods insecure
#     fallthrough in-addr.arpa ip6.arpa
#     ttl 30
#     endpoint_pod_names
#  }
#
# see coredns.yaml for the desired result.
kubectl patch configmap coredns --type='json' -n kube-system -p '[{
  "op": "replace",
  "path": "/data/Corefile",
  "value": ".:53 {\n    errors\n    health {\n       lameduck 5s\n    }\n    ready\n    kubernetes cluster.local in-addr.arpa ip6.arpa {\n       pods insecure\n       fallthrough in-addr.arpa ip6.arpa\n       ttl 30\n       endpoint_pod_names\n    }\n    prometheus :9153\n    forward . /etc/resolv.conf {\n       max_concurrent 1000\n    }\n    cache 30\n    loop\n    reload\n    loadbalance\n}\n"
}]'
