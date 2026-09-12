set positional-arguments
set shell := ["bash", "--noprofile", "--norc", "-euo", "pipefail", "-c"]

default:
    @just --list

test: test-web test-tooling

build *args:
    @./scripts/chainman.sh run bundle -- "$@"

analyze *args:
    @./scripts/chainman.sh run analyze -- "$@"

parity-check *args:
    @./scripts/chainman.sh run parity-check -- "$@"

test-vm *args:
    @./scripts/chainman.sh run test-vm -- "$@"

test-tooling *args:
    @./scripts/chainman.sh run test-tooling -- "$@"

test-web *args:
    @./scripts/chainman.sh run test-web -- "$@"

e2e-prepare-ci *args:
    @./scripts/chainman.sh run e2e-prepare-ci -- "$@"

e2e *args:
    @./scripts/chainman.sh run e2e -- "$@"

publish-dry-run *args:
    @./scripts/chainman.sh run publish-dry-run -- "$@"

publish *args:
    @./scripts/chainman.sh run publish -- "$@"

setup-hooks *args:
    @./scripts/chainman.sh run hooks-install -- "$@"

import 'scripts/chainman.just'
