#!/usr/bin/env bash
# Fail if any CRD loses a served API version between BASE and HEAD unless the PR is labelled crd-version-removed
# and MIGRATIONS.md names the CRD. (The API server rejects a CRD update whose status.storedVersions still lists a
# version that spec.versions no longer defines — clusters need a storage migration first.)
# Usage: hack/version-guard.sh <base-git-ref> [pr-number]
set -euo pipefail
cd "$(dirname "$0")/.."
base=$1; pr=${2:-}
git rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "❌ base ref '$base' not found (fetch-depth: 0?)"; exit 1; }
removed=""
# a CRD file that disappeared from crds/ counts as every one of its versions removed
for gone in $(comm -23 <(git ls-tree --name-only "$base" crds/ 2>/dev/null | sed 's#crds/##' | sort) <(ls crds | sort)); do
  removed="$removed ${gone%.yaml}(file-removed)"
done
for f in crds/*.yaml; do
  name=$(basename "$f" .yaml)
  git cat-file -e "$base:$f" 2>/dev/null || continue
  old=$(git show "$base:$f" | yq -N '.spec.versions[].name' | sort)
  new=$(yq -N '.spec.versions[].name' "$f" | sort)
  gone=$(comm -23 <(echo "$old") <(echo "$new") || true)
  [ -z "$gone" ] || removed="$removed $name($(echo $gone | tr ' ' ','))"
done
[ -n "$removed" ] || { echo "✅ no served versions removed"; exit 0; }
echo "⚠ served versions removed:$removed"
labelled=no; [ -n "$pr" ] && gh pr view "$pr" --json labels --jq '.labels[].name' | grep -qx 'crd-version-removed' && labelled=yes
for n in $removed; do grep -q "${n%%(*}" MIGRATIONS.md || { echo "❌ MIGRATIONS.md does not mention ${n%%(*}"; exit 1; }; done
[ "$labelled" = yes ] || { echo "❌ PR must carry the label crd-version-removed (and the release notes must tell operators to run the storedVersions migration before 'crds')"; exit 1; }
echo "✅ version removal acknowledged"
