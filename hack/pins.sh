#!/usr/bin/env bash
# Stamp the upstream version pins parsed from kustomization.yaml into Chart.yaml annotations
# (the packaged chart otherwise carries no pins; the terraform module's consistency check reads them).
set -euo pipefail
cd "$(dirname "$0")/.."
k=kustomization.yaml
pin() { [ -n "$2" ] || { echo "pins.sh: could not parse pin for $1" >&2; exit 1; }; yq -i ".annotations.\"glueops.dev/pin.$1\" = \"$2\"" Chart.yaml; }
pin argo-cd              "$(grep -oE 'argoproj/argo-cd/manifests/crds\?ref=v[0-9.]+' $k | head -1 | sed 's/.*ref=//')"
pin cert-manager         "$(grep -oE 'cert-manager/cert-manager/releases/download/v[0-9.]+' $k | head -1 | sed 's#.*/##')"
pin external-secrets     "$(grep -oE 'external-secrets/external-secrets/v[0-9.]+/' $k | head -1 | sed 's#.*/\(v[0-9.]*\)/#\1#')"
pin vpa                  "$(grep -oE 'vertical-pod-autoscaler-[0-9.]+/' $k | head -1 | sed 's/vertical-pod-autoscaler-//; s#/##')"
pin traefik              "$(grep -oE 'traefik-helm-chart/v[0-9.]+/' $k | head -1 | sed 's#traefik-helm-chart/##; s#/##')"
pin kube-prometheus-stack "$(grep -oE 'kube-prometheus-stack-[0-9.]+/' $k | head -1 | sed 's/kube-prometheus-stack-//; s#/##')"
pin keda                 "$(grep -oE 'kedacore/keda/v[0-9.]+/' $k | head -1 | sed 's#kedacore/keda/##; s#/##')"
pin metacontroller       "$(grep -oE 'metacontroller/metacontroller/v[0-9.]+/' $k | head -1 | sed 's#metacontroller/metacontroller/##; s#/##')"
pin fluent-operator      "$(grep -oE 'fluent-operator-[0-9.]+/' $k | head -1 | sed 's/fluent-operator-//; s#/##')"
pin external-dns         "$(grep -oE 'external-dns-helm-chart-[0-9.]+/' $k | head -1 | sed 's/external-dns-helm-chart-//; s#/##')"
