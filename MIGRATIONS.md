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
