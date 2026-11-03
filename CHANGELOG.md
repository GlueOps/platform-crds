# Changelog

## [0.1.6](https://github.com/GlueOps/platform-crds/compare/v0.1.5...v0.1.6) (2026-11-03)


### Features

* **deps:** bump external-secrets CRDs to v2.14.0 ([#111](https://github.com/GlueOps/platform-crds/issues/111)) ([b076d47](https://github.com/GlueOps/platform-crds/commit/b076d475d7f0ddef035529124c57ec397c5742de))
* **deps:** update actions/create-github-app-token action to v3.3.0 ([#108](https://github.com/GlueOps/platform-crds/issues/108)) ([41483fa](https://github.com/GlueOps/platform-crds/commit/41483fae5314a4839c77c9f72a6398ebc7d5a3fb))
* **deps:** update dependency kubernetes-sigs/external-dns to v1.23.0 ([#102](https://github.com/GlueOps/platform-crds/issues/102)) ([3bd2a8d](https://github.com/GlueOps/platform-crds/commit/3bd2a8dfb54d91eb36cd2bfbc8471e9519f7e0bd))
* **deps:** update dependency traefik/traefik-helm-chart to v42 ([#109](https://github.com/GlueOps/platform-crds/issues/109)) ([4a5bdba](https://github.com/GlueOps/platform-crds/commit/4a5bdbad87f7a398c54447f6fb7ad15aa67233ae))
* **deps:** update helm/kind-action action to v1.15.0 ([#94](https://github.com/GlueOps/platform-crds/issues/94)) ([973148e](https://github.com/GlueOps/platform-crds/commit/973148e8346d6423bee2a1d14aaab5fb70ce9e98))


### Bug Fixes

* **deps:** pin VPA CRDs to 1.7.3 ([df3ee21](https://github.com/GlueOps/platform-crds/commit/df3ee21eae19ae2f121a4320826d9048174e8a87))


### Continuous Integration

* auto-render crds/ on every same-repo PR, not just renovate ([#90](https://github.com/GlueOps/platform-crds/issues/90)) ([4f9f56e](https://github.com/GlueOps/platform-crds/commit/4f9f56efe954df102d7ef20e70903828d385635c))


### Dependencies

* pin Argo CD CRDs to v3.4.13 ([df3ee21](https://github.com/GlueOps/platform-crds/commit/df3ee21eae19ae2f121a4320826d9048174e8a87))
* update dependency cert-manager/cert-manager to v1.21.3 ([#106](https://github.com/GlueOps/platform-crds/issues/106)) ([27278fb](https://github.com/GlueOps/platform-crds/commit/27278fb4e926cecbb8acb3b7676f1a67a9543cc0))
* update dependency metacontroller/metacontroller to v4.17.6 ([#107](https://github.com/GlueOps/platform-crds/issues/107)) ([68066d2](https://github.com/GlueOps/platform-crds/commit/68066d212adcf69fa562b90791f8168c73d12924))

## [0.1.5](https://github.com/GlueOps/platform-crds/compare/v0.1.4...v0.1.5) (2026-09-18)


### Features

* bump CRD sources for the Kubernetes 1.35 platform component upgrades - abandoned ([#83](https://github.com/GlueOps/platform-crds/issues/83)) ([64fedc4](https://github.com/GlueOps/platform-crds/commit/64fedc435f57f03c77a3321b8b79687c02d69c29))

## [0.1.4](https://github.com/GlueOps/platform-crds/compare/v0.1.3...v0.1.4) (2026-08-28)


### Bug Fixes

* remove cache warmup as it fails too often ([#64](https://github.com/GlueOps/platform-crds/issues/64)) ([82cad53](https://github.com/GlueOps/platform-crds/commit/82cad538590ab7c278952ec5c0ec71b80dded485))

## [0.1.3](https://github.com/GlueOps/platform-crds/compare/v0.1.2...v0.1.3) (2026-08-28)


### Documentation

* complete the add-a-source and add-a-profile recipes, and enforce pins ([#62](https://github.com/GlueOps/platform-crds/issues/62)) ([215be59](https://github.com/GlueOps/platform-crds/commit/215be59a9dbd90ba966e6f0d42820b23725beb8b))

## [0.1.2](https://github.com/GlueOps/platform-crds/compare/v0.1.1...v0.1.2) (2026-08-28)


### Features

* stamp platform.glueops.dev/bundle on every CRD ([#59](https://github.com/GlueOps/platform-crds/issues/59)) ([#61](https://github.com/GlueOps/platform-crds/issues/61)) ([5a46646](https://github.com/GlueOps/platform-crds/commit/5a466467de9688460de1aec3fb3a72437c37d73f))


### Documentation

* state what apply-only can and cannot converge, and guard the trigger ([#58](https://github.com/GlueOps/platform-crds/issues/58)) ([df59faf](https://github.com/GlueOps/platform-crds/commit/df59faf144e6486dcb9baadf1099f17fd2b7e034))

## [0.1.1](https://github.com/GlueOps/platform-crds/compare/v0.1.0...v0.1.1) (2026-08-27)


### Bug Fixes

* **ci:** count every profile in the publish mirror probe ([#56](https://github.com/GlueOps/platform-crds/issues/56)) ([5374746](https://github.com/GlueOps/platform-crds/commit/53747461d5dc63a36cb5e68adf6ff494d9537b9b))

## [0.1.0](https://github.com/GlueOps/platform-crds/compare/v0.0.1...v0.1.0) (2026-08-27)


### ⚠ BREAKING CHANGES

* consumers must switch from 'helm show crds' to 'helm template --include-crds -f platform.yaml'. 'helm show crds' still works and returns every CRD, so an older consumer installs the union rather than failing.

### Features

* install CRDs per cluster shape via conditional profile subcharts ([#54](https://github.com/GlueOps/platform-crds/issues/54)) ([c724fea](https://github.com/GlueOps/platform-crds/commit/c724fea2d5629ff58f9da43ca749d365a185e4cf))

## 0.0.1 (2026-08-26)


### ⚠ BREAKING CHANGES

* initial CRD bundle (layer-0 of the platform bootstrap) ([#1](https://github.com/GlueOps/platform-crds/issues/1))

### Features

* initial CRD bundle (layer-0 of the platform bootstrap) ([#1](https://github.com/GlueOps/platform-crds/issues/1)) ([72934de](https://github.com/GlueOps/platform-crds/commit/72934ded7ed6a583884d981aa128a59c3344149d))


### Miscellaneous Chores

* first release is v0.0.1; keep the bundle on 0.x semantics ([#10](https://github.com/GlueOps/platform-crds/issues/10)) ([83fb2b7](https://github.com/GlueOps/platform-crds/commit/83fb2b7eba168a9b8fd36e0f0a5656678861296e))


### Continuous Integration

* add workflows (pull_request checks, release-please, OCI publish on tag) ([9de3c01](https://github.com/GlueOps/platform-crds/commit/9de3c016d8e8d3055695238d55890f0d8af2756f))
