#!/usr/bin/env bash
# Stamp the upstream version pins parsed from kustomization.yaml into Chart.yaml annotations
# (the packaged chart otherwise carries no pins; the terraform module's consistency check reads them).
# Edits Chart.yaml line by line on purpose: release-please rewrites Chart.yaml with a different YAML
# serializer, and a whole-file re-serialisation here would make the render-drift check fail after every release.
set -euo pipefail
cd "$(dirname "$0")/.."
# every profile's sources, so a pin that moved into profiles/<name>/ is still found
k=$(mktemp); trap 'rm -f "$k"' EXIT
cat kustomization.yaml profiles/*/kustomization.yaml > "$k"
grep -q '^annotations:' Chart.yaml || printf 'annotations:\n' >> Chart.yaml
pin() {
  [ -n "$2" ] || { echo "pins.sh: could not parse pin for $1" >&2; exit 1; }
  if grep -q "^  glueops.dev/pin.$1:" Chart.yaml; then
    sed -i "s#^  glueops.dev/pin.$1:.*#  glueops.dev/pin.$1: \"$2\"#" Chart.yaml
  else
    sed -i "/^annotations:/a\\  glueops.dev/pin.$1: \"$2\"" Chart.yaml
  fi
}
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
