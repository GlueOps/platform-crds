#!/usr/bin/env bash
# Regenerate every profile's CRD directory (one file per CRD, each starting with ---) and the pins in Chart.yaml.
# `helm show crds` concatenates a chart's crds/*.yaml WITHOUT inserting separators, so the leading --- is load-bearing.
# Profiles: the root kustomization.yaml renders the base chart; profiles/<name>/ renders charts/<name>/, a conditional
# subchart. Sources must be disjoint across profiles — hack/verify.sh fails on a CRD present in more than one.
set -euo pipefail
cd "$(dirname "$0")/.."

render() {   # $1 = kustomize dir, $2 = output crds dir
  rm -rf "$2" && mkdir -p "$2"
  kubectl kustomize "$1" | yq -s "\"$2/\" + .metadata.name + \".yaml\"" 'select(.kind=="CustomResourceDefinition")'
  for f in "$2"/*.yaml; do head -1 "$f" | grep -q '^---$' || sed -i '1i ---' "$f"; done
  echo "  $(ls "$2" | wc -l) CRDs -> $2"
}

render . crds
for p in profiles/*/; do
  name=$(basename "$p")
  render "$p" "charts/$name/crds"
done
hack/pins.sh
echo "rendered $(ls crds charts/*/crds 2>/dev/null | grep -c '\.yaml$') CRDs across $(( 1 + $(ls -d profiles/*/ 2>/dev/null | wc -l) )) profiles"
