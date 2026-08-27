#!/usr/bin/env bash
# Fail if any CRD loses a served API version between BASE and HEAD unless the PR is labelled crd-version-removed
# and MIGRATIONS.md names the CRD. (The API server rejects a CRD update whose status.storedVersions still lists a
# version that spec.versions no longer defines — clusters need a storage migration first.)
# Profiles are compared as one set: moving a CRD between the base chart and a profile subchart is not a removal.
# Usage: hack/version-guard.sh <base-git-ref> [pr-number]
set -euo pipefail
cd "$(dirname "$0")/.."
base=$1; pr=${2:-}
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "❌ base ref '$base' not found (fetch-depth: 0?)"; exit 1; }

crd_paths_now() { ls crds/*.yaml charts/*/crds/*.yaml 2>/dev/null || true; }
crd_paths_at()  { git ls-tree -r --name-only "$1" | grep -E '^(crds|charts/[^/]+/crds)/[^/]+\.yaml$' || true; }
declare -A NOW OLD
while read -r p; do [ -n "$p" ] && NOW["$(basename "$p" .yaml)"]="$p"; done <<< "$(crd_paths_now)"
while read -r p; do [ -n "$p" ] && OLD["$(basename "$p" .yaml)"]="$p"; done <<< "$(crd_paths_at "$base")"

removed=""
for name in "${!OLD[@]}"; do
  if [ -z "${NOW[$name]:-}" ]; then removed="$removed $name(file-removed)"; continue; fi
  old=$(git show "$base:${OLD[$name]}" | yq -N '.spec.versions[].name' | sort)
  new=$(yq -N '.spec.versions[].name' "${NOW[$name]}" | sort)
  gone=$(comm -23 <(echo "$old") <(echo "$new") || true)
  [ -z "$gone" ] || removed="$removed $name($(echo $gone | tr ' ' ','))"
done
[ -n "$removed" ] || { echo "✅ no served versions removed (${#NOW[@]} CRDs across all profiles)"; exit 0; }
echo "⚠ served versions removed:$removed"
labelled=no; [ -n "$pr" ] && gh pr view "$pr" --json labels --jq '.labels[].name' | grep -qx 'crd-version-removed' && labelled=yes
for n in $removed; do grep -q "${n%%(*}" MIGRATIONS.md || { echo "❌ MIGRATIONS.md does not mention ${n%%(*}"; exit 1; }; done
[ "$labelled" = yes ] || { echo "❌ PR must carry the label crd-version-removed (and the release notes must tell operators to run the storedVersions migration before 'crds')"; exit 1; }
echo "✅ version removal acknowledged"
