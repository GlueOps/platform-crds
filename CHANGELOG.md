# Changelog

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
