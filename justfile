set positional-arguments
set shell := ["bash", "--noprofile", "--norc", "-euo", "pipefail", "-c"]

default:
    @just --list

shell:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh shell --profile default

exec +args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh exec --profile default -- "$@"

# Compatibility entry: recipes are now declared tasks with setup and lifetime policy.
run +args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run "$@"

setup: bootstrap
build: bundle
test: test-web test-tooling
verify: ci-local

cache-status:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh cache-status

cache-prune *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh cache-prune "$@"

deps-update *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh deps-update "$@"

chainman-update *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh chainman-update "$@"

dexie-update:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh deps-update --no-commit -- --targets js

bootstrap *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run bootstrap -- "$@"

bootstrap-ci *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run bootstrap-ci -- "$@"

bundle *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run bundle -- "$@"

format *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run format -- "$@"

analyze *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run analyze -- "$@"

parity-check *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run parity-check -- "$@"

test-vm *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run test-vm -- "$@"

test-tooling *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run test-tooling -- "$@"

test-web *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run test-web -- "$@"

e2e-prepare-ci *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run e2e-prepare-ci -- "$@"

e2e *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run e2e -- "$@"

check *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run check -- "$@"

ci-local *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run ci-local -- "$@"

publish-dry-run *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run publish-dry-run -- "$@"

publish *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run publish -- "$@"

hooks-install *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run hooks-install -- "$@"

clean *args:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh run clean -- "$@"

services-status:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh services-status

services-stop:
    @CHAINMAN_MODE="${CHAINMAN_MODE:-host-nix}" ./scripts/chainman.sh services-stop
