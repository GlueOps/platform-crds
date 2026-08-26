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

| Bundle version | CRD(s) | Version removed | Notes |
|---|---|---|---|
| _(none yet)_ | | | |
