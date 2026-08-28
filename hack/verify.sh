#!/usr/bin/env bash
# CI checks that need no cluster: render parity, upstream completeness, forbidden groups, duplicates/disjointness,
# conversion webhooks, package round-trip, and that every profile is reachable and mandatory.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "❌ $*" >&2; exit 1; }

profiles=$(ls -d profiles/*/ 2>/dev/null | xargs -r -n1 basename)   # profile names; the base chart is not one
crd_dirs() { echo crds; for p in $profiles; do echo "charts/$p/crds"; done; }
all_names() { for d in $(crd_dirs); do ls "$d" 2>/dev/null | sed 's/\.yaml$//'; done | sort; }
total=$(all_names | wc -l)
k=$(mktemp); trap 'rm -f "$k"' EXIT; cat kustomization.yaml profiles/*/kustomization.yaml > "$k"

# 1. committed CRD dirs == fresh render, per profile; the workflow separately requires a clean git status after render.sh
check_render() {   # $1 = kustomize dir, $2 = crds dir
  local rendered committed
  rendered=$(kubectl kustomize "$1" | yq -N 'select(.kind=="CustomResourceDefinition") | .metadata.name' | sort)
  committed=$(ls "$2" | sed 's/\.yaml$//' | sort)
  [ "$rendered" = "$committed" ] || { diff <(echo "$rendered") <(echo "$committed") || true; fail "$2 does not match the render of $1 — run hack/render.sh"; }
}
check_render . crds
for p in $profiles; do check_render "profiles/$p" "charts/$p/crds"; done
for d in $(crd_dirs); do for f in "$d"/*.yaml; do head -1 "$f" | grep -q '^---$' || fail "$f must start with ---"; done; done

# 2. completeness of the per-file directory sources: every *.yaml upstream must be referenced or explicitly excluded
declare -A EXCLUDE=( ["traefik/traefik-helm-chart:traefik/crds"]='^(kustomization\.yaml|gateway-standard-install\.yaml|hub\.traefik\.io_.*\.yaml)$' )
api() { if command -v gh >/dev/null; then gh api "$1"; else curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/$1"; fi; }
grep -oE 'https://raw\.githubusercontent\.com/[^ ]+' "$k" | sed -E 's#https://raw.githubusercontent.com/([^/]+/[^/]+)/([^/]+)/(.*)/[^/]+$#\1 \2 \3#' | sort -u | while read -r repo ref dir; do
  [ -n "$dir" ] || continue
  referenced=$(grep -oE "https://raw\.githubusercontent\.com/$repo/$ref/$dir/[^ ]+" "$k" | sed 's#.*/##' | sort)
  # single-file sources (one referenced file, and the directory is not a CRD directory) are exempt
  case "$dir" in */deploy|deploy/crds) continue;; esac
  upstream=$(api "repos/$repo/contents/$dir?ref=$ref" | jq -r '.[] | select(.type=="file") | select(.name|endswith(".yaml")) | .name' | sort)
  ex="${EXCLUDE[$repo:$dir]:-^$}"
  missing=$(comm -23 <(echo "$upstream") <(echo "$referenced") | grep -vE "$ex" || true)
  [ -z "$missing" ] || fail "upstream $repo/$dir@$ref has CRD files not referenced in a kustomization.yaml: $(echo $missing)"
  echo "✓ $repo/$dir@$ref complete ($(echo "$referenced" | wc -l) files)"
done

# 3. forbidden groups (Gateway API, Traefik Hub, Calico/Tigera are NOT the bundle's business — something else owns them)
for d in $(crd_dirs); do
  bad=$(ls "$d" | grep -E '\.(gateway\.networking\.k8s\.io|hub\.traefik\.io|projectcalico\.org|crd\.projectcalico\.org|operator\.tigera\.io)\.yaml$' || true)
  [ -z "$bad" ] || fail "forbidden CRD groups in $d: $bad"
done

# 4. duplicates AND profile disjointness: a CRD in two profiles is applied twice and its ownership flip-flops
dups=$(all_names | uniq -d)
[ -z "$dups" ] || fail "CRD present in more than one profile (or duplicated): $dups"

# 5. conversion webhooks: an orphan CRD is inert ONLY without one — with a webhook, every read/write of that type
#    fails on a cluster where the operator (and its Service) is absent. spec.conversion is absent upstream today.
for d in $(crd_dirs); do for f in "$d"/*.yaml; do
  [ "$(yq -N '.spec.conversion.strategy // "None"' "$f")" = "None" ] || fail "$f declares a conversion webhook: an orphan CRD with a webhook is not inert — exclude it, pin below it, or ship it with its operator"
done; done

# 5b. …and the trigger for the ones we did NOT ship. Conversion is only invoked when a CRD serves more than one
#     version, which is why a stale spec.conversion webhook left on a cluster by an older installer is harmless today.
#     captain_utils applies and nothing else, and server-side apply cannot remove a field the bundle does not set, so
#     those leftovers are permanent: the day a source starts serving a second version, they go live and every read at
#     the non-storage version fails against a Service that no longer exists. Fail here so that arrives as a decision at
#     bump time, in this repo, rather than as a broken read on a cluster months later.
#     To acknowledge one: audit the fleet for a stale webhook on that type
#       kubectl get crd <name> -o jsonpath='{.spec.conversion.strategy}{"\n"}'     # must be None everywhere
#     clear any that are not (`kubectl patch crd <name> --type=merge -p '{"spec":{"conversion":{"strategy":"None"}}}'`),
#     record it in MIGRATIONS.md, and add the CRD name here.
multi_version_ok=""   # empty on purpose: no CRD in the bundle serves more than one version today
for d in $(crd_dirs); do for f in "$d"/*.yaml; do
  name=$(basename "$f" .yaml)
  case " $multi_version_ok " in *" $name "*) continue ;; esac
  n=$(yq -N '[.spec.versions[] | select(.served == true)] | length' "$f")
  [ "$n" -le 1 ] || fail "$f now serves $n versions: conversion becomes live for this type, so any stale spec.conversion webhook a previous installer left on a cluster starts failing reads — and the bundle cannot remove it. Audit the fleet, then add '$name' to multi_version_ok in $0 and note it in MIGRATIONS.md"
done; done

# 6. package round-trip: helm show crds must yield the UNION, one document per file, and the package must carry
#    nothing but chart metadata and CRDs (it is passed the platform chart's values file, which holds secrets)
tmp=$(mktemp -d); helm package . --version 0.0.0-verify -d "$tmp" >/dev/null
tgz="$tmp/platform-crds-0.0.0-verify.tgz"
docs=$(helm show crds "$tgz" | yq -N '.metadata.name' | grep -v '^---$' | wc -l)
[ "$docs" -eq "$total" ] || fail "helm show crds yields $docs documents for $total files"
extra=$(tar tzf "$tgz" | grep -vE '^platform-crds/(Chart\.yaml|values\.yaml|values\.schema\.json|crds/.*\.yaml|charts/[^/]+/(Chart\.yaml|crds/.*\.yaml))$' || true)
[ -z "$extra" ] || fail "package contains files other than chart metadata and crds/: $extra"
[ -z "$(find . -path ./.git -prune -o -name 'templates' -type d -print)" ] || fail "this chart must never have a templates/ directory: it is rendered with the platform values file, which holds secrets"

# 7. every profile is reachable, mandatory, and additive
render_n() { helm template x "$tgz" --include-crds "$@" 2>/dev/null | yq -N 'select(. != null and .kind == "CustomResourceDefinition") | .metadata.name' | grep -c . || true; }
base_n=$(ls crds | wc -l)
v=$(mktemp)
printf '{}\n' > "$v"; helm template x "$tgz" --include-crds -f "$v" >/dev/null 2>&1 && fail "profile switches must be mandatory: an empty values file rendered without error (values.schema.json required[] is wrong)"
for p in $profiles; do
  printf '%s:\n  enabled: false\n' "$p" > "$v"; off=$(render_n -f "$v")
  printf '%s:\n  enabled: true\n'  "$p" > "$v"; on=$(render_n -f "$v")
  [ "$off" -eq "$base_n" ] || fail "profile $p off rendered $off CRDs, expected the base $base_n"
  [ "$on" -eq "$(( base_n + $(ls "charts/$p/crds" | wc -l) ))" ] || fail "profile $p on rendered $on CRDs, expected base + $(ls "charts/$p/crds" | wc -l)"
  yq -e ".required | contains([\"$p\"])" values.schema.json >/dev/null || fail "values.schema.json must list $p in required[]"
  echo "✓ profile $p: off=$off on=$on, key mandatory"
done
rm -f "$v"; rm -rf "$tmp"

# 8. Chart.yaml invariants: pins present; description short enough that release-please's YAML serializer (lineWidth 80)
#    does not fold it — a folded description would make the render-drift check fail on every release PR
[ "$(yq -r '.description | length' Chart.yaml)" -lt 80 ] || fail "Chart.yaml description must stay under 80 characters (release-please folds longer plain scalars)"
for p in argo-cd cert-manager external-secrets vpa traefik kube-prometheus-stack keda metacontroller fluent-operator external-dns; do yq -e ".annotations.\"glueops.dev/pin.$p\" | length > 0" Chart.yaml >/dev/null || fail "Chart.yaml missing pin annotation for $p"; done
echo "✅ verify: $total CRDs ($base_n base + $(echo $profiles | wc -w) profile(s)), complete, disjoint, no forbidden groups, no conversion webhooks and none invocable, package round-trips, profiles mandatory, pins present"
