#!/usr/bin/env bash
# CI checks that need no cluster: render parity, upstream completeness, forbidden groups, duplicates, package round-trip.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "❌ $*" >&2; exit 1; }
# 1. committed crds/ == fresh render (name set); the workflow separately requires a clean git status after render.sh
rendered=$(kubectl kustomize . | yq -N 'select(.kind=="CustomResourceDefinition") | .metadata.name' | sort)
committed=$(ls crds | sed 's/\.yaml$//' | sort)
[ "$rendered" = "$committed" ] || { diff <(echo "$rendered") <(echo "$committed") || true; fail "crds/ does not match the render — run hack/render.sh"; }
for f in crds/*.yaml; do head -1 "$f" | grep -q '^---$' || fail "$f must start with ---"; done
# 2. completeness of the per-file directory sources: every *.yaml upstream must be referenced or explicitly excluded
declare -A EXCLUDE=( ["traefik/traefik-helm-chart:traefik/crds"]='^(kustomization\.yaml|gateway-standard-install\.yaml|hub\.traefik\.io_.*\.yaml)$' )
api() { if command -v gh >/dev/null; then gh api "$1"; else curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/$1"; fi; }
grep -oE 'https://raw\.githubusercontent\.com/[^ ]+' kustomization.yaml | sed -E 's#https://raw.githubusercontent.com/([^/]+/[^/]+)/([^/]+)/(.*)/[^/]+$#\1 \2 \3#' | sort -u | while read -r repo ref dir; do
  [ -n "$dir" ] || continue
  referenced=$(grep -oE "https://raw\.githubusercontent\.com/$repo/$ref/$dir/[^ ]+" kustomization.yaml | sed 's#.*/##' | sort)
  # single-file sources (one referenced file, and the directory is not a CRD directory) are exempt
  case "$dir" in */deploy|deploy/crds) continue;; esac
  upstream=$(api "repos/$repo/contents/$dir?ref=$ref" | jq -r '.[] | select(.type=="file") | select(.name|endswith(".yaml")) | .name' | sort)
  ex="${EXCLUDE[$repo:$dir]:-^$}"
  missing=$(comm -23 <(echo "$upstream") <(echo "$referenced") | grep -vE "$ex" || true)
  [ -z "$missing" ] || fail "upstream $repo/$dir@$ref has CRD files not referenced in kustomization.yaml: $(echo $missing)"
  echo "✓ $repo/$dir@$ref complete ($(echo "$referenced" | wc -l) files)"
done
# 3. forbidden groups (Gateway API, Traefik Hub, Calico/Tigera are NOT the bundle's business)
bad=$(ls crds | grep -E '\.(gateway\.networking\.k8s\.io|hub\.traefik\.io|projectcalico\.org|crd\.projectcalico\.org|operator\.tigera\.io)\.yaml$' || true)
[ -z "$bad" ] || fail "forbidden CRD groups in bundle: $bad"
# 4. duplicates
dups=$(echo "$rendered" | uniq -d); [ -z "$dups" ] || fail "duplicate CRD names: $dups"
# 5. package round-trip: helm show crds must yield exactly one YAML document per file
tmp=$(mktemp -d); helm package . --version 0.0.0-verify -d "$tmp" >/dev/null
docs=$(helm show crds "$tmp"/platform-crds-0.0.0-verify.tgz | yq -N '.metadata.name' | grep -vc '^---$')
[ "$docs" -eq "$(ls crds | wc -l)" ] || fail "helm show crds yields $docs documents for $(ls crds | wc -l) files"
tar tzf "$tmp"/platform-crds-0.0.0-verify.tgz | grep -vE '^platform-crds/(Chart\.yaml|crds/.*\.yaml)$' | grep -q . && fail "package contains files other than Chart.yaml and crds/: $(tar tzf "$tmp"/*.tgz | grep -vE 'Chart.yaml|crds/')" || true
rm -rf "$tmp"
# 6. pins present
for p in argo-cd cert-manager external-secrets vpa traefik kube-prometheus-stack keda metacontroller fluent-operator external-dns; do yq -e ".annotations.\"glueops.dev/pin.$p\" | length > 0" Chart.yaml >/dev/null || fail "Chart.yaml missing pin annotation for $p"; done
echo "✅ verify: $(ls crds | wc -l) CRDs, complete, no forbidden groups, no duplicates, package round-trips, pins present"
