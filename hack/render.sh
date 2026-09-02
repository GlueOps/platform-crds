#!/usr/bin/env bash
# Regenerate every profile's CRD directory (one file per CRD, each starting with ---) and the pins in Chart.yaml.
# `helm show crds` concatenates a chart's crds/*.yaml WITHOUT inserting separators, so the leading --- is load-bearing.
# Profiles: the root kustomization.yaml renders the base chart; profiles/<name>/ renders charts/<name>/, a conditional
# subchart. Sources must be disjoint across profiles — hack/verify.sh fails on a CRD present in more than one.
#
# Every CRD is stamped with BUNDLE_LABEL. It is stamped here rather than in kustomization.yaml so that a new profile
# cannot forget it (verify.sh asserts every rendered CRD carries it). It is what makes the bundle self-describing on a
# cluster: `kubectl get crd -l platform.glueops.dev/bundle=platform-crds`. Deliberately a NEW, GlueOps-namespaced key
# and NOT app.kubernetes.io/managed-by — no controller can select on a key that did not exist, whereas taking over
# managed-by would change a key with an established meaning to fix something cosmetic. Deliberately carries no version
# either: a value that changed per release would make all 85 CRDs diff on every bump and drown the "N new, M changed"
# summary the crds step prints. Static value; one write per cluster, a no-op on every run after that.
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE_LABEL_KEY=platform.glueops.dev/bundle       # hack/verify.sh pins both of these
BUNDLE_LABEL_VALUE=platform-crds
# Argo CD honours sync-options on the LIVE object: an Application that still tracks a CRD an earlier installer
# rendered (pre-#347 k8s-monitoring-helm installed the kube-prometheus-stack and OpenTelemetry CRDs from Argo CD
# Applications) can then neither prune it when the CRD leaves its desired state nor cascade-delete it through its
# resources-finalizer — either of which would garbage-collect every object of that kind. The bundle owns this
# annotation, so it is applied once per CRD and converged on every run. hack/verify.sh pins it too.
ARGO_SYNC_OPTIONS_KEY=argocd.argoproj.io/sync-options
ARGO_SYNC_OPTIONS_VALUE=Prune=false,Delete=false

render() {   # $1 = kustomize dir, $2 = output crds dir
  rm -rf "$2" && mkdir -p "$2"
  kubectl kustomize "$1" \
    | yq -s "\"$2/\" + .metadata.name + \".yaml\"" \
         "select(.kind==\"CustomResourceDefinition\") | .metadata.labels[\"$BUNDLE_LABEL_KEY\"] = \"$BUNDLE_LABEL_VALUE\" | .metadata.annotations[\"$ARGO_SYNC_OPTIONS_KEY\"] = \"$ARGO_SYNC_OPTIONS_VALUE\""
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
