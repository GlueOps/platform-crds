# Storage-version migrations

A bundle release that **removes an API version** from a CRD (e.g. ESO dropping `v1beta1`) can only be applied to a
cluster whose `status.storedVersions` no longer lists that version. CI blocks such PRs unless they carry the label
`crd-version-removed` and an entry below. The release notes of that bundle version must tell operators to run the
migration on every cluster **before** `captain_utils → crds` (the tool refuses to apply and prints the same recipe).

Recipe, per CRD:

```bash
kubectl get <plural.group> -A -o json | kubectl replace -f -    # rewrites every object at the current storage version
kubectl patch crd <name> --subresource=status --type=merge -p '{"status":{"storedVersions":["<remaining versions>"]}}'
```

The `kubectl replace` above is the upstream storage-migration recipe and is correct here: it rewrites the **custom
resources**, one at a time, at the CRD's current storage version. It is not the same thing as replacing a CRD, which
captain_utils deliberately no longer does — a whole-object PUT of a CRD erases `metadata.finalizers`, destroying a
terminating CRD and orphaning its objects. Do not "fix" this line to an apply: apply would not rewrite the stored
encoding, which is the entire point of the migration.

| Bundle version | CRD(s) | Version removed | Notes |
|---|---|---|---|
| _(none yet)_ | | | |

## Taking over `opentelemetrycollectors.opentelemetry.io` from the operator chart

The bundle serves only `v1beta1` and declares no `spec.conversion`. A cluster where the opentelemetry-operator Helm
chart installed this CRD (through Argo CD, before k8s-monitoring-helm#347) may keep the chart's conversion webhook
stanza after the takeover (server-side apply cannot remove a field the bundle never sets, unless the CRD was
client-side applied). Before running `captain_utils → crds` with a bundle that carries this CRD, audit:

```bash
kubectl get crd opentelemetrycollectors.opentelemetry.io -o jsonpath='{.spec.conversion.strategy} {.status.storedVersions}{"\n"}'
```

- `None [v1beta1]` (or the CRD is absent): nothing to do.
- `Webhook [v1beta1]`: inert while only one version is served; clear it anyway so a future second served version can
  never hit a dead Service:
  `kubectl patch crd opentelemetrycollectors.opentelemetry.io --type=merge -p '{"spec":{"conversion":{"strategy":"None","webhook":null}}}'`
  (strategy `None` is rejected while the webhook stanza is still present, hence the explicit `null`).
- `storedVersions` containing `v1alpha1`: objects were stored at the old version (operator < 0.98). Run the
  storage-version recipe above for `opentelemetrycollectors.opentelemetry.io` **while the operator and its webhook
  Service are still running**, then clear the webhook as above. With the webhook already dead, every read of the type
  fails and `kubectl delete crd` hangs on the instance finalizer.
