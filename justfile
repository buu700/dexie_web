set positional-arguments
set shell := ["bash", "--noprofile", "--norc", "-euo", "pipefail", "-c"]

default:
    @just --list

test: test-web test-tooling

build *args:
    @just chainman run bundle -- "$@"

analyze *args:
    @just chainman run analyze -- "$@"

parity-check *args:
    @just chainman run parity-check -- "$@"

test-vm *args:
    @just chainman run test-vm -- "$@"

test-tooling *args:
    @just chainman run test-tooling -- "$@"

test-web *args:
    @just chainman run test-web -- "$@"

e2e-prepare-ci *args:
    @just chainman run e2e-prepare-ci -- "$@"

e2e *args:
    @just chainman run e2e -- "$@"

publish-dry-run *args:
    @just chainman run publish-dry-run -- "$@"

publish *args:
    @just chainman run publish -- "$@"

setup-hooks *args:
    @just chainman run hooks-install -- "$@"

# Stable consumer bootstrap. Runtime behavior belongs to the pinned Git revision.
[group("Chainman")]
[positional-arguments]
chainman +args:
    #!/bin/sh
    set -eu
    IFS= read -r revision < chainman.lock
    case "$revision" in ''|*[!0-9a-f]*) echo 'chainman.lock requires a full lowercase Git SHA' >&2; exit 2 ;; esac
    test "${#revision}" -eq 40 && test "$(wc -c < chainman.lock)" -eq 41
    cache=${XDG_CACHE_HOME:-$HOME/.cache}/chainman/git/github.com-chainmandev-chainman/$revision.git
    g() (
        unset $(GIT_CONFIG_PARAMETERS='' GIT_CONFIG_COUNT=0 git rev-parse --local-env-vars)
        GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_COUNT=0 GIT_TERMINAL_PROMPT=0 git --no-replace-objects -c core.hooksPath=/dev/null -c core.fsmonitor=false "$@"
    )
    if test ! -e "$cache"; then
        mkdir -p "${cache%/*}"
        temporary=$(mktemp -d "$cache.XXXXXX")
        g init --bare --quiet --template= "$temporary"
        ln -sn "$temporary" "$cache" 2>/dev/null || rm -rf "$temporary"
    fi
    if ! g --git-dir="$cache" cat-file -e "$revision" 2>/dev/null; then
        g --git-dir="$cache" -c gc.auto=0 fetch --no-auto-maintenance --no-write-fetch-head https://github.com/chainmandev/chainman.git "$revision"
    fi
    g --git-dir="$cache" fsck --full --strict --no-reflogs --no-dangling
    test "$(g --git-dir="$cache" cat-file -t "$revision")" = commit
    entry=$(g --git-dir="$cache" cat-file blob "$revision:bootstrap/git-entry.sh")
    exec sh -c "$entry" chainman "$PWD" "$cache" "$revision" "$@"

# Project-owned command aliases. Chainman updates only the revision pin.

[positional-arguments]
cache-prune *args:
    #!/bin/sh
    exec just chainman recipe cache-prune "$@"

[positional-arguments]
cache-status *args:
    #!/bin/sh
    exec just chainman recipe cache-status "$@"

[positional-arguments]
chainman-update *args:
    #!/bin/sh
    exec just chainman recipe chainman-update "$@"

[positional-arguments]
clean *args:
    #!/bin/sh
    exec just chainman recipe clean "$@"

[positional-arguments]
config *args:
    #!/bin/sh
    exec just chainman recipe config "$@"

[positional-arguments]
deps-audit *args:
    #!/bin/sh
    exec just chainman recipe deps-audit "$@"

[positional-arguments]
deps-check *args:
    #!/bin/sh
    exec just chainman recipe deps-check "$@"

[positional-arguments]
deps-coverage *args:
    #!/bin/sh
    exec just chainman recipe deps-coverage "$@"

[positional-arguments]
deps-policy-report *args:
    #!/bin/sh
    exec just chainman recipe deps-policy-report "$@"

[positional-arguments]
deps-update *args:
    #!/bin/sh
    exec just chainman recipe deps-update "$@"

[positional-arguments]
deps-update-flutter *args:
    #!/bin/sh
    exec just chainman recipe deps-update-flutter "$@"

[positional-arguments]
deps-update-github *args:
    #!/bin/sh
    exec just chainman recipe deps-update-github "$@"

[positional-arguments]
deps-update-js *args:
    #!/bin/sh
    exec just chainman recipe deps-update-js "$@"

[positional-arguments]
deps-update-nix *args:
    #!/bin/sh
    exec just chainman recipe deps-update-nix "$@"

[positional-arguments]
doctor *args:
    #!/bin/sh
    exec just chainman recipe doctor "$@"

[positional-arguments]
exec *args:
    #!/bin/sh
    exec just chainman recipe exec "$@"

[positional-arguments]
explain *args:
    #!/bin/sh
    exec just chainman recipe explain "$@"

[positional-arguments]
format *args:
    #!/bin/sh
    exec just chainman recipe format "$@"

[positional-arguments]
format-check *args:
    #!/bin/sh
    exec just chainman recipe format-check "$@"

[positional-arguments]
format-staged *args:
    #!/bin/sh
    exec just chainman recipe format-staged "$@"

[positional-arguments]
format-write *args:
    #!/bin/sh
    exec just chainman recipe format-write "$@"

[positional-arguments]
generate *args:
    #!/bin/sh
    exec just chainman recipe generate "$@"

[positional-arguments]
services-status *args:
    #!/bin/sh
    exec just chainman recipe services-status "$@"

[positional-arguments]
setup *args:
    #!/bin/sh
    exec just chainman recipe setup "$@"

[positional-arguments]
setup-status *args:
    #!/bin/sh
    exec just chainman recipe setup-status "$@"

[positional-arguments]
shell *args:
    #!/bin/sh
    exec just chainman recipe shell "$@"

[positional-arguments]
stop *args:
    #!/bin/sh
    exec just chainman recipe stop "$@"

[positional-arguments]
verify *args:
    #!/bin/sh
    exec just chainman recipe verify "$@"

[positional-arguments]
verify-lite *args:
    #!/bin/sh
    exec just chainman recipe verify-lite "$@"
