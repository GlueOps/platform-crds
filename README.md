# platform-crds

Every CustomResourceDefinition the GlueOps platform needs, in one versioned bundle that `captain_utils` applies with
`kubectl apply --server-side --force-conflicts` **before ArgoCD and before the platform chart**. No ArgoCD Application
renders a CRD any more; this bundle is the only installer of platform CRDs.

## Profiles

Most CRDs go to every cluster. A component the platform chart deploys only on some clusters keeps its CRDs in a
*profile* — a conditional subchart — so a cluster installs only what its own values turn on.

```
kustomization.yaml              base sources          -> crds/                 (every cluster)
profiles/kubeadm/               kubeadm-only sources  -> charts/kubeadm/crds/  (kubeadm.enabled: true)
```

Consumers select with the cluster's platform values file; `captain_utils`' `crds` item does this for you:

```bash
helm template x oci://ghcr.io/glueops/platform-crds --version <v> --include-crds -f platform.yaml
```

`helm show crds` still returns the **union** of every profile, values-independent — use it to see everything the
bundle can install, and to compute the "N of M" line the apply step prints.

Every profile key is **mandatory**: `values.schema.json` marks it required and nothing defines a default, so a
renamed or missing key is a hard error (`at '/kubeadm': missing property 'enabled'`) rather than a silent fallback
to the base set. `hack/verify.sh` proves each profile is reachable, additive, disjoint from the others, and mandatory.

Adding a profile: create `profiles/<name>/kustomization.yaml`, add `<name>` to `dependencies` in `Chart.yaml` with
`condition: <name>.enabled`, add it to `required` in `values.schema.json`, run `hack/render.sh`. The key must be one
the platform chart already writes into `platform.yaml`, so nothing in captain_utils has to learn about it.

The bundle still ships CRDs for components a cluster does not run when that is not gated on a values switch
(fluentd, the ESO generators) — profiles are for cluster *shape*, not for every unused type.

## How it works

- `kustomization.yaml` is the **only hand-edited manifest**: one line per upstream source, pinned by tag/URL. Adding a
  CRD set is one line; bumping a version is a renovate PR.
- `hack/render.sh` regenerates `crds/` — one file per CRD, each starting with `---` (required: `helm show crds`
  concatenates the files without separators) — and stamps the upstream pins into `Chart.yaml` annotations
  (`glueops.dev/pin.<source>`), which the terraform module's consistency check compares against the platform chart.
- CI (`.github/workflows/ci.yaml`) re-renders and fails on drift, checks every upstream directory is fully referenced,
  rejects Gateway API / Traefik Hub / Calico CRDs, rejects duplicates, applies the bundle to a kind cluster at the fleet's
  Kubernetes version, round-trips the package through `helm show crds`, and guards against removed API versions.
- Releases (`release-please`, tag `vX.Y.Z`; the bundle stays on 0.x — a breaking change bumps the minor, a feature
  bumps the patch — until it is promoted to 1.0 deliberately) publish the chart to `oci://ghcr.io/glueops/platform-crds`, pulled by
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
- Provenance: every bundle CRD carries the label `platform.glueops.dev/bundle=platform-crds`, so the bundle's
  footprint on a cluster is one query:

  ```bash
  kubectl get crd -l platform.glueops.dev/bundle=platform-crds          # everything this bundle installed
  kubectl get crd -l '!platform.glueops.dev/bundle'                     # everything else (tenant, cloud, Calico, …)
  ```

  It is a new, GlueOps-namespaced key on purpose. It is deliberately **not** `app.kubernetes.io/managed-by`: nothing
  can be selecting on a key that did not exist, whereas taking over `managed-by` would change a key with an
  established meaning (Helm checks it when adopting a resource) to fix something cosmetic. It carries no version
  either — a value that changed per release would make all 85 CRDs diff on every bump.
  Field-manager ownership is the other half: every bundle CRD also carries `managedFields` manager
  `glueops-platform-crds` (`kubectl get crd <name> --show-managed-fields`). Orphans = CRDs with that manager, or that
  label, that are no longer in the bundle.
- **The bundle converges exactly what it declares — nothing more.** captain_utils applies and does nothing else
  (`kubectl replace` was removed: it erased `metadata.finalizers`, destroying terminating CRDs). Server-side apply
  cannot remove a field the applying manager does not set, so:

  | the bundle… | on a cluster where another installer set it |
  |---|---|
  | declares the key | our manager takes it over on the next apply — the old value is overwritten |
  | later drops a key it used to declare | removed cleanly, because we owned it |
  | never declares the key | **frozen: no bundle release can ever remove it** |

  So what upstream happens to stamp on a CRD decides what we can converge. 54 of 85 CRDs here ship no labels at all;
  a cluster migrated from the old per-Application installs therefore keeps `app.kubernetes.io/managed-by: Helm` and
  `helm.sh/chart` on the CRDs whose upstream copy has no labels (measured: 8 of 83 on a real cluster — 6 KEDA, which
  is sourced from `config/crd/bases/`, plus 2 cert-manager). These are inert: nothing reads them, the set does not
  grow, and `kubectl diff` stays clean because we never apply them.

  Do **not** try to clear them by resetting ownership. `kubectl patch crd <name> --type=merge -p
  '{"metadata":{"managedFields":[{}]}}'` followed by a re-run does not work — verified: it makes the field *unowned*,
  not absent, and the next apply still does not set it, so the labels survive unchanged. It also releases claims that
  are live rather than stale. To remove one anyway, delete the key directly: `kubectl label crd <name> <key>-`.
- Flipping a profile off does not remove its CRDs. A cluster that goes `kubeadm: true → false` keeps the VPA CRDs,
  still owned by `glueops-platform-crds` but no longer in the bundle — the "orphans" case above, reached without any
  upstream change. Remove them by hand if you want them gone, after checking for live objects.

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
