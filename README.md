# platform-crds

Every CustomResourceDefinition the GlueOps platform needs, in one versioned bundle that `captain_utils` applies with
`kubectl apply --server-side --force-conflicts` **before ArgoCD and before the platform chart**. No ArgoCD Application
renders a CRD any more; this bundle is the only installer of platform CRDs.

## How it works

- `kustomization.yaml` is the **only hand-edited manifest**: one line per upstream source, pinned by tag/URL. Adding a
  CRD set is one line; bumping a version is a renovate PR.
- `hack/render.sh` regenerates `crds/` — one file per CRD, each starting with `---` (required: `helm show crds`
  concatenates the files without separators) — and stamps the upstream pins into `Chart.yaml` annotations
  (`glueops.dev/pin.<source>`), which the terraform module's consistency check compares against the platform chart.
- CI (`.github/workflows/ci.yaml`) re-renders and fails on drift, checks every upstream directory is fully referenced,
  rejects Gateway API / Traefik Hub / Calico CRDs, rejects duplicates, applies the bundle to a kind cluster at the fleet's
  Kubernetes version, round-trips the package through `helm show crds`, and guards against removed API versions.
- Releases (`release-please`, tag `vX.Y.Z`) publish the chart to `oci://ghcr.io/glueops/platform-crds`, pulled by
  captain_utils through `ghcr.repo.gpkg.io`. The chart is **packaging only**: `Chart.yaml` + `crds/`; it is applied by
  captain_utils with `kubectl apply --server-side --force-conflicts` before ArgoCD and before the platform chart.
  Never `helm install` it.
- **First release only:** GitHub creates the GHCR package *private*. After the first `publish` run fails its
  "anonymously pullable" step, set https://github.com/orgs/GlueOps/packages/container/platform-crds/settings to
  **Public** and re-run the job (it deliberately checks ghcr.io before touching the mirror, which negative-caches misses).
- Keep `Chart.yaml`'s `description` under 80 characters: release-please re-serialises Chart.yaml and folds longer
  scalars, which would make the render-drift check fail on every release PR (CI enforces this).

## Operating

```
captain_utils → crds              # applies the version pinned as platform_crds_version in VERSIONS/glueops.yaml
captain_utils → argocd
captain_utils → crds              # again: recreates anything the argocd release removed (normally "no changes")
captain_utils → glueops-platform
```

- The bundle **adds and updates CRDs; it never deletes.** A CRD that upstream drops stays in the cluster until a
  human removes it (`kubectl get <kind> -A` first — deleting a CRD garbage-collects every object of that kind).
- **Fix-forward only.** A bundle older than what is live silently shrinks schemas; bump the pin, never roll it back.
- A removed API version needs a storage migration first — see [MIGRATIONS.md](MIGRATIONS.md).
- Provenance: every bundle CRD carries `managedFields` manager `glueops-platform-crds` (`kubectl get crd <name>
  --show-managed-fields`). Orphans = CRDs with that manager that are no longer in the bundle.
- Legacy co-owners: CRDs that ArgoCD once synced with ServerSideApply keep an `argocd-controller/Apply` entry; to
  *remove* a field from those, reset ownership once (`kubectl patch crd <name> --type=merge -p
  '{"metadata":{"managedFields":[{}]}}'`) and re-run `crds`.

## Not in the bundle (by design)

- Calico / Tigera operator CRDs — installed by the `calico` Helm release (EKS) or GlueKube; the operator manages them.
- Cloud-provider CRDs (EKS VPC-CNI `vpcresources.k8s.aws`, …).
- Tenant-installed CRDs.
- Traefik Hub and Gateway API CRDs — a separate future decision; the traefik source is filtered to `traefik.io`.

The bundle is the union of CRDs any cluster flavour may need; unused CRDs on a given cluster (fluentd, VPA on EKS, ESO
generators) are expected.

## Adding or bumping a source

1. Edit `kustomization.yaml` (a directory source must contain its own `kustomization.yaml` upstream — otherwise list
   the files individually).
2. `hack/render.sh && hack/verify.sh` (needs kubectl, helm, yq, jq, gh).
3. Commit `crds/` and `Chart.yaml` with the change. CI repeats the checks and applies the bundle to kind.
