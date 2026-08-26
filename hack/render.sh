#!/usr/bin/env bash
# Regenerate crds/ (one file per CRD, each starting with ---) and the pin annotations in Chart.yaml.
# `helm show crds` concatenates crds/*.yaml WITHOUT inserting separators, so the leading --- is load-bearing.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf crds && mkdir -p crds
kubectl kustomize . | yq -s '"crds/" + .metadata.name + ".yaml"' 'select(.kind=="CustomResourceDefinition")'
for f in crds/*.yaml; do head -1 "$f" | grep -q '^---$' || sed -i '1i ---' "$f"; done
hack/pins.sh
echo "rendered $(ls crds | wc -l) CRDs into crds/"
